-- Friendly, human-readable references for rides and online payments.
-- New rides use T-00001, T-00002, ... while UUIDs remain the immutable
-- internal identifiers. Existing payment references remain valid for history.

CREATE SEQUENCE IF NOT EXISTS public.ride_reference_seq;

ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS ride_reference TEXT;

-- Backfill existing rides deterministically before enforcing uniqueness.
WITH numbered AS (
  SELECT id,
         ROW_NUMBER() OVER (ORDER BY requested_at NULLS LAST, id) AS reference_number
  FROM public.rides
  WHERE ride_reference IS NULL OR trim(ride_reference) = ''
)
UPDATE public.rides r
SET ride_reference = 'T-' || LPAD(numbered.reference_number::TEXT, 5, '0')
FROM numbered
WHERE r.id = numbered.id;

DO $$
DECLARE
  v_max_reference BIGINT;
BEGIN
  SELECT MAX(NULLIF(regexp_replace(ride_reference, '^T-', ''), '')::BIGINT)
  INTO v_max_reference
  FROM public.rides
  WHERE ride_reference ~ '^T-[0-9]+$';

  PERFORM setval(
    'public.ride_reference_seq',
    COALESCE(v_max_reference, 1),
    v_max_reference IS NOT NULL
  );
END $$;

ALTER TABLE public.rides
  ALTER COLUMN ride_reference SET DEFAULT 'T-' || LPAD(nextval('public.ride_reference_seq')::TEXT, 5, '0'),
  ALTER COLUMN ride_reference SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_rides_ride_reference_unique
  ON public.rides (ride_reference);

COMMENT ON COLUMN public.rides.ride_reference IS
  'Customer-facing immutable ride reference, e.g. T-00001. Internal joins continue using id.';

-- Keep archived cancelled rides compatible with the live schema.
CREATE TABLE IF NOT EXISTS public.rides_archive (
  LIKE public.rides INCLUDING DEFAULTS
);

ALTER TABLE public.rides_archive
  ADD COLUMN IF NOT EXISTS ride_reference TEXT,
  ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS surge_multiplier NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS duration_mins INTEGER,
  ADD COLUMN IF NOT EXISTS driver_completed BOOLEAN,
  ADD COLUMN IF NOT EXISTS passenger_completed BOOLEAN,
  ADD COLUMN IF NOT EXISTS payment_reference TEXT,
  ADD COLUMN IF NOT EXISTS payment_status TEXT,
  ADD COLUMN IF NOT EXISTS payment_method TEXT,
  ADD COLUMN IF NOT EXISTS ride_type TEXT,
  ADD COLUMN IF NOT EXISTS distance_km NUMERIC,
  ADD COLUMN IF NOT EXISTS pickup_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS pickup_lng DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS dest_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS dest_lng DOUBLE PRECISION;

UPDATE public.rides_archive archive
SET ride_reference = 'T-' || LPAD(nextval('public.ride_reference_seq')::TEXT, 5, '0')
WHERE archive.ride_reference IS NULL OR trim(archive.ride_reference) = '';

-- The current dispatch signature is the authoritative ride creation path.
CREATE OR REPLACE FUNCTION public.dispatch_ride(
  pickup_lat DOUBLE PRECISION,
  pickup_lng DOUBLE PRECISION,
  p_passenger_id UUID,
  p_origin TEXT,
  p_destination TEXT DEFAULT NULL,
  dest_lat DOUBLE PRECISION DEFAULT NULL,
  dest_lng DOUBLE PRECISION DEFAULT NULL,
  p_ride_type TEXT DEFAULT 'TRYP Go',
  p_fare NUMERIC DEFAULT 0,
  p_payment_method TEXT DEFAULT 'Cash',
  p_distance_km NUMERIC DEFAULT 0,
  p_duration_mins NUMERIC DEFAULT 0,
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  new_ride_id UUID;
  v_base_fare NUMERIC;
  v_per_km_rate NUMERIC;
  v_min_fare NUMERIC;
  v_per_minute_rate NUMERIC;
  v_surge_multiplier NUMERIC;
  v_authoritative_fare NUMERIC;
  v_ride_reference TEXT;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_passenger_id THEN
    RAISE EXCEPTION 'Unauthorized: passenger_id mismatch';
  END IF;

  IF NOT public.is_verified_passenger(p_passenger_id) THEN
    RAISE EXCEPTION 'Passenger verification is required before requesting rides.';
  END IF;

  SELECT base_fare, per_km_rate, min_fare, per_minute_rate, surge_multiplier
  INTO v_base_fare, v_per_km_rate, v_min_fare, v_per_minute_rate, v_surge_multiplier
  FROM public.fare_schemas
  WHERE tier = p_ride_type
  LIMIT 1;

  IF v_base_fare IS NULL THEN
    RAISE EXCEPTION 'Fare configuration for tier % is unavailable.', p_ride_type;
  END IF;

  v_authoritative_fare := GREATEST(
    COALESCE(v_min_fare, 0),
    (
      COALESCE(v_base_fare, 0)
      + (GREATEST(COALESCE(p_distance_km, 0), 0) * COALESCE(v_per_km_rate, 0))
      + (GREATEST(COALESCE(p_duration_mins, 0), 0) * COALESCE(v_per_minute_rate, 0))
    ) * GREATEST(COALESCE(v_surge_multiplier, 1), 0)
  );

  -- Explicitly consume the sequence so the reference is stable and visible
  -- immediately in the returned row, independent of future default changes.
  v_ride_reference := 'T-' || LPAD(nextval('public.ride_reference_seq')::TEXT, 5, '0');

  INSERT INTO public.rides (
    passenger_id, origin, destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, ride_type, ride_reference, fare, payment_method,
    distance_km, duration_mins, payment_status, metadata, status, requested_at
  ) VALUES (
    p_passenger_id, p_origin, p_destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, p_ride_type, v_ride_reference, ROUND(v_authoritative_fare, 2), p_payment_method,
    GREATEST(COALESCE(p_distance_km, 0), 0),
    ROUND(GREATEST(COALESCE(p_duration_mins, 0), 0))::INTEGER,
    'pending', p_metadata, 'requested', now()
  ) RETURNING id INTO new_ride_id;

  RETURN new_ride_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, JSONB
) TO authenticated;

-- Friendly references are also accepted for Paystack reservations. A retry may
-- append a numeric attempt suffix while remaining easy to read (T-00001-2).
CREATE OR REPLACE FUNCTION public.begin_ride_payment(
  p_ride_id UUID,
  p_reference TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ride public.rides;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Only the payment server can initialize a transaction.';
  END IF;

  IF p_reference IS NULL OR p_reference !~ '^T-[0-9]{5,}(-[0-9]+)?$' THEN
    RAISE EXCEPTION 'Invalid payment reference.';
  END IF;

  SELECT * INTO v_ride FROM public.rides WHERE id = p_ride_id FOR UPDATE;
  IF v_ride.id IS NULL THEN RAISE EXCEPTION 'Ride not found.'; END IF;
  IF v_ride.payment_method = 'Cash' THEN RAISE EXCEPTION 'Cash rides do not require Paystack.'; END IF;
  IF v_ride.status IN ('completed', 'cancelled') THEN RAISE EXCEPTION 'This ride is no longer payable.'; END IF;
  IF v_ride.payment_status = 'paid' THEN RAISE EXCEPTION 'This ride is already paid.'; END IF;
  IF v_ride.payment_status = 'processing'
     AND v_ride.updated_at > timezone('utc', now()) - interval '15 minutes' THEN
    RAISE EXCEPTION 'A payment is already being processed for this ride.';
  END IF;

  UPDATE public.rides
  SET payment_status = 'processing',
      payment_reference = p_reference,
      updated_at = timezone('utc', now())
  WHERE id = p_ride_id;
  RETURN p_ride_id;
END;
$$;

REVOKE ALL ON FUNCTION public.begin_ride_payment(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.begin_ride_payment(UUID, TEXT) TO service_role;

COMMENT ON FUNCTION public.begin_ride_payment(UUID, TEXT) IS
  'Reserves a friendly Paystack reference such as T-00001 for a ride payment.';

-- Preserve the friendly reference when cancelled rides are archived.
CREATE OR REPLACE FUNCTION public.archive_stale_rides()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.rides
  SET status = 'cancelled'
  WHERE status = 'requested'
    AND COALESCE(GREATEST(requested_at, scheduled_for), requested_at)
      < timezone('utc', now()) - interval '20 minutes';

  WITH deleted_rides AS (
    DELETE FROM public.rides
    WHERE status = 'cancelled'
      AND updated_at < timezone('utc', now()) - interval '24 hours'
    RETURNING *
  )
  INSERT INTO public.rides_archive (
    id, ride_reference, passenger_id, driver_id, origin, destination, status, fare,
    requested_at, accepted_at, started_at, completed_at, metadata,
    ride_type, payment_method, payment_status, payment_reference,
    distance_km, pickup_lat, pickup_lng, dest_lat, dest_lng,
    surge_multiplier, duration_mins, driver_completed, passenger_completed,
    updated_at, scheduled_for
  )
  SELECT
    id, ride_reference, passenger_id, driver_id, origin, destination, status, fare,
    requested_at, accepted_at, started_at, completed_at, metadata,
    ride_type, payment_method, payment_status, payment_reference,
    distance_km, pickup_lat, pickup_lng, dest_lat, dest_lng,
    surge_multiplier, duration_mins, driver_completed, passenger_completed,
    updated_at, scheduled_for
  FROM deleted_rides;
END;
$$;

GRANT EXECUTE ON FUNCTION public.archive_stale_rides() TO service_role;

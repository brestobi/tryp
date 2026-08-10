-- Scheduled ride booking support.
-- A future ride remains visible to its passenger but is not offered to drivers
-- until its scheduled pickup time arrives.

ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_rides_scheduled_for
  ON public.rides (scheduled_for)
  WHERE scheduled_for IS NOT NULL;

-- Replace the authoritative fare-enforcing dispatch function with a compatible
-- signature that also persists the optional scheduled pickup timestamp.
DROP FUNCTION IF EXISTS public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT,
  NUMERIC, NUMERIC, JSONB
);

CREATE OR REPLACE FUNCTION public.dispatch_ride(
  pickup_lat DOUBLE PRECISION,
  pickup_lng DOUBLE PRECISION,
  p_passenger_id UUID,
  p_origin TEXT,
  p_destination TEXT,
  dest_lat DOUBLE PRECISION,
  dest_lng DOUBLE PRECISION,
  p_ride_type TEXT,
  p_fare NUMERIC,
  p_payment_method TEXT,
  p_distance_km NUMERIC,
  p_duration_mins NUMERIC,
  p_metadata JSONB,
  p_scheduled_for TIMESTAMPTZ
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
BEGIN
  IF auth.uid() IS DISTINCT FROM p_passenger_id THEN
    RAISE EXCEPTION 'Unauthorized: passenger_id mismatch';
  END IF;

  IF NOT public.is_verified_passenger(p_passenger_id) THEN
    RAISE EXCEPTION 'Passenger verification is required before requesting rides.';
  END IF;

  IF p_scheduled_for IS NOT NULL
     AND p_scheduled_for <= timezone('utc', now()) + interval '10 minutes' THEN
    RAISE EXCEPTION 'Scheduled pickup time must be at least 10 minutes from now.';
  END IF;

  SELECT
    base_fare,
    per_km_rate,
    min_fare,
    per_minute_rate,
    surge_multiplier
  INTO
    v_base_fare,
    v_per_km_rate,
    v_min_fare,
    v_per_minute_rate,
    v_surge_multiplier
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

  INSERT INTO public.rides (
    passenger_id, origin, destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, ride_type, fare, payment_method,
    distance_km, duration_mins, payment_status, metadata, status,
    requested_at, scheduled_for
  ) VALUES (
    p_passenger_id, p_origin, p_destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, p_ride_type, ROUND(v_authoritative_fare, 2), p_payment_method,
    GREATEST(COALESCE(p_distance_km, 0), 0),
    ROUND(GREATEST(COALESCE(p_duration_mins, 0), 0))::INTEGER,
    'pending', p_metadata, 'requested', now(), p_scheduled_for
  ) RETURNING id INTO new_ride_id;

  RETURN new_ride_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT,
  NUMERIC, NUMERIC, JSONB, TIMESTAMPTZ
) TO authenticated;

-- Keep the previous signature available for already-installed apps. Older
-- clients continue to create immediate rides with scheduled_for = NULL.
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
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
  SELECT public.dispatch_ride(
    pickup_lat, pickup_lng, p_passenger_id, p_origin, p_destination,
    dest_lat, dest_lng, p_ride_type, p_fare, p_payment_method,
    p_distance_km, p_duration_mins, p_metadata, NULL::TIMESTAMPTZ
  )
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT,
  NUMERIC, NUMERIC, JSONB
) TO authenticated;

-- Future rides must not be offered before their pickup window. Cash rides are
-- still immediately available when scheduled_for is null.
DROP VIEW IF EXISTS public.available_rides_for_driver;
CREATE VIEW public.available_rides_for_driver
  WITH (security_invoker = false) AS
SELECT
  r.id,
  r.passenger_id,
  r.origin,
  r.destination,
  r.status,
  r.fare,
  r.ride_type,
  r.payment_method,
  r.payment_status,
  r.distance_km,
  r.pickup_lat,
  r.pickup_lng,
  r.dest_lat,
  r.dest_lng,
  r.requested_at,
  r.scheduled_for,
  p.full_name AS passenger_name
FROM public.rides r
JOIN public.profiles p ON p.id = r.passenger_id
WHERE public.is_online_approved_driver(auth.uid())
  AND r.status = 'requested'
  AND r.driver_id IS NULL
  AND (r.scheduled_for IS NULL OR r.scheduled_for <= timezone('utc', now()))
  AND (r.payment_method = 'Cash' OR r.payment_status = 'paid')
  AND NOT EXISTS (
    SELECT 1
    FROM public.driver_declined_rides dd
    WHERE dd.ride_id = r.id
      AND dd.driver_id = auth.uid()
  );
GRANT SELECT ON public.available_rides_for_driver TO authenticated;

-- Keep the atomic acceptance path consistent with the driver view.
CREATE OR REPLACE FUNCTION public.accept_ride(p_ride_id UUID)
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ride public.rides;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'driver'
      AND driver_status = 'approved'
  ) THEN
    RAISE EXCEPTION 'Only verified and approved drivers can accept rides.';
  END IF;

  UPDATE public.rides
  SET driver_id = auth.uid(),
      status = 'accepted',
      accepted_at = COALESCE(accepted_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE id = p_ride_id
    AND status = 'requested'
    AND driver_id IS NULL
    AND (scheduled_for IS NULL OR scheduled_for <= timezone('utc', now()))
    AND (payment_method = 'Cash' OR payment_status = 'paid')
  RETURNING * INTO v_ride;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'This ride is unavailable, not yet scheduled, unpaid, or already accepted.';
  END IF;

  RETURN v_ride;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_ride(UUID) TO authenticated;

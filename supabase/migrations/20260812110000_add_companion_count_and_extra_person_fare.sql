-- Passenger companions and per-companion pricing.
-- The booking passenger is always counted as one person. The new field stores
-- only additional companions, so a value of 2 means 3 people in the vehicle.

ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS additional_passengers INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.rides
  DROP CONSTRAINT IF EXISTS rides_additional_passengers_check;

ALTER TABLE public.rides
  ADD CONSTRAINT rides_additional_passengers_check
  CHECK (additional_passengers >= 0);

ALTER TABLE public.rides_archive
  ADD COLUMN IF NOT EXISTS additional_passengers INTEGER;

ALTER TABLE public.fare_schemas
  ADD COLUMN IF NOT EXISTS extra_person_rate NUMERIC(10,2) NOT NULL DEFAULT 0;

ALTER TABLE public.fare_schemas
  DROP CONSTRAINT IF EXISTS fare_schemas_extra_person_rate_check;

ALTER TABLE public.fare_schemas
  ADD CONSTRAINT fare_schemas_extra_person_rate_check
  CHECK (extra_person_rate >= 0);

-- The client quote remains display-only. The server calculates the fare from
-- the live schema, adds the configured companion charge after the normal fare,
-- and never changes the base, distance, duration, or minimum fare components.
-- Capacity is enforced here as well as in the passenger UI.
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
  p_scheduled_for TIMESTAMPTZ,
  p_additional_passengers INTEGER
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
  v_extra_person_rate NUMERIC;
  v_surge_multiplier NUMERIC;
  v_authoritative_fare NUMERIC;
  v_additional_passengers INTEGER := COALESCE(p_additional_passengers, 0);
  v_capacity INTEGER;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_passenger_id THEN
    RAISE EXCEPTION 'Unauthorized: passenger_id mismatch';
  END IF;

  IF NOT public.is_verified_passenger(p_passenger_id) THEN
    RAISE EXCEPTION 'Passenger verification is required before requesting rides.';
  END IF;

  IF v_additional_passengers < 0 THEN
    RAISE EXCEPTION 'Additional passenger count cannot be negative.';
  END IF;

  v_capacity := CASE p_ride_type
    WHEN 'TRYP XL' THEN 6
    ELSE 4
  END;

  IF v_additional_passengers + 1 > v_capacity THEN
    RAISE EXCEPTION 'This vehicle tier allows up to % people.', v_capacity;
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
    extra_person_rate,
    surge_multiplier
  INTO
    v_base_fare,
    v_per_km_rate,
    v_min_fare,
    v_per_minute_rate,
    v_extra_person_rate,
    v_surge_multiplier
  FROM public.fare_schemas
  WHERE tier = p_ride_type
  LIMIT 1;

  IF v_base_fare IS NULL THEN
    RAISE EXCEPTION 'Fare configuration for tier % is unavailable.', p_ride_type;
  END IF;

  v_authoritative_fare :=
    GREATEST(
      COALESCE(v_min_fare, 0),
      (
        COALESCE(v_base_fare, 0)
        + (GREATEST(COALESCE(p_distance_km, 0), 0) * COALESCE(v_per_km_rate, 0))
        + (GREATEST(COALESCE(p_duration_mins, 0), 0) * COALESCE(v_per_minute_rate, 0))
      ) * GREATEST(COALESCE(v_surge_multiplier, 1), 0)
    )
    + (v_additional_passengers * COALESCE(v_extra_person_rate, 0));

  INSERT INTO public.rides (
    passenger_id, origin, destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, ride_type, fare, payment_method,
    distance_km, duration_mins, additional_passengers,
    payment_status, metadata, status, requested_at, scheduled_for
  ) VALUES (
    p_passenger_id, p_origin, p_destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, p_ride_type, ROUND(v_authoritative_fare, 2), p_payment_method,
    GREATEST(COALESCE(p_distance_km, 0), 0),
    ROUND(GREATEST(COALESCE(p_duration_mins, 0), 0))::INTEGER,
    v_additional_passengers,
    'pending', p_metadata, 'requested', now(), p_scheduled_for
  ) RETURNING id INTO new_ride_id;

  RETURN new_ride_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT,
  NUMERIC, NUMERIC, JSONB, TIMESTAMPTZ, INTEGER
) TO authenticated;

-- Compatibility overload for the driver app and older immediate-ride callers.
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
  p_additional_passengers INTEGER
)
RETURNS UUID
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
  SELECT public.dispatch_ride(
    pickup_lat, pickup_lng, p_passenger_id, p_origin, p_destination,
    dest_lat, dest_lng, p_ride_type, p_fare, p_payment_method,
    p_distance_km, p_duration_mins, p_metadata, NULL::TIMESTAMPTZ,
    p_additional_passengers
  )
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT,
  NUMERIC, NUMERIC, JSONB, INTEGER
) TO authenticated;

-- Make the party size available in every driver request projection.
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
  r.additional_passengers,
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

-- Prevent passengers from changing the stored party size after dispatch.
CREATE OR REPLACE FUNCTION public.prevent_client_ride_pricing_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.role() <> 'service_role' AND NOT public.is_admin()
     AND (
       NEW.fare IS DISTINCT FROM OLD.fare
       OR NEW.ride_type IS DISTINCT FROM OLD.ride_type
       OR NEW.distance_km IS DISTINCT FROM OLD.distance_km
       OR NEW.duration_mins IS DISTINCT FROM OLD.duration_mins
       OR NEW.payment_method IS DISTINCT FROM OLD.payment_method
       OR NEW.additional_passengers IS DISTINCT FROM OLD.additional_passengers
     ) THEN
    RAISE EXCEPTION 'Ride pricing and passenger-count fields are managed by the dispatch workflow.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_client_ride_pricing_changes ON public.rides;
CREATE TRIGGER prevent_client_ride_pricing_changes
  BEFORE UPDATE OF fare, ride_type, distance_km, duration_mins,
    payment_method, additional_passengers
  ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_client_ride_pricing_changes();

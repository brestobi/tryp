-- Harden passenger fare integrity.
--
-- The passenger app still sends its Mapbox route metrics for display, but those
-- values are client-authored and must not be allowed to reduce the server fare.
-- Use a conservative road-distance estimate derived from the
-- pickup/destination coordinates for both persisted metrics and pricing. The
-- client route metrics are retained only in the RPC signature for compatibility
-- and are not trusted.

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
  v_coordinate_distance_km NUMERIC;
  v_authoritative_distance_km NUMERIC;
  v_authoritative_duration_mins NUMERIC;
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

  IF pickup_lat IS NULL OR pickup_lng IS NULL
     OR dest_lat IS NULL OR dest_lng IS NULL
     OR pickup_lat <> pickup_lat OR dest_lat <> dest_lat
     OR pickup_lng <> pickup_lng OR dest_lng <> dest_lng
     OR pickup_lat < -90 OR pickup_lat > 90
     OR dest_lat < -90 OR dest_lat > 90
     OR pickup_lng < -180 OR pickup_lng > 180
     OR dest_lng < -180 OR dest_lng > 180 THEN
    RAISE EXCEPTION 'Valid pickup and destination coordinates are required.';
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

  -- The client route metrics are display-only. Ignore both p_distance_km and
  -- p_duration_mins when calculating the stored fare, because an authenticated
  -- caller can otherwise submit zero for a long-distance ride. The database
  -- uses a conservative coordinate-derived road estimate instead. If exact
  -- Mapbox road pricing is required later, replace this with a server-issued
  -- signed route quote rather than trusting raw client metrics.
  v_coordinate_distance_km := earth_distance(
    ll_to_earth(pickup_lat, pickup_lng),
    ll_to_earth(dest_lat, dest_lng)
  ) / 1000.0;
  v_authoritative_distance_km := GREATEST(
    0.5,
    v_coordinate_distance_km * 1.35
  );
  v_authoritative_duration_mins := GREATEST(
    3,
    CEIL(v_authoritative_distance_km / 35.0 * 60.0)
  );

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
        + (v_authoritative_distance_km * COALESCE(v_per_km_rate, 0))
        + (v_authoritative_duration_mins * COALESCE(v_per_minute_rate, 0))
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
    ROUND(v_authoritative_distance_km, 2),
    ROUND(v_authoritative_duration_mins)::INTEGER,
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

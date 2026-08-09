-- Admin fare changes are authoritative for new rides.
-- The client may send a quote for display, but the database recalculates the
-- stored fare from the current per-tier fare_schemas row.

DROP FUNCTION IF EXISTS public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT, NUMERIC, JSONB
);

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
BEGIN
  IF auth.uid() IS DISTINCT FROM p_passenger_id THEN
    RAISE EXCEPTION 'Unauthorized: passenger_id mismatch';
  END IF;

  IF NOT public.is_verified_passenger(p_passenger_id) THEN
    RAISE EXCEPTION 'Passenger verification is required before requesting rides.';
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

  -- Never trust a client quote when the configured tier is missing. A missing
  -- schema is an operational error, not permission to author the stored fare.
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
    distance_km, duration_mins, payment_status, metadata, status, requested_at
  ) VALUES (
    p_passenger_id, p_origin, p_destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, p_ride_type, ROUND(v_authoritative_fare, 2), p_payment_method,
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

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'fare_schemas'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.fare_schemas;
  END IF;
END $$;

-- Keep direct REST updates from changing the fare that was calculated by the
-- dispatch RPC. Status/payment transitions remain available through their
-- dedicated server-side workflows.
-- Rides must be created through dispatch_ride(), which verifies the passenger
-- and calculates the fare from the live fare schema. SECURITY DEFINER lets the
-- RPC insert the row while this privilege prevents REST clients from bypassing it.
REVOKE INSERT ON public.rides FROM authenticated;

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
     ) THEN
    RAISE EXCEPTION 'Ride pricing fields are managed by the dispatch workflow.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_client_ride_pricing_changes ON public.rides;
CREATE TRIGGER prevent_client_ride_pricing_changes
  BEFORE UPDATE OF fare, ride_type, distance_km, duration_mins, payment_method
  ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_client_ride_pricing_changes();

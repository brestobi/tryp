-- TRYP ride lifecycle hardening
-- Keeps driver declines private, enforces valid transitions, and makes completion atomic.

CREATE OR REPLACE FUNCTION public.decline_ride(p_ride_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'driver'
      AND driver_status = 'approved'
      AND is_online = true
  ) THEN
    RAISE EXCEPTION 'Only approved drivers can decline rides.';
  END IF;

  INSERT INTO public.driver_declined_rides (driver_id, ride_id)
  SELECT auth.uid(), r.id
  FROM public.rides r
  WHERE r.id = p_ride_id
    AND r.status = 'requested'
    AND r.driver_id IS NULL
  ON CONFLICT (driver_id, ride_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.decline_ride(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.transition_ride_status(
  p_ride_id UUID,
  p_next_status TEXT
)
RETURNS UUID AS $$
DECLARE
  v_ride public.rides;
  v_current TEXT;
  v_allowed BOOLEAN := false;
BEGIN
  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'Ride not found.';
  END IF;

  IF auth.uid() IS DISTINCT FROM v_ride.passenger_id
     AND auth.uid() IS DISTINCT FROM v_ride.driver_id
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'You are not a participant in this ride.';
  END IF;

  v_current := v_ride.status;
  v_allowed :=
    (auth.uid() = v_ride.passenger_id AND v_current IN ('requested', 'accepted', 'arrived') AND p_next_status = 'cancelled')
    OR (auth.uid() = v_ride.driver_id AND v_current = 'accepted' AND p_next_status = 'arrived')
    OR (auth.uid() = v_ride.driver_id AND v_current = 'arrived' AND p_next_status = 'in_trip')
    OR (public.is_admin() AND p_next_status IN ('requested', 'accepted', 'arrived', 'in_trip', 'completed', 'cancelled'));

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Invalid ride status transition: % -> %.', v_current, p_next_status;
  END IF;

  UPDATE public.rides
  SET status = p_next_status,
      accepted_at = CASE WHEN p_next_status = 'accepted' THEN COALESCE(accepted_at, now()) ELSE accepted_at END,
      started_at = CASE WHEN p_next_status = 'in_trip' THEN COALESCE(started_at, now()) ELSE started_at END,
      completed_at = CASE WHEN p_next_status = 'completed' THEN COALESCE(completed_at, now()) ELSE completed_at END,
      -- Cash is settled when the ride is completed. Online payments remain
      -- pending/processing until a trusted payment verification path marks them paid.
      payment_status = CASE
        WHEN p_next_status = 'completed' AND payment_method = 'Cash' THEN 'paid'
        ELSE payment_status
      END
  WHERE id = p_ride_id;

  RETURN p_ride_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.transition_ride_status(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.complete_ride(
  p_ride_id UUID,
  p_actor TEXT
)
RETURNS UUID AS $$
DECLARE
  v_ride public.rides;
  v_driver_completed BOOLEAN;
  v_passenger_completed BOOLEAN;
BEGIN
  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'Ride not found.';
  END IF;

  IF v_ride.status <> 'in_trip' THEN
    RAISE EXCEPTION 'Only rides in progress can be completed.';
  END IF;

  IF p_actor = 'driver' AND auth.uid() = v_ride.driver_id THEN
    UPDATE public.rides SET driver_completed = true WHERE id = p_ride_id;
  ELSIF p_actor = 'passenger' AND auth.uid() = v_ride.passenger_id THEN
    UPDATE public.rides SET passenger_completed = true WHERE id = p_ride_id;
  ELSE
    RAISE EXCEPTION 'Invalid completion actor.';
  END IF;

  SELECT driver_completed, passenger_completed
  INTO v_driver_completed, v_passenger_completed
  FROM public.rides
  WHERE id = p_ride_id;
  
  IF v_driver_completed AND v_passenger_completed THEN
    UPDATE public.rides
    SET status = 'completed',
        completed_at = COALESCE(completed_at, now()),
        -- Do not settle an online payment merely because both parties ended the ride.
        payment_status = CASE
          WHEN payment_method = 'Cash' THEN 'paid'
          ELSE payment_status
        END
    WHERE id = p_ride_id;
  END IF;

  RETURN p_ride_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.complete_ride(UUID, TEXT) TO authenticated;

-- Remove legacy seven-argument overloads created by older migrations.
DROP FUNCTION IF EXISTS public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT
);
DROP FUNCTION IF EXISTS public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT, NUMERIC
);

-- Canonical dispatch signature. New requests remain unassigned so every eligible
-- driver can see them and declines can be recorded per driver.
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
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_ride_id UUID;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_passenger_id THEN
    RAISE EXCEPTION 'Unauthorized: passenger_id mismatch';
  END IF;

  INSERT INTO public.rides (
    passenger_id, origin, destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, ride_type, fare, payment_method,
    distance_km, payment_status, metadata, status, requested_at
  ) VALUES (
    p_passenger_id, p_origin, p_destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, p_ride_type, p_fare, p_payment_method,
    p_distance_km, 'pending', p_metadata, 'requested', now()
  ) RETURNING id INTO new_ride_id;

  RETURN new_ride_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT, NUMERIC, JSONB
) TO authenticated;

-- Recreate the old open-request view with a decline-aware, PIN-free projection.
-- CREATE OR REPLACE VIEW cannot change the existing view's column list.
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
  p.full_name AS passenger_name
FROM public.rides r
JOIN public.profiles p ON p.id = r.passenger_id
WHERE public.is_online_approved_driver(auth.uid())
  AND r.status = 'requested'
  AND r.driver_id IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.driver_declined_rides dd
    WHERE dd.ride_id = r.id
      AND dd.driver_id = auth.uid()
  );

GRANT SELECT ON public.available_rides_for_driver TO authenticated;

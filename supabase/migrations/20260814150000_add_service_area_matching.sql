-- TRYP service-area matching for the Tzaneen–The Oaks corridor and Phalaborwa.
-- Drivers and passengers must select the same service area. Open requests are
-- then limited to approved online drivers within 5 km of the pickup point.

SET search_path = public, extensions, pg_temp;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS service_area TEXT;

ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS service_area TEXT;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_service_area_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_service_area_check
  CHECK (service_area IS NULL OR service_area IN ('tzaneen_the_oaks', 'phalaborwa'));

ALTER TABLE public.rides
  DROP CONSTRAINT IF EXISTS rides_service_area_check;

ALTER TABLE public.rides
  ADD CONSTRAINT rides_service_area_check
  CHECK (service_area IS NULL OR service_area IN ('tzaneen_the_oaks', 'phalaborwa'));

CREATE INDEX IF NOT EXISTS idx_profiles_service_area_online
  ON public.profiles(service_area, is_online, current_lat, current_lng)
  WHERE role = 'driver' AND is_online = true;

CREATE INDEX IF NOT EXISTS idx_rides_service_area_requested
  ON public.rides(service_area, status, requested_at DESC)
  WHERE status = 'requested' AND driver_id IS NULL;

-- Existing rides remain readable. New rides must have a selected passenger area.
UPDATE public.rides r
SET service_area = p.service_area
FROM public.profiles p
WHERE r.passenger_id = p.id
  AND r.service_area IS NULL
  AND p.service_area IN ('tzaneen_the_oaks', 'phalaborwa');

CREATE OR REPLACE FUNCTION public.set_ride_service_area()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_service_area TEXT;
BEGIN
  SELECT service_area
  INTO v_service_area
  FROM public.profiles
  WHERE id = NEW.passenger_id;

  IF v_service_area IS NULL THEN
    RAISE EXCEPTION 'Select a TRYP service area before requesting a ride.';
  END IF;

  IF v_service_area NOT IN ('tzaneen_the_oaks', 'phalaborwa') THEN
    RAISE EXCEPTION 'Invalid TRYP service area.';
  END IF;

  NEW.service_area := v_service_area;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rides_set_service_area ON public.rides;
CREATE TRIGGER rides_set_service_area
  BEFORE INSERT ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.set_ride_service_area();

-- A driver is eligible only when the request and driver's selected area match,
-- both GPS coordinates are present, and the pickup is within five kilometres.
CREATE OR REPLACE FUNCTION public.is_driver_eligible_for_ride(p_ride_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.rides r
    JOIN public.profiles d ON d.id = auth.uid()
    WHERE r.id = p_ride_id
      AND r.status = 'requested'
      AND r.driver_id IS NULL
      AND d.role = 'driver'
      AND d.driver_status = 'approved'
      AND d.is_online = true
      AND d.service_area IS NOT NULL
      AND d.service_area = r.service_area
      AND d.current_lat IS NOT NULL
      AND d.current_lng IS NOT NULL
      AND r.pickup_lat IS NOT NULL
      AND r.pickup_lng IS NOT NULL
      AND earth_distance(
        ll_to_earth(d.current_lat, d.current_lng),
        ll_to_earth(r.pickup_lat, r.pickup_lng)
      ) <= 5000
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_driver_eligible_for_ride(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_driver_eligible_for_ride(UUID) TO service_role;

-- Replace the broad open-ride policy so a driver cannot read another area's
-- requests through the base rides table.
DROP POLICY IF EXISTS "rides_select_policy" ON public.rides;
CREATE POLICY "rides_select_policy"
  ON public.rides FOR SELECT TO authenticated
  USING (
    passenger_id = auth.uid()
    OR driver_id = auth.uid()
    OR public.is_admin()
    OR public.is_driver_eligible_for_ride(id)
  );

DROP POLICY IF EXISTS "rides_update_policy" ON public.rides;
CREATE POLICY "rides_update_policy"
  ON public.rides FOR UPDATE TO authenticated
  USING (
    passenger_id = auth.uid()
    OR driver_id = auth.uid()
    OR public.has_admin_permission('fleet:write')
    OR public.is_driver_eligible_for_ride(id)
  )
  WITH CHECK (
    passenger_id = auth.uid()
    OR driver_id = auth.uid()
    OR public.has_admin_permission('fleet:write')
    OR public.is_driver_eligible_for_ride(id)
  );

-- Keep the atomic claim path consistent with the request list. The database
-- rechecks area and GPS distance at acceptance time to avoid stale requests.
CREATE OR REPLACE FUNCTION public.accept_ride(p_ride_id UUID)
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_ride public.rides;
BEGIN
  IF NOT public.is_driver_eligible_for_ride(p_ride_id) THEN
    RAISE EXCEPTION 'This ride is outside your service area or nearby radius.';
  END IF;

  UPDATE public.rides r
  SET driver_id = auth.uid(),
      status = 'accepted',
      accepted_at = COALESCE(accepted_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE r.id = p_ride_id
    AND public.is_driver_eligible_for_ride(r.id)
  RETURNING r.* INTO v_ride;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'This ride request is no longer available.';
  END IF;

  RETURN v_ride;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_ride(UUID) TO authenticated;

-- The driver view is the primary request feed. It exposes the exact pickup
-- distance in kilometres and orders closest requests first.
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
  r.service_area,
  ROUND((earth_distance(
    ll_to_earth(d.current_lat, d.current_lng),
    ll_to_earth(r.pickup_lat, r.pickup_lng)
  ) / 1000.0)::numeric, 2) AS pickup_distance_km,
  p.full_name AS passenger_name
FROM public.rides r
JOIN public.profiles p ON p.id = r.passenger_id
JOIN public.profiles d ON d.id = auth.uid()
WHERE d.role = 'driver'
  AND d.driver_status = 'approved'
  AND d.is_online = true
  AND d.service_area IS NOT NULL
  AND d.current_lat IS NOT NULL
  AND d.current_lng IS NOT NULL
  AND r.service_area = d.service_area
  AND r.status = 'requested'
  AND r.driver_id IS NULL
  AND r.pickup_lat IS NOT NULL
  AND r.pickup_lng IS NOT NULL
  AND earth_distance(
    ll_to_earth(d.current_lat, d.current_lng),
    ll_to_earth(r.pickup_lat, r.pickup_lng)
  ) <= 5000
  AND (r.scheduled_for IS NULL OR r.scheduled_for <= timezone('utc', now()))
  AND (r.payment_method = 'Cash' OR r.payment_status = 'paid')
  AND NOT EXISTS (
    SELECT 1
    FROM public.driver_declined_rides dd
    WHERE dd.ride_id = r.id
      AND dd.driver_id = auth.uid()
  )
ORDER BY pickup_distance_km ASC, r.requested_at DESC;

GRANT SELECT ON public.available_rides_for_driver TO authenticated;

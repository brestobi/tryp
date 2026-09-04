-- Final security hardening for the driver dispatch flow.
--
-- This migration intentionally runs after the existing lifecycle, dispatch,
-- presence, and suspension migrations. It closes the remaining gaps without
-- relying on client-side checks or profile-column visibility.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Keep the passenger PIN out of rides.metadata. Drivers can read their ride
-- row, so a PIN stored there is not a secret from the driver.
CREATE TABLE IF NOT EXISTS public.ride_safety_pins (
  ride_id UUID PRIMARY KEY REFERENCES public.rides(id) ON DELETE CASCADE,
  pin_code TEXT NOT NULL CHECK (pin_code ~ '^[0-9]{4}$'),
  pin_digest TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.ride_safety_pins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.ride_safety_pins FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.ride_safety_pins TO authenticated;

DROP POLICY IF EXISTS "Passengers can read own ride safety pins"
  ON public.ride_safety_pins;
CREATE POLICY "Passengers can read own ride safety pins"
  ON public.ride_safety_pins FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.rides r
      WHERE r.id = ride_safety_pins.ride_id
        AND r.passenger_id = auth.uid()
    )
  );

CREATE OR REPLACE FUNCTION public.strip_ride_safety_pin_metadata()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  -- Never persist a client-authored plaintext PIN in a driver-readable ride row.
  NEW.metadata := COALESCE(NEW.metadata, '{}'::jsonb) - 'pin_code';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rides_strip_safety_pin_metadata ON public.rides;
CREATE TRIGGER rides_strip_safety_pin_metadata
  BEFORE INSERT OR UPDATE OF metadata ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.strip_ride_safety_pin_metadata();

CREATE OR REPLACE FUNCTION public.set_ride_safety_pin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_random_bytes BYTEA;
  v_pin TEXT;
BEGIN
  v_random_bytes := gen_random_bytes(2);
  v_pin := (
    (get_byte(v_random_bytes, 0) * 256 + get_byte(v_random_bytes, 1)) % 9000
    + 1000
  )::TEXT;

  INSERT INTO public.ride_safety_pins (ride_id, pin_code, pin_digest)
  VALUES (
    NEW.id,
    v_pin,
    encode(digest(v_pin || ':' || NEW.id::TEXT, 'sha256'), 'hex')
  )
  ON CONFLICT (ride_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rides_set_safety_pin ON public.rides;
CREATE TRIGGER rides_set_safety_pin
  AFTER INSERT ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.set_ride_safety_pin();

-- Backfill legacy rides before removing the old plaintext metadata field.
DO $$
DECLARE
  v_ride RECORD;
  v_pin TEXT;
  v_random_bytes BYTEA;
BEGIN
  FOR v_ride IN
    SELECT id, metadata
    FROM public.rides
    WHERE NOT EXISTS (
      SELECT 1 FROM public.ride_safety_pins p WHERE p.ride_id = rides.id
    )
  LOOP
    v_pin := NULLIF(v_ride.metadata ->> 'pin_code', '');
    IF v_pin IS NULL OR v_pin !~ '^[0-9]{4}$' THEN
      v_random_bytes := gen_random_bytes(2);
      v_pin := (
        (get_byte(v_random_bytes, 0) * 256 + get_byte(v_random_bytes, 1)) % 9000
        + 1000
      )::TEXT;
    END IF;

    INSERT INTO public.ride_safety_pins (ride_id, pin_code, pin_digest)
    VALUES (
      v_ride.id,
      v_pin,
      encode(digest(v_pin || ':' || v_ride.id::TEXT, 'sha256'), 'hex')
    )
    ON CONFLICT (ride_id) DO NOTHING;
  END LOOP;
END;
$$;

UPDATE public.rides
SET metadata = COALESCE(metadata, '{}'::jsonb) - 'pin_code'
WHERE metadata ? 'pin_code';

CREATE OR REPLACE FUNCTION public.get_ride_safety_pin(p_ride_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pin TEXT;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.rides
    WHERE id = p_ride_id
      AND passenger_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Only the passenger can view this safety PIN.';
  END IF;

  SELECT pin_code INTO v_pin
  FROM public.ride_safety_pins
  WHERE ride_id = p_ride_id;
  RETURN v_pin;
END;
$$;

REVOKE ALL ON FUNCTION public.get_ride_safety_pin(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_ride_safety_pin(UUID) TO authenticated;

-- PIN validation is now part of the protected state transition. A missing PIN
-- record or missing argument fails closed instead of allowing a bypass.
CREATE OR REPLACE FUNCTION public.transition_ride_status(
  p_ride_id UUID,
  p_next_status TEXT,
  p_pin_code TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_ride public.rides;
  v_current TEXT;
  v_allowed BOOLEAN := false;
  v_expected_digest TEXT;
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
    (auth.uid() = v_ride.passenger_id
      AND v_current IN ('requested', 'accepted')
      AND p_next_status = 'cancelled')
    OR (auth.uid() = v_ride.driver_id
      AND v_current = 'accepted'
      AND p_next_status = 'arrived')
    OR (auth.uid() = v_ride.driver_id
      AND v_current = 'arrived'
      AND p_next_status = 'in_trip')
    OR (public.is_admin()
      AND p_next_status IN ('requested', 'accepted', 'arrived', 'in_trip', 'completed', 'cancelled'));

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Invalid ride status transition: % -> %.', v_current, p_next_status;
  END IF;

  IF auth.uid() = v_ride.driver_id AND v_current = 'arrived' AND p_next_status = 'in_trip' THEN
    SELECT pin_digest
    INTO v_expected_digest
    FROM public.ride_safety_pins
    WHERE ride_id = p_ride_id;

    IF v_expected_digest IS NULL
       OR p_pin_code IS NULL
       OR p_pin_code !~ '^[0-9]{4}$'
       OR NOT (v_expected_digest = encode(
         digest(p_pin_code || ':' || p_ride_id::TEXT, 'sha256'), 'hex'
       )) THEN
      RAISE EXCEPTION 'The passenger safety PIN is incorrect.';
    END IF;
  END IF;

  UPDATE public.rides
  SET status = p_next_status,
      accepted_at = CASE
        WHEN p_next_status = 'accepted' THEN COALESCE(accepted_at, now())
        ELSE accepted_at
      END,
      started_at = CASE
        WHEN p_next_status = 'in_trip' THEN COALESCE(started_at, now())
        ELSE started_at
      END,
      completed_at = CASE
        WHEN p_next_status = 'completed' THEN COALESCE(completed_at, now())
        ELSE completed_at
      END,
      payment_status = CASE
        WHEN p_next_status = 'completed' AND payment_method = 'Cash' THEN 'paid'
        ELSE payment_status
      END
  WHERE id = p_ride_id;

  RETURN p_ride_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.transition_ride_status(
  p_ride_id UUID,
  p_next_status TEXT
)
RETURNS UUID
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
  SELECT public.transition_ride_status(p_ride_id, p_next_status, NULL::TEXT)
$$;

REVOKE ALL ON FUNCTION public.transition_ride_status(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transition_ride_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transition_ride_status(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.transition_ride_status(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transition_ride_status(UUID, TEXT, TEXT) TO service_role;

-- Keep the eligibility helper authoritative for every caller, including the
-- accept RPC and any future endpoint that reuses it.
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
      AND COALESCE(d.account_status, 'active') = 'active'
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
      AND (r.scheduled_for IS NULL OR r.scheduled_for <= timezone('utc', now()))
      AND (r.payment_method = 'Cash' OR r.payment_status = 'paid')
  );
$$;

REVOKE ALL ON FUNCTION public.is_driver_eligible_for_ride(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_driver_eligible_for_ride(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_driver_eligible_for_ride(UUID) TO service_role;

-- A driver may hold at most one accepted/arrived/in-trip ride. The advisory
-- lock serializes two simultaneous accept calls from multiple devices.
CREATE OR REPLACE FUNCTION public.accept_ride(p_ride_id UUID)
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_ride public.rides;
BEGIN
  IF NOT public.is_online_approved_driver(auth.uid()) THEN
    RAISE EXCEPTION 'Only approved online drivers can accept rides.';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('driver-accept:' || auth.uid()::TEXT, 0)
  );

  IF EXISTS (
    SELECT 1
    FROM public.rides
    WHERE driver_id = auth.uid()
      AND status IN ('accepted', 'arrived', 'in_trip')
  ) THEN
    RAISE EXCEPTION 'You already have an active ride.';
  END IF;

  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL OR NOT public.is_driver_eligible_for_ride(p_ride_id) THEN
    RAISE EXCEPTION 'This ride is outside your service area or nearby radius.';
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
    AND public.is_driver_eligible_for_ride(p_ride_id)
  RETURNING * INTO v_ride;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'This ride request is no longer available.';
  END IF;

  RETURN v_ride;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_ride(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_ride(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_ride(UUID) TO service_role;

-- Presence predicates and self-service profile updates must both respect a
-- suspension. Existing profiles without the new column are treated as active.
CREATE OR REPLACE FUNCTION public.is_online_approved_driver(
  p_uid UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = p_uid
      AND role = 'driver'
      AND driver_status = 'approved'
      AND COALESCE(account_status, 'active') = 'active'
      AND is_online = true
  );
$$;

CREATE OR REPLACE FUNCTION public.prevent_suspended_profile_reactivation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.role() <> 'service_role'
     AND auth.uid() = OLD.id
     AND NOT public.has_admin_permission('users:write')
     AND NEW.account_status IS DISTINCT FROM OLD.account_status THEN
    RAISE EXCEPTION 'Account status can only be changed by an administrator.';
  END IF;

  IF auth.role() <> 'service_role'
     AND auth.uid() = OLD.id
     AND NOT public.has_admin_permission('users:write')
     AND OLD.account_status = 'suspended'
     AND NEW.is_online = true THEN
    RAISE EXCEPTION 'Suspended drivers cannot go online.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_prevent_suspended_reactivation ON public.profiles;
CREATE TRIGGER profiles_prevent_suspended_reactivation
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_suspended_profile_reactivation();

-- A suspended account must never be visible through the driver request view.
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
  AND COALESCE(d.account_status, 'active') = 'active'
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

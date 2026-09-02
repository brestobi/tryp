-- Harden passenger account and active-ride invariants.
--
-- These checks live in INSERT triggers so every dispatch_ride overload and any
-- future server-side ride creation path receives the same protection. Locking
-- the passenger profile serializes concurrent requests from multiple devices.

CREATE OR REPLACE FUNCTION public.protect_passenger_ride_creation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role TEXT;
  v_account_status TEXT;
BEGIN
  -- Trusted administrative/server workflows are allowed to create or repair
  -- records. Authenticated passenger requests must pass all checks below.
  IF auth.role() = 'service_role' OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM NEW.passenger_id THEN
    RAISE EXCEPTION 'Unauthorized passenger ride creation.';
  END IF;

  -- This row lock is the serialization point for concurrent ride requests.
  SELECT role, account_status
  INTO v_role, v_account_status
  FROM public.profiles
  WHERE id = NEW.passenger_id
  FOR UPDATE;

  IF NOT FOUND OR v_role <> 'passenger' THEN
    RAISE EXCEPTION 'Only passenger accounts can request rides.';
  END IF;
  IF v_account_status = 'suspended' THEN
    RAISE EXCEPTION 'This passenger account is suspended.';
  END IF;

  IF NEW.status IN ('requested', 'accepted', 'arrived', 'in_trip')
     AND EXISTS (
       SELECT 1
       FROM public.rides
       WHERE passenger_id = NEW.passenger_id
         AND status IN ('requested', 'accepted', 'arrived', 'in_trip')
     ) THEN
    RAISE EXCEPTION 'This passenger already has an active ride.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_passenger_ride_creation ON public.rides;
CREATE TRIGGER protect_passenger_ride_creation
  BEFORE INSERT ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_passenger_ride_creation();

CREATE OR REPLACE FUNCTION public.protect_passenger_long_distance_booking_creation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role TEXT;
  v_account_status TEXT;
BEGIN
  IF auth.role() = 'service_role' OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM NEW.passenger_id THEN
    RAISE EXCEPTION 'Unauthorized passenger booking creation.';
  END IF;

  SELECT role, account_status
  INTO v_role, v_account_status
  FROM public.profiles
  WHERE id = NEW.passenger_id
  FOR UPDATE;

  IF NOT FOUND OR v_role <> 'passenger' THEN
    RAISE EXCEPTION 'Only passenger accounts can create bookings.';
  END IF;
  IF v_account_status = 'suspended' THEN
    RAISE EXCEPTION 'This passenger account is suspended.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_passenger_long_distance_booking_creation
  ON public.long_distance_bookings;
CREATE TRIGGER protect_passenger_long_distance_booking_creation
  BEFORE INSERT ON public.long_distance_bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_passenger_long_distance_booking_creation();

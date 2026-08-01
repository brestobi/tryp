-- Migration: 20260801270000_realtime_rides_and_location.sql
-- Enables real-time driver dispatching, live GPS location updates, atomic ride acceptance, and passenger notifications.

-- 1. Ensure driver location and availability fields on public.profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS heading DOUBLE PRECISION DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_driver_online_loc 
  ON public.profiles(role, is_online, current_lat, current_lng) 
  WHERE role = 'driver' AND is_online = true;

-- 2. Atomic RPC function for driver to accept a requested ride
CREATE OR REPLACE FUNCTION public.accept_ride(p_ride_id UUID)
RETURNS public.rides AS $$
DECLARE
  v_ride public.rides;
BEGIN
  -- Verify driver is authenticated and approved
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
      AND role = 'driver' 
      AND driver_status = 'approved'
  ) THEN
    RAISE EXCEPTION 'Only verified & approved TRYP drivers can accept ride requests.';
  END IF;

  -- Atomically claim the ride
  UPDATE public.rides
  SET driver_id = auth.uid(),
      status = 'accepted',
      accepted_at = now()
  WHERE id = p_ride_id
    AND status = 'requested'
    AND driver_id IS NULL
  RETURNING * INTO v_ride;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'This ride request has already been accepted or cancelled.';
  END IF;

  RETURN v_ride;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.accept_ride(UUID) TO authenticated;

-- 3. Automatic passenger notification trigger on ride status updates
CREATE OR REPLACE FUNCTION public.trigger_notify_passenger_on_ride_update()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_name TEXT;
  v_vehicle_info TEXT;
  v_title TEXT;
  v_body TEXT;
BEGIN
  IF (OLD.status IS DISTINCT FROM NEW.status) THEN
    -- Get driver info if available
    IF NEW.driver_id IS NOT NULL THEN
      SELECT 
        COALESCE(full_name, 'Driver'),
        TRIM(CONCAT(COALESCE(vehicle_make, ''), ' ', COALESCE(vehicle_model, ''), ' (', COALESCE(vehicle_plate, 'N/A'), ')'))
      INTO v_driver_name, v_vehicle_info
      FROM public.profiles
      WHERE id = NEW.driver_id;
    END IF;

    IF NEW.status = 'accepted' THEN
      v_title := 'Driver Matched! 🚙';
      v_body := COALESCE(v_driver_name, 'A driver') || ' accepted your ride! Vehicle: ' || COALESCE(v_vehicle_info, 'TRYP Vehicle');
    ELSIF NEW.status = 'arrived' THEN
      v_title := 'Driver Arrived! 📌';
      v_body := COALESCE(v_driver_name, 'Your driver') || ' has arrived at your pickup location.';
    ELSIF NEW.status = 'in_trip' THEN
      v_title := 'Trip Started! 🟢';
      v_body := 'Your ride to ' || COALESCE(NEW.destination, 'destination') || ' is now in progress.';
    ELSIF NEW.status = 'completed' THEN
      v_title := 'Trip Completed! 🏁';
      v_body := 'You have arrived at ' || COALESCE(NEW.destination, 'your destination') || '. Thank you for riding with TRYP!';
    ELSIF NEW.status = 'cancelled' THEN
      v_title := 'Ride Cancelled ⚠️';
      v_body := 'Your ride request to ' || COALESCE(NEW.destination, 'destination') || ' was cancelled.';
    END IF;

    IF v_title IS NOT NULL THEN
      INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        route_path,
        payload
      ) VALUES (
        NEW.passenger_id,
        v_title,
        v_body,
        'ride',
        '/passenger/ride-tracking',
        jsonb_build_object('ride_id', NEW.id, 'status', NEW.status, 'driver_id', NEW.driver_id)
      );
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[trigger_notify_passenger_on_ride_update] Error: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_ride_status_notify_passenger ON public.rides;
CREATE TRIGGER on_ride_status_notify_passenger
  AFTER UPDATE ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_notify_passenger_on_ride_update();

-- 4. Enable Supabase Realtime for Rides and Profiles tables
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rides;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END $$;

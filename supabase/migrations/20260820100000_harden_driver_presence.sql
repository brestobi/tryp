-- Keep driver availability truthful when the app is backgrounded, killed, or
-- loses connectivity before it can explicitly go offline.

CREATE OR REPLACE FUNCTION public.expire_stale_driver_locations()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_expired INTEGER;
BEGIN
  UPDATE public.profiles
  SET is_online = false,
      updated_at = timezone('utc', now())
  WHERE role = 'driver'
    AND is_online = true
    AND COALESCE(last_location_update, updated_at) <
        timezone('utc', now()) - interval '2 minutes';

  GET DIAGNOSTICS v_expired = ROW_COUNT;
  RETURN v_expired;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_stale_driver_locations() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.expire_stale_driver_locations() TO service_role;

-- Refresh the timestamp from the database clock whenever coordinates change.
-- The client still sends a heartbeat timestamp on every update, but this
-- prevents device clock skew from making an active driver look stale.
CREATE OR REPLACE FUNCTION public.set_driver_location_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.role = 'driver'
     AND (
       NEW.current_lat IS DISTINCT FROM OLD.current_lat
       OR NEW.current_lng IS DISTINCT FROM OLD.current_lng
     ) THEN
    NEW.last_location_update = timezone('utc', now());
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_set_driver_location_timestamp ON public.profiles;
CREATE TRIGGER profiles_set_driver_location_timestamp
  BEFORE UPDATE OF current_lat, current_lng ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_driver_location_timestamp();

-- Run every minute. The job is intentionally separate from ride archiving so
-- presence cleanup remains independently observable and recoverable.
DO $$
BEGIN
  IF to_regclass('cron.job') IS NULL THEN
    RAISE WARNING '[driver_presence] pg_cron is unavailable; schedule expire_stale_driver_locations() manually.';
  ELSIF NOT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'expire-stale-driver-locations-job'
  ) THEN
    BEGIN
      PERFORM cron.schedule(
        'expire-stale-driver-locations-job',
        '* * * * *',
        'SELECT public.expire_stale_driver_locations()'
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '[driver_presence] Could not schedule stale-location cleanup: %', SQLERRM;
    END;
  END IF;
END;
$$;

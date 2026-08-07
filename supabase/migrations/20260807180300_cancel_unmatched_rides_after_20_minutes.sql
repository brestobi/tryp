-- Automatically cancel ride requests that have waited more than 20 minutes.
-- The existing archive-stale-rides-job calls public.archive_stale_rides() every minute.
-- Keep the function name so the existing cron schedule continues to work.

DO $$
BEGIN
  BEGIN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS pg_cron';
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[cancel_unmatched_rides] pg_cron could not be enabled: %', SQLERRM;
  END;
END;
$$;

-- scheduled_for was added after rides_archive was created by the original
-- archiving migration. Keep the archive table compatible with the current rides
-- schema before the atomic archive move below.
CREATE TABLE IF NOT EXISTS public.rides_archive (
  LIKE public.rides INCLUDING ALL
);

ALTER TABLE public.rides_archive
  ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS surge_multiplier NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS duration_mins INTEGER,
  ADD COLUMN IF NOT EXISTS driver_completed BOOLEAN,
  ADD COLUMN IF NOT EXISTS passenger_completed BOOLEAN;

CREATE OR REPLACE FUNCTION public.archive_stale_rides()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Cancel only rides that are still waiting for a driver. The status predicate
  -- makes this safe against a concurrent driver acceptance: whichever
  -- transaction updates the requested row first wins. This also handles legacy
  -- requested rows that have a driver_id but were never accepted.
  UPDATE public.rides
  SET status = 'cancelled'
  WHERE status = 'requested'
    AND COALESCE(
      GREATEST(requested_at, scheduled_for),
      requested_at
    ) < timezone('utc', now()) - interval '20 minutes';

  -- Keep cancelled rides available to the passenger for 24 hours so the status
  -- update and its notification can be observed. Move them atomically after
  -- that grace period; this preserves the archive behavior without deleting a
  -- ride immediately after its timeout notification.
  WITH deleted_rides AS (
    DELETE FROM public.rides
    WHERE status = 'cancelled'
      AND updated_at < timezone('utc', now()) - interval '24 hours'
    RETURNING *
  )
  INSERT INTO public.rides_archive (
    id, passenger_id, driver_id, origin, destination, status, fare,
    requested_at, accepted_at, started_at, completed_at, metadata,
    ride_type, payment_method, payment_status, payment_reference,
    distance_km, pickup_lat, pickup_lng, dest_lat, dest_lng,
    surge_multiplier, duration_mins, driver_completed, passenger_completed,
    updated_at, scheduled_for
  )
  SELECT
    id, passenger_id, driver_id, origin, destination, status, fare,
    requested_at, accepted_at, started_at, completed_at, metadata,
    ride_type, payment_method, payment_status, payment_reference,
    distance_km, pickup_lat, pickup_lng, dest_lat, dest_lng,
    surge_multiplier, duration_mins, driver_completed, passenger_completed,
    updated_at, scheduled_for
  FROM deleted_rides;
END;
$$;

GRANT EXECUTE ON FUNCTION public.archive_stale_rides() TO service_role;

-- Make the existing minute-by-minute job self-healing if it was removed.
-- If hosted permissions prevent pg_cron from being enabled, leave the function
-- installed and log a warning rather than failing the whole migration.
DO $$
BEGIN
  IF to_regclass('cron.job') IS NULL THEN
    RAISE WARNING '[cancel_unmatched_rides] pg_cron is unavailable; schedule the job manually.';
  ELSIF NOT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'archive-stale-rides-job'
  ) THEN
    BEGIN
      PERFORM cron.schedule(
        'archive-stale-rides-job',
        '* * * * *',
        'SELECT public.archive_stale_rides()'
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '[cancel_unmatched_rides] Could not schedule timeout job: %', SQLERRM;
    END;
  END IF;
END;
$$;

-- Speed up the minute-by-minute timeout scan without affecting accepted rides.
CREATE INDEX IF NOT EXISTS idx_rides_waiting_timeout
  ON public.rides (requested_at)
  WHERE status = 'requested';

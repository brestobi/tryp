-- Enable pg_cron if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create an archive table for rides if it doesn't exist
CREATE TABLE IF NOT EXISTS public.rides_archive (
    LIKE public.rides INCLUDING ALL
);

-- Function to archive stale or cancelled rides
CREATE OR REPLACE FUNCTION public.archive_stale_rides()
RETURNS void AS $$
BEGIN
    -- Move rides requested > 20 mins ago without a driver to archive
    INSERT INTO public.rides_archive
    SELECT * FROM public.rides
    WHERE status = 'requested' 
    AND requested_at < NOW() - INTERVAL '20 minutes';

    DELETE FROM public.rides
    WHERE status = 'requested' 
    AND requested_at < NOW() - INTERVAL '20 minutes';

    -- Move cancelled rides to archive
    INSERT INTO public.rides_archive
    SELECT * FROM public.rides
    WHERE status = 'cancelled';

    DELETE FROM public.rides
    WHERE status = 'cancelled';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule the cron job to run every minute
SELECT cron.schedule(
    'archive-stale-rides-job',
    '* * * * *',
    'SELECT public.archive_stale_rides()'
);

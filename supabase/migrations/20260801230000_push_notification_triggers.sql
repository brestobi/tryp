-- =========================================================================
-- TRYP PLATFORM — Push Notification Database Triggers
-- Migration: 20260801230000_push_notification_triggers.sql
--
-- Automatically calls the `send-push-notification` Edge Function via pg_net
-- when:
--   1. A new in-app notification is inserted into `public.notifications`
--   2. A ride status changes in `public.rides`
-- =========================================================================

CREATE EXTENSION IF NOT EXISTS pg_net;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Trigger for `public.notifications` INSERT
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS on_notification_created_send_push ON public.notifications;
DROP FUNCTION IF EXISTS public.trigger_push_on_notification();

CREATE OR REPLACE FUNCTION public.trigger_push_on_notification()
RETURNS TRIGGER AS $$
DECLARE
  project_ref  TEXT := 'lapkfscxtkvbuojysygk';
  service_key  TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhcGtmc2N4dGt2YnVvanlzeWdrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTE3NDE3NiwiZXhwIjoyMTAwNzUwMTc2fQ.dhi4ApypmzYb2LLX98HBzXtxBIy-E1aSg4pzxwZxqEU';
  payload      JSONB;
BEGIN
  payload := jsonb_build_object(
    'type',   'INSERT',
    'table',  'notifications',
    'schema', 'public',
    'record', jsonb_build_object(
      'id',         NEW.id,
      'user_id',    NEW.user_id,
      'title',      NEW.title,
      'body',       NEW.body,
      'type',       NEW.type,
      'route_path', NEW.route_path,
      'payload',    COALESCE(NEW.payload, '{}'::jsonb)
    )
  );

  PERFORM net.http_post(
    url     := 'https://' || project_ref || '.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body    := payload::text
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[trigger_push_on_notification] Failed: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_notification_created_send_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_push_on_notification();


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Trigger for `public.rides` UPDATE (Ride Status Changes)
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS on_ride_updated_send_push ON public.rides;
DROP FUNCTION IF EXISTS public.trigger_push_on_ride_update();

CREATE OR REPLACE FUNCTION public.trigger_push_on_ride_update()
RETURNS TRIGGER AS $$
DECLARE
  project_ref  TEXT := 'lapkfscxtkvbuojysygk';
  service_key  TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhcGtmc2N4dGt2YnVvanlzeWdrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTE3NDE3NiwiZXhwIjoyMTAwNzUwMTc2fQ.dhi4ApypmzYb2LLX98HBzXtxBIy-E1aSg4pzxwZxqEU';
  payload      JSONB;
BEGIN
  -- Only trigger if status has changed
  IF (OLD.status IS DISTINCT FROM NEW.status) THEN
    payload := jsonb_build_object(
      'type',       'UPDATE',
      'table',      'rides',
      'schema',     'public',
      'record',     jsonb_build_object(
        'id',             NEW.id,
        'passenger_id',   NEW.passenger_id,
        'driver_id',      NEW.driver_id,
        'status',         NEW.status,
        'origin',         NEW.origin,
        'destination',    NEW.destination,
        'fare',           COALESCE(NEW.fare, 0),
        'ride_type',      COALESCE(NEW.ride_type, 'TRYP Go'),
        'payment_method', COALESCE(NEW.payment_method, 'Cash')
      ),
      'old_record', jsonb_build_object(
        'status', OLD.status
      )
    );

    PERFORM net.http_post(
      url     := 'https://' || project_ref || '.supabase.co/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || service_key
      ),
      body    := payload::text
    );
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[trigger_push_on_ride_update] Failed: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_ride_updated_send_push
  AFTER UPDATE ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_push_on_ride_update();

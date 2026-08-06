-- =========================================================================
-- TRYP PLATFORM — Supabase Realtime notifications
-- Migration: 20260801230000_push_notification_triggers.sql
--
-- Firebase/FCM is intentionally not used. Notifications are sent through the
-- app's Supabase notifications table and consumed via Realtime subscriptions.
-- =========================================================================

-- Intentionally no network trigger: the app listens to public.notifications
-- via Supabase Realtime. This keeps the system inside Supabase and avoids the
-- broken Firebase path entirely.

-- Keep the publication setup for notifications so inserts are streamed live to
-- the client app without custom HTTP calls.
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.notifications;

-- If older trigger artifacts exist, remove them to prevent stale Firebase calls.
DROP TRIGGER IF EXISTS on_notification_created_send_push ON public.notifications;
DROP FUNCTION IF EXISTS public.trigger_push_on_notification();
DROP TRIGGER IF EXISTS on_ride_updated_send_push ON public.rides;
DROP FUNCTION IF EXISTS public.trigger_push_on_ride_update();

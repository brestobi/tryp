-- TRYP push delivery
--
-- This migration connects server-created notification rows to the
-- send-push-notification Edge Function. It intentionally does not store a
-- service-role key in source control. Before applying it, configure the
-- database setting below with the Supabase service-role key, or replace this
-- trigger with a Supabase Dashboard Database Webhook:
--
--   ALTER DATABASE postgres SET app.supabase_service_key = '<service-role-key>';
--   ALTER DATABASE postgres SET app.push_webhook_secret = '<random-webhook-secret>';
--
-- Also deploy the Edge Function and configure these function secrets:
--   SUPABASE_SERVICE_ROLE_KEY
--   FCM_SERVICE_ACCOUNT_JSON
--   FCM_PROJECT_ID=tryp-75e26
--   PUSH_WEBHOOK_SECRET (same value as app.push_webhook_secret)

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.trigger_push_on_notification()
RETURNS TRIGGER AS $$
DECLARE
  project_ref TEXT := 'lapkfscxtkvbuojysygk';
  service_key TEXT := current_setting('app.supabase_service_key', true);
  payload JSONB;
BEGIN
  IF service_key IS NULL OR service_key = '' THEN
    RAISE WARNING '[trigger_push_on_notification] app.supabase_service_key is not configured; push delivery skipped.';
    RETURN NEW;
  END IF;

  IF current_setting('app.push_webhook_secret', true) IS NULL
     OR current_setting('app.push_webhook_secret', true) = '' THEN
    RAISE WARNING '[trigger_push_on_notification] app.push_webhook_secret is not configured; push delivery skipped.';
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'notifications',
    'schema', 'public',
    'record', jsonb_build_object(
      'id', NEW.id,
      'user_id', NEW.user_id,
      'title', NEW.title,
      'body', NEW.body,
      'type', NEW.type,
      'route_path', NEW.route_path,
      'payload', COALESCE(NEW.payload, '{}'::jsonb)
    )
  );

  PERFORM net.http_post(
    url := 'https://' || project_ref || '.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key,
      'x-tryp-push-secret', current_setting('app.push_webhook_secret', true)
    ),
    body := payload::text
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[trigger_push_on_notification] %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

DROP TRIGGER IF EXISTS on_notification_created_send_push ON public.notifications;
CREATE TRIGGER on_notification_created_send_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_push_on_notification();

COMMENT ON FUNCTION public.trigger_push_on_notification() IS
  'Asynchronously forwards notification rows to the send-push-notification Edge Function. Requires app.supabase_service_key.';

-- TRYP push delivery fix
-- pg_net 0.20.x expects the http_post body argument as JSONB. Passing
-- payload::text causes the trigger's exception handler to skip the request.

CREATE OR REPLACE FUNCTION public.trigger_push_on_notification()
RETURNS TRIGGER AS $$
DECLARE
  project_ref TEXT := 'lapkfscxtkvbuojysygk';
  service_key TEXT;
  webhook_secret TEXT;
  payload JSONB;
BEGIN
  SELECT decrypted_secret
    INTO service_key
  FROM vault.decrypted_secrets
  WHERE name = 'tryp_push_supabase_service_key'
  LIMIT 1;

  SELECT decrypted_secret
    INTO webhook_secret
  FROM vault.decrypted_secrets
  WHERE name = 'tryp_push_webhook_secret'
  LIMIT 1;

  IF service_key IS NULL OR service_key = '' THEN
    RAISE WARNING '[trigger_push_on_notification] Supabase service key is not configured in Vault; push skipped.';
    RETURN NEW;
  END IF;

  IF webhook_secret IS NULL OR webhook_secret = '' THEN
    RAISE WARNING '[trigger_push_on_notification] Push webhook secret is not configured in Vault; push skipped.';
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
      'x-tryp-push-secret', webhook_secret
    ),
    body := payload
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[trigger_push_on_notification] %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, vault;

DROP TRIGGER IF EXISTS on_notification_created_send_push ON public.notifications;
CREATE TRIGGER on_notification_created_send_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_push_on_notification();

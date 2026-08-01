-- =========================================================================
-- TRYP PLATFORM — Welcome Email Trigger
-- Migration: 20260801210000_welcome_email_trigger.sql
--
-- Fires the send-welcome-email Edge Function via pg_net whenever
-- a new row is inserted into auth.users (i.e. every new signup).
-- =========================================================================

-- Ensure pg_net extension is enabled (required for HTTP calls from DB triggers)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Drop old trigger/function if they exist (idempotent re-run safe)
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS on_new_user_send_welcome_email ON auth.users;
DROP FUNCTION IF EXISTS public.trigger_send_welcome_email();

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Create the trigger function
--    Calls the send-welcome-email Edge Function with the new user's
--    email and metadata via an async HTTP POST (non-blocking).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trigger_send_welcome_email()
RETURNS TRIGGER AS $$
DECLARE
  project_ref  TEXT := 'lapkfscxtkvbuojysygk';
  service_key  TEXT := current_setting('app.supabase_service_key', true);
  payload      JSONB;
BEGIN
  -- Build the webhook payload that mirrors Supabase's Auth Webhook format
  payload := jsonb_build_object(
    'type',   'INSERT',
    'table',  'users',
    'schema', 'auth',
    'record', jsonb_build_object(
      'id',                NEW.id,
      'email',             NEW.email,
      'raw_user_meta_data', COALESCE(NEW.raw_user_meta_data, '{}'::jsonb),
      'created_at',        NEW.created_at
    )
  );

  -- Fire-and-forget async HTTP POST to the Edge Function
  PERFORM net.http_post(
    url     := 'https://' || project_ref || '.supabase.co/functions/v1/send-welcome-email',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || COALESCE(service_key, '')
    ),
    body    := payload::text
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Never block signup if email fails — just log and continue
    RAISE WARNING '[trigger_send_welcome_email] Failed to call edge function: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Attach the trigger to auth.users INSERT
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TRIGGER on_new_user_send_welcome_email
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_send_welcome_email();

-- ─────────────────────────────────────────────────────────────────────────────
-- NOTES:
-- • The trigger is AFTER INSERT so it never blocks the signup transaction.
-- • The EXCEPTION block ensures a failed email call never rejects signup.
-- • Authorization uses the service_role key stored in app settings.
--   To set it run:
--     ALTER DATABASE postgres SET app.supabase_service_key = 'your-service-role-key';
-- • RESEND_API_KEY must be set in Supabase Dashboard:
--     Dashboard → Edge Functions → send-welcome-email → Secrets → RESEND_API_KEY
-- ─────────────────────────────────────────────────────────────────────────────

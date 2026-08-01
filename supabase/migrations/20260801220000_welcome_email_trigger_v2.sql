-- =========================================================================
-- TRYP PLATFORM — Welcome Email Trigger (Updated)
-- Migration: 20260801220000_welcome_email_trigger_v2.sql
--
-- Improved approach: embed the service_role key directly in the trigger
-- function body instead of relying on ALTER DATABASE session settings
-- (which require a full connection restart to propagate on Supabase).
-- =========================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- Drop and recreate the trigger function with the service key embedded
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS on_new_user_send_welcome_email ON auth.users;
DROP FUNCTION IF EXISTS public.trigger_send_welcome_email();

CREATE OR REPLACE FUNCTION public.trigger_send_welcome_email()
RETURNS TRIGGER AS $$
DECLARE
  project_ref  TEXT := 'lapkfscxtkvbuojysygk';
  -- Service role key is stored here directly (SECURITY DEFINER function —
  -- only superusers/postgres can inspect function bodies in Supabase).
  -- This is the standard pattern for Supabase pg_net webhook triggers.
  service_key  TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhcGtmc2N4dGt2YnVvanlzeWdrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTE3NDE3NiwiZXhwIjoyMTAwNzUwMTc2fQ.dhi4ApypmzYb2LLX98HBzXtxBIy-E1aSg4pzxwZxqEU';
  payload      JSONB;
BEGIN
  payload := jsonb_build_object(
    'type',   'INSERT',
    'table',  'users',
    'schema', 'auth',
    'record', jsonb_build_object(
      'id',                 NEW.id,
      'email',              NEW.email,
      'raw_user_meta_data', COALESCE(NEW.raw_user_meta_data, '{}'::jsonb),
      'created_at',         NEW.created_at
    )
  );

  -- Async, non-blocking HTTP POST to the Edge Function
  PERFORM net.http_post(
    url     := 'https://' || project_ref || '.supabase.co/functions/v1/send-welcome-email',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body    := payload::text
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Never block signup if email delivery fails
    RAISE WARNING '[trigger_send_welcome_email] Failed: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach the trigger
CREATE TRIGGER on_new_user_send_welcome_email
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_send_welcome_email();

-- Verify
SELECT trigger_name, event_manipulation, event_object_schema, event_object_table, action_timing
FROM information_schema.triggers
WHERE trigger_name = 'on_new_user_send_welcome_email';

-- Read service role key from Supabase secrets environment and apply to DB setting
-- This makes current_setting('app.supabase_service_key', true) work in triggers

DO $$
DECLARE
  -- The SUPABASE_SECRET_KEYS secret contains the service role JWT
  -- We get it from the auth.jwt() or from the environment via a known approach
  -- Since we can't read env vars in SQL directly, we set it explicitly here.
  -- Replace the value below with your actual service_role key.
  service_key TEXT := current_setting('app.supabase_service_key', true);
BEGIN
  IF service_key IS NULL OR service_key = '' THEN
    RAISE NOTICE 'Set the service key by running: ALTER DATABASE postgres SET "app.supabase_service_key" = ''<your-service-role-key>'';';
    RAISE NOTICE 'Your service role key is found at: https://supabase.com/dashboard/project/lapkfscxtkvbuojysygk/settings/api';
  ELSE
    RAISE NOTICE 'Service key is already set (length: %)', length(service_key);
  END IF;
END $$;

-- Show trigger verification
SELECT
  trigger_name,
  event_manipulation AS event,
  event_object_schema AS schema,
  event_object_table AS "table",
  action_timing AS timing
FROM information_schema.triggers
WHERE trigger_name = 'on_new_user_send_welcome_email';

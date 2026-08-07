-- Retry invoice delivery every five minutes so a missing/temporary webhook
-- does not leave a completed ride without an invoice email.

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.retry_pending_invoice_emails()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault, pg_temp
AS $$
DECLARE
  project_id CONSTANT TEXT := 'lapkfscxtkvbuojysygk';
  service_key TEXT;
  delivery RECORD;
BEGIN
  SELECT decrypted_secret INTO service_key
  FROM vault.decrypted_secrets
  WHERE name = 'tryp_invoice_supabase_service_key'
  LIMIT 1;

  IF service_key IS NULL OR service_key = '' THEN
    RAISE WARNING '[retry_pending_invoice_emails] Supabase service key is not configured in Vault.';
    RETURN;
  END IF;

  FOR delivery IN
    SELECT id, ride_id
    FROM public.invoice_deliveries
    WHERE status IN ('pending', 'failed')
       OR (status = 'sending' AND last_attempt_at < timezone('utc', now()) - interval '10 minutes')
    ORDER BY created_at
    LIMIT 100
  LOOP
    PERFORM net.http_post(
      url := 'https://' || project_id || '.supabase.co/functions/v1/send-invoice-email',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_key
      ),
      body := jsonb_build_object('ride_id', delivery.ride_id)
    );
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[retry_pending_invoice_emails] %', SQLERRM;
END;
$$;

GRANT EXECUTE ON FUNCTION public.retry_pending_invoice_emails() TO service_role;

SELECT cron.schedule(
  'tryp-invoice-email-retry',
  '*/5 * * * *',
  'SELECT public.retry_pending_invoice_emails()'
)
WHERE NOT EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'tryp-invoice-email-retry'
);

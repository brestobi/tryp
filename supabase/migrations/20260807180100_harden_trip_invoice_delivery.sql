-- Trip invoice delivery: durable, idempotent post-completion email processing.

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE TABLE IF NOT EXISTS public.invoice_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sending', 'sent', 'failed')),
  attempts INTEGER NOT NULL DEFAULT 0,
  last_attempt_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  provider_message_id TEXT,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT invoice_deliveries_ride_unique UNIQUE (ride_id)
);

CREATE INDEX IF NOT EXISTS idx_invoice_deliveries_status ON public.invoice_deliveries(status);

ALTER TABLE public.invoice_deliveries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Passengers can view own invoice deliveries" ON public.invoice_deliveries;
CREATE POLICY "Passengers can view own invoice deliveries"
  ON public.invoice_deliveries FOR SELECT TO authenticated
  USING (passenger_id = auth.uid() OR public.is_admin());

DROP TRIGGER IF EXISTS invoice_deliveries_set_updated_at ON public.invoice_deliveries;
CREATE TRIGGER invoice_deliveries_set_updated_at
  BEFORE UPDATE ON public.invoice_deliveries
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS on_ride_completed ON public.rides;
DROP TRIGGER IF EXISTS on_ride_completed_enqueue_invoice ON public.rides;
DROP TRIGGER IF EXISTS on_ride_completed_enqueue_invoice_v2 ON public.rides;

CREATE OR REPLACE FUNCTION public.enqueue_trip_invoice_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault, pg_temp
AS $$
DECLARE
  project_id CONSTANT TEXT := 'lapkfscxtkvbuojysygk';
  service_key TEXT;
  invoice_id UUID;
BEGIN
  IF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM NEW.status
     AND NEW.passenger_id IS NOT NULL THEN
    INSERT INTO public.invoice_deliveries (ride_id, passenger_id)
    VALUES (NEW.id, NEW.passenger_id)
    ON CONFLICT (ride_id) DO NOTHING
    RETURNING id INTO invoice_id;

    IF invoice_id IS NOT NULL THEN
      SELECT decrypted_secret INTO service_key
      FROM vault.decrypted_secrets
      WHERE name = 'tryp_invoice_supabase_service_key'
      LIMIT 1;

      IF service_key IS NULL OR service_key = '' THEN
        RAISE WARNING '[enqueue_trip_invoice_email] Supabase service key is not configured in Vault.';
        RETURN NEW;
      END IF;

      PERFORM net.http_post(
        url := 'https://' || project_id || '.supabase.co/functions/v1/send-invoice-email',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || service_key
        ),
        body := jsonb_build_object('ride_id', NEW.id)
      );
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[enqueue_trip_invoice_email] %', SQLERRM;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_ride_completed_enqueue_invoice_v2
  AFTER UPDATE OF status ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.enqueue_trip_invoice_email();

GRANT EXECUTE ON FUNCTION public.enqueue_trip_invoice_email() TO service_role;

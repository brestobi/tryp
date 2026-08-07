-- TRYP invoice delivery fix
-- pg_net expects body JSONB and headers JSONB. The previous trigger passed
-- both values in incompatible forms and had no exception guard, so completing
-- a ride could be rolled back by the invoice HTTP enqueue failure.

CREATE OR REPLACE FUNCTION public.trigger_send_invoice_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  project_id CONSTANT TEXT := 'lapkfscxtkvbuojysygk';
BEGIN
  IF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM net.http_post(
      url := 'https://' || project_id || '.supabase.co/functions/v1/send-invoice-email',
      headers := jsonb_build_object('Content-Type', 'application/json'),
      body := jsonb_build_object(
        'ride_id', NEW.id,
        'passenger_id', NEW.passenger_id
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Invoice delivery is asynchronous and must never block ride completion.
    RAISE WARNING '[trigger_send_invoice_email] %', SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_ride_completed ON public.rides;
CREATE TRIGGER on_ride_completed
  AFTER UPDATE ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_send_invoice_email();

GRANT EXECUTE ON FUNCTION public.trigger_send_invoice_email() TO service_role;

-- Create a function to trigger the send-invoice-email edge function
CREATE OR REPLACE FUNCTION trigger_send_invoice_email()
RETURNS TRIGGER AS $$
DECLARE
  project_id TEXT := 'lapkfscxtkvbuojysygk';
BEGIN
  -- Only trigger when status is updated to 'completed'
  IF (NEW.status = 'completed' AND OLD.status != 'completed') THEN
    PERFORM
      net.http_post(
        url := 'https://' || project_id || '.supabase.co/functions/v1/send-invoice-email',
        headers := '{"Content-Type": "application/json"}',
        body := jsonb_build_object('ride_id', NEW.id, 'passenger_id', NEW.passenger_id)::text
      );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on the rides table
CREATE TRIGGER on_ride_completed
AFTER UPDATE ON rides
FOR EACH ROW
EXECUTE FUNCTION trigger_send_invoice_email();

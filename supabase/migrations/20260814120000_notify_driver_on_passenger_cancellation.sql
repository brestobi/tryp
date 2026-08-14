-- Notify an assigned driver when a passenger cancels before arrival.
-- The notification row is also consumed by the existing push-delivery trigger.

CREATE OR REPLACE FUNCTION public.trigger_notify_driver_on_ride_cancellation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status
     AND NEW.status = 'cancelled'
     AND NEW.driver_id IS NOT NULL THEN
    INSERT INTO public.notifications (
      user_id,
      title,
      body,
      type,
      route_path,
      payload
    ) VALUES (
      NEW.driver_id,
      'Ride Cancelled',
      'The passenger cancelled the ride from ' ||
        COALESCE(NEW.origin, 'the pickup location') || ' to ' ||
        COALESCE(NEW.destination, 'the destination') || '.',
      'ride',
      '/driver/home',
      jsonb_build_object(
        'ride_id', NEW.id,
        'status', NEW.status,
        'passenger_id', NEW.passenger_id
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[trigger_notify_driver_on_ride_cancellation] Error: %', SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_ride_cancelled_notify_driver ON public.rides;
CREATE TRIGGER on_ride_cancelled_notify_driver
  AFTER UPDATE ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_notify_driver_on_ride_cancellation();

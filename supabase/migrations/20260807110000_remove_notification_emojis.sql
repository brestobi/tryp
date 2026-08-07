-- Keep notification copy professional and consistent across in-app and push notifications.

CREATE OR REPLACE FUNCTION public.strip_notification_emoji(p_text TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT replace(
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(
                        replace(
                          replace(
                            replace(
                              replace(
                                replace(
                                  replace(COALESCE(p_text, ''), '🚘', ''),
                                  '🚙', ''
                                ),
                                '🚗', ''
                              ),
                              '📌', ''
                            ),
                            '🟢', ''
                          ),
                          '🔴', ''
                        ),
                        '🏁', ''
                      ),
                      '⚠️', ''
                    ),
                    '⚠', ''
                  ),
                  '🎉', ''
                ),
                '✅', ''
              ),
              '❌', ''
            ),
            '📸', ''
          ),
          '⭐', ''
        ),
        '️', ''
      ),
      '🚕', ''
    ),
    '🚖', ''
  );
$$;

-- Clean notifications already stored so users do not keep seeing the old copy.
UPDATE public.notifications
SET title = public.strip_notification_emoji(title),
    body = public.strip_notification_emoji(body)
WHERE title <> public.strip_notification_emoji(title)
   OR body <> public.strip_notification_emoji(body);

-- Sanitize all notifications created through the shared RPC, including driver
-- ride requests created by dispatch_ride().
CREATE OR REPLACE FUNCTION public.send_notification(
  target_uid UUID,
  p_title TEXT,
  p_body TEXT,
  p_type TEXT DEFAULT 'system',
  p_route_path TEXT DEFAULT NULL,
  p_payload JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_id UUID;
BEGIN
  INSERT INTO public.notifications (user_id, title, body, type, route_path, payload)
  VALUES (
    target_uid,
    public.strip_notification_emoji(p_title),
    public.strip_notification_emoji(p_body),
    p_type,
    p_route_path,
    p_payload
  )
  RETURNING id INTO new_id;
  RETURN new_id;
END;
$$;

-- Ride status notifications are inserted directly by this trigger, so replace
-- its copy as well. This keeps downstream push notifications emoji-free.
CREATE OR REPLACE FUNCTION public.trigger_notify_passenger_on_ride_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_driver_name TEXT;
  v_vehicle_info TEXT;
  v_title TEXT;
  v_body TEXT;
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.driver_id IS NOT NULL THEN
      SELECT
        COALESCE(full_name, 'Driver'),
        TRIM(CONCAT(
          COALESCE(vehicle_make, ''), ' ',
          COALESCE(vehicle_model, ''), ' (',
          COALESCE(vehicle_plate, 'N/A'), ')'
        ))
      INTO v_driver_name, v_vehicle_info
      FROM public.profiles
      WHERE id = NEW.driver_id;
    END IF;

    IF NEW.status = 'accepted' THEN
      v_title := 'Driver Matched!';
      v_body := COALESCE(v_driver_name, 'A driver') ||
        ' accepted your ride! Vehicle: ' || COALESCE(v_vehicle_info, 'TRYP Vehicle');
    ELSIF NEW.status = 'arrived' THEN
      v_title := 'Driver Arrived!';
      v_body := COALESCE(v_driver_name, 'Your driver') ||
        ' has arrived at your pickup location.';
    ELSIF NEW.status = 'in_trip' THEN
      v_title := 'Trip Started!';
      v_body := 'Your ride to ' || COALESCE(NEW.destination, 'destination') ||
        ' is now in progress.';
    ELSIF NEW.status = 'completed' THEN
      v_title := 'Trip Completed!';
      v_body := 'You have arrived at ' || COALESCE(NEW.destination, 'your destination') ||
        '. Thank you for riding with TRYP!';
    ELSIF NEW.status = 'cancelled' THEN
      v_title := 'Ride Cancelled';
      v_body := 'Your ride request to ' || COALESCE(NEW.destination, 'destination') ||
        ' was cancelled.';
    END IF;

    IF v_title IS NOT NULL THEN
      INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        route_path,
        payload
      ) VALUES (
        NEW.passenger_id,
        public.strip_notification_emoji(v_title),
        public.strip_notification_emoji(v_body),
        'ride',
        '/passenger/ride-tracking',
        jsonb_build_object(
          'ride_id', NEW.id,
          'status', NEW.status,
          'driver_id', NEW.driver_id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '[trigger_notify_passenger_on_ride_update] Error: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Broadcast notifications to passengers and/or drivers.
--
-- Inserts one notification row per target user. Each insert:
--   - shows up in the user's in-app notification feed (realtime), and
--   - automatically queues push delivery via the existing
--     on_notification_created_send_push trigger (pg_net -> send-push-notification).
--
-- Only admins may call this function. Inserting notifications is blocked for
-- regular users by RLS (no INSERT policy on public.notifications), so this
-- SECURITY DEFINER function is the only broadcast path.

CREATE OR REPLACE FUNCTION public.broadcast_notification(
  p_title TEXT,
  p_body TEXT,
  p_type TEXT DEFAULT 'system',
  p_route_path TEXT DEFAULT NULL,
  p_payload JSONB DEFAULT NULL,
  p_target_role TEXT DEFAULT 'all'
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Only admin accounts can broadcast to the fleet.
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admins can broadcast notifications.';
  END IF;

  IF p_target_role NOT IN ('all', 'passenger', 'driver') THEN
    RAISE EXCEPTION 'Invalid target role "%": use all, passenger, or driver.', p_target_role;
  END IF;

  IF p_type NOT IN ('ride', 'promo', 'system', 'payment') THEN
    RAISE EXCEPTION 'Invalid notification type "%": use ride, promo, system, or payment.', p_type;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, route_path, payload)
  SELECT
    p.id,
    public.strip_notification_emoji(p_title),
    public.strip_notification_emoji(p_body),
    p_type,
    p_route_path,
    p_payload
  FROM public.profiles p
  WHERE p.role IN ('passenger', 'driver')
    AND (p_target_role = 'all' OR p.role = p_target_role);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.broadcast_notification(TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.broadcast_notification(TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) TO service_role;

COMMENT ON FUNCTION public.broadcast_notification(TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) IS
  'Admin-only broadcast: inserts one notification per passenger/driver matching p_target_role (all | passenger | driver). Returns recipient count.';

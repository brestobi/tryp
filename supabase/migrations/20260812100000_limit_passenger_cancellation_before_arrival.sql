-- Passengers may cancel only before the driver marks the ride as arrived.
-- Keep this rule in the database as well as in the passenger UI so a stale
-- client cannot cancel after the driver has tapped "I Have Arrived".
CREATE OR REPLACE FUNCTION public.transition_ride_status(
  p_ride_id UUID,
  p_next_status TEXT
)
RETURNS UUID AS $$
DECLARE
  v_ride public.rides;
  v_current TEXT;
  v_allowed BOOLEAN := false;
BEGIN
  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'Ride not found.';
  END IF;

  IF auth.uid() IS DISTINCT FROM v_ride.passenger_id
     AND auth.uid() IS DISTINCT FROM v_ride.driver_id
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'You are not a participant in this ride.';
  END IF;

  v_current := v_ride.status;
  v_allowed :=
    (auth.uid() = v_ride.passenger_id AND v_current IN ('requested', 'accepted') AND p_next_status = 'cancelled')
    OR (auth.uid() = v_ride.driver_id AND v_current = 'accepted' AND p_next_status = 'arrived')
    OR (auth.uid() = v_ride.driver_id AND v_current = 'arrived' AND p_next_status = 'in_trip')
    OR (public.is_admin() AND p_next_status IN ('requested', 'accepted', 'arrived', 'in_trip', 'completed', 'cancelled'));

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Invalid ride status transition: % -> %.', v_current, p_next_status;
  END IF;

  UPDATE public.rides
  SET status = p_next_status,
      accepted_at = CASE WHEN p_next_status = 'accepted' THEN COALESCE(accepted_at, now()) ELSE accepted_at END,
      started_at = CASE WHEN p_next_status = 'in_trip' THEN COALESCE(started_at, now()) ELSE started_at END,
      completed_at = CASE WHEN p_next_status = 'completed' THEN COALESCE(completed_at, now()) ELSE completed_at END,
      payment_status = CASE
        WHEN p_next_status = 'completed' AND payment_method = 'Cash' THEN 'paid'
        ELSE payment_status
      END
  WHERE id = p_ride_id;

  RETURN p_ride_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.transition_ride_status(UUID, TEXT) TO authenticated;

-- Payment cleanup follows the same pre-arrival rule. A settled payment is
-- still protected by the existing paid-state guard above this status check.
CREATE OR REPLACE FUNCTION public.cancel_unpaid_ride_payment(p_ride_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ride public.rides;
BEGIN
  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'Ride not found.';
  END IF;
  IF auth.uid() IS DISTINCT FROM v_ride.passenger_id
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only the passenger or an admin can cancel this ride payment.';
  END IF;

  IF v_ride.payment_status = 'paid' THEN
    RETURN 'paid';
  END IF;

  IF v_ride.payment_status NOT IN ('failed', 'cancelled') THEN
    RETURN v_ride.payment_status;
  END IF;

  IF v_ride.status NOT IN ('requested', 'accepted') THEN
    RAISE EXCEPTION 'Only a ride before driver arrival can be cancelled.';
  END IF;

  UPDATE public.rides
  SET payment_status = CASE
        WHEN v_ride.payment_method = 'Cash' THEN payment_status
        ELSE 'cancelled'
      END,
      status = 'cancelled',
      updated_at = timezone('utc', now())
  WHERE id = p_ride_id;

  RETURN 'cancelled';
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_unpaid_ride_payment(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_unpaid_ride_payment(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_unpaid_ride_payment(UUID) TO service_role;

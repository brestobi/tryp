-- Atomic cleanup for a ride whose online checkout failed, was cancelled, or
-- could not be initialized. The row lock prevents a client cleanup from
-- racing with the trusted Paystack verification path.
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

  -- A payment that has already settled must never be cancelled by the client.
  -- The caller can reload the ride and show the confirmed server state.
  IF v_ride.payment_status = 'paid' THEN
    RETURN 'paid';
  END IF;

  -- An unresolved Paystack transaction must remain recoverable. Only a
  -- server-confirmed failed/cancelled payment may be released here.
  IF v_ride.payment_status NOT IN ('failed', 'cancelled') THEN
    RETURN v_ride.payment_status;
  END IF;

  IF v_ride.status NOT IN ('requested', 'accepted', 'arrived') THEN
    RAISE EXCEPTION 'Only an unstarted ride can be cancelled.';
  END IF;

  UPDATE public.rides
  SET payment_status = CASE
        WHEN v_ride.payment_method = 'Cash' THEN payment_status
        ELSE 'cancelled'
      END,
      status = CASE
        WHEN status IN ('requested', 'accepted', 'arrived') THEN 'cancelled'
        ELSE status
      END,
      updated_at = timezone('utc', now())
  WHERE id = p_ride_id;

  RETURN 'cancelled';
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_unpaid_ride_payment(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_unpaid_ride_payment(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_unpaid_ride_payment(UUID) TO service_role;

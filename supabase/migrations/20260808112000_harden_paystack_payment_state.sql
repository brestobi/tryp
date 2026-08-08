-- Harden the live Paystack flow after the initial integration.
-- Only the Edge Functions (service_role) may reserve a reference or mark an
-- online payment processing/paid. Passengers can no longer author references.

CREATE OR REPLACE FUNCTION public.begin_ride_payment(
  p_ride_id UUID,
  p_reference TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ride public.rides;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Only the payment server can initialize a transaction.';
  END IF;

  IF p_reference IS NULL OR p_reference !~ '^TRYP_[A-Za-z0-9_-]{8,80}$' THEN
    RAISE EXCEPTION 'Invalid payment reference.';
  END IF;

  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'Ride not found.';
  END IF;
  IF v_ride.payment_method = 'Cash' THEN
    RAISE EXCEPTION 'Cash rides do not require Paystack.';
  END IF;
  IF v_ride.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'This ride is no longer payable.';
  END IF;
  IF v_ride.payment_status = 'paid' THEN
    RAISE EXCEPTION 'This ride is already paid.';
  END IF;
  IF v_ride.payment_status = 'processing'
     AND v_ride.updated_at > timezone('utc', now()) - interval '15 minutes' THEN
    RAISE EXCEPTION 'A payment is already being processed for this ride.';
  END IF;

  UPDATE public.rides
  SET payment_status = 'processing',
      payment_reference = p_reference,
      updated_at = timezone('utc', now())
  WHERE id = p_ride_id;

  RETURN p_ride_id;
END;
$$;

REVOKE ALL ON FUNCTION public.begin_ride_payment(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.begin_ride_payment(UUID, TEXT) TO service_role;

-- Replace the older broadly writable RPC. A passenger may update only a
-- client-owned non-final state, and may never create/change a reference.
CREATE OR REPLACE FUNCTION public.set_ride_payment_status(
  p_ride_id UUID,
  p_status TEXT,
  p_reference TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ride public.rides;
  v_is_trusted BOOLEAN := auth.role() = 'service_role' OR public.is_admin();
BEGIN
  IF p_status NOT IN ('pending', 'processing', 'paid', 'failed', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid payment status.';
  END IF;

  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'Ride not found.';
  END IF;

  IF NOT v_is_trusted THEN
    IF auth.uid() IS DISTINCT FROM v_ride.passenger_id THEN
      RAISE EXCEPTION 'Only the passenger or an admin can update ride payment.';
    END IF;
    IF p_status = 'processing' OR p_status = 'paid' THEN
      RAISE EXCEPTION 'Payment processing and settlement are server-controlled.';
    END IF;
    IF p_reference IS NOT NULL AND p_reference IS DISTINCT FROM v_ride.payment_reference THEN
      RAISE EXCEPTION 'Payment references are server-controlled.';
    END IF;
    IF v_ride.payment_status = 'paid' THEN
      RAISE EXCEPTION 'A settled payment cannot be changed by the passenger.';
    END IF;
  END IF;

  IF p_status = 'paid'
     AND v_ride.payment_method <> 'Cash'
     AND NULLIF(trim(COALESCE(p_reference, v_ride.payment_reference)), '') IS NULL THEN
    RAISE EXCEPTION 'A payment reference is required for online payments.';
  END IF;

  UPDATE public.rides
  SET payment_status = p_status,
      payment_reference = CASE
        WHEN v_is_trusted THEN COALESCE(NULLIF(trim(p_reference), ''), payment_reference)
        ELSE payment_reference
      END,
      updated_at = timezone('utc', now())
  WHERE id = p_ride_id;

  RETURN p_ride_id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_ride_payment_status(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_ride_payment_status(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_ride_payment_status(UUID, TEXT, TEXT) TO service_role;

-- Do not show unpaid online rides to drivers. Cash rides remain immediately
-- dispatchable; online rides become dispatchable after verified settlement.
DROP VIEW IF EXISTS public.available_rides_for_driver;
CREATE VIEW public.available_rides_for_driver
  WITH (security_invoker = false) AS
SELECT
  r.id,
  r.passenger_id,
  r.origin,
  r.destination,
  r.status,
  r.fare,
  r.ride_type,
  r.payment_method,
  r.payment_status,
  r.distance_km,
  r.pickup_lat,
  r.pickup_lng,
  r.dest_lat,
  r.dest_lng,
  r.requested_at,
  p.full_name AS passenger_name
FROM public.rides r
JOIN public.profiles p ON p.id = r.passenger_id
WHERE public.is_online_approved_driver(auth.uid())
  AND r.status = 'requested'
  AND r.driver_id IS NULL
  AND (r.payment_method = 'Cash' OR r.payment_status = 'paid')
  AND NOT EXISTS (
    SELECT 1
    FROM public.driver_declined_rides dd
    WHERE dd.ride_id = r.id
      AND dd.driver_id = auth.uid()
  );
GRANT SELECT ON public.available_rides_for_driver TO authenticated;

-- Keep the atomic accept path consistent with the view in case a driver has a
-- stale client-side list.
CREATE OR REPLACE FUNCTION public.accept_ride(p_ride_id UUID)
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ride public.rides;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'driver'
      AND driver_status = 'approved'
  ) THEN
    RAISE EXCEPTION 'Only verified and approved drivers can accept rides.';
  END IF;

  UPDATE public.rides
  SET driver_id = auth.uid(),
      status = 'accepted',
      accepted_at = COALESCE(accepted_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
  WHERE id = p_ride_id
    AND status = 'requested'
    AND driver_id IS NULL
    AND (payment_method = 'Cash' OR payment_status = 'paid')
  RETURNING * INTO v_ride;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'This ride is unavailable, unpaid, or already accepted.';
  END IF;

  RETURN v_ride;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_ride(UUID) TO authenticated;

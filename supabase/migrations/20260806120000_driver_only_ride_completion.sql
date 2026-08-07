-- TRYP: driver-only ride completion
-- The driver is the operational source of truth for arrival and fare completion.
-- Keep the legacy completion columns for compatibility, but do not require the
-- passenger to confirm before the ride becomes completed.

CREATE OR REPLACE FUNCTION public.complete_ride(
  p_ride_id UUID,
  p_actor TEXT DEFAULT 'driver'
)
RETURNS UUID AS $$
DECLARE
  v_ride public.rides;
BEGIN
  -- Mark this transaction so the completion guard below can distinguish the
  -- authorized RPC from direct table updates made by clients.
  PERFORM set_config('tryp.driver_completion_rpc', 'true', true);
  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'Ride not found.';
  END IF;

  IF v_ride.status <> 'in_trip' THEN
    RAISE EXCEPTION 'Only rides in progress can be completed.';
  END IF;

  IF p_actor <> 'driver' OR auth.uid() IS DISTINCT FROM v_ride.driver_id THEN
    RAISE EXCEPTION 'Only the assigned driver can complete this ride.';
  END IF;

  UPDATE public.rides
  SET status = 'completed',
      driver_completed = true,
      completed_at = COALESCE(completed_at, now()),
      -- Cash is settled at driver completion. Online payments remain pending or
      -- processing until the trusted payment verification path marks them paid.
      payment_status = CASE
        WHEN payment_method = 'Cash' THEN 'paid'
        ELSE payment_status
      END
  WHERE id = p_ride_id;

  RETURN p_ride_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.complete_ride(UUID, TEXT) TO authenticated;

-- Prevent a passenger or driver from bypassing the RPC by directly changing a
-- ride to completed through the broad legacy rides UPDATE policy.
CREATE OR REPLACE FUNCTION public.prevent_unauthorized_ride_completion()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status <> 'completed'
     AND NEW.status = 'completed'
     AND COALESCE(current_setting('tryp.driver_completion_rpc', true), '') <> 'true' THEN
    RAISE EXCEPTION 'Only the assigned driver can complete a ride.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS enforce_driver_only_ride_completion ON public.rides;
CREATE TRIGGER enforce_driver_only_ride_completion
  BEFORE UPDATE OF status ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_unauthorized_ride_completion();

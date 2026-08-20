-- Admin reschedule RPC + audit columns for scheduled rides.
--
-- Goals
--   1. Let super admins and finance managers adjust a scheduled pickup time
--      without forcing the passenger to resubmit the booking.
--   2. Persist a structured audit trail showing who rescheduled when and why:
--      reschedule_count, last_rescheduled_at, last_rescheduled_by,
--      last_reschedule_reason.
--   3. Refuse any reschedule that would push a paid ride back-to-back the
--      dispatch window (>= 10 minutes from "now").
--   4. Surface every reschedule via the realtime channel so the admin
--      dashboard refreshes immediately.

ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS reschedule_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_rescheduled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_rescheduled_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS last_reschedule_reason TEXT;

COMMENT ON COLUMN public.rides.reschedule_count IS
  'Number of times an admin or finance team has rescheduled this ride.';
COMMENT ON COLUMN public.rides.last_reschedule_reason IS
  'Operator note explaining the latest reschedule (visible in audit + admin UI).';

-- ─────────────────────────────────────────────────────────────────────────────
-- reschedule_ride: admin-only update of scheduled_for
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.reschedule_ride(
  p_ride_id UUID,
  p_scheduled_for TIMESTAMPTZ,
  p_reason TEXT DEFAULT NULL
)
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ride public.rides;
  v_new TIMESTAMPTZ;
BEGIN
  IF NOT (
    public.has_admin_permission('fleet:read')
    OR public.has_admin_permission('finance:read')
    OR auth.role() = 'service_role'
  ) THEN
    RAISE EXCEPTION 'Only admin operators can reschedule a ride.';
  END IF;

  IF p_scheduled_for IS NULL THEN
    RAISE EXCEPTION 'A new scheduled_for timestamp is required.';
  END IF;

  v_new := timezone('utc', p_scheduled_for);
  IF v_new <= timezone('utc', now()) + interval '10 minutes' THEN
    RAISE EXCEPTION 'The new scheduled pickup must be at least 10 minutes from now.';
  END IF;

  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'Ride not found.';
  END IF;

  IF v_ride.status NOT IN ('requested', 'accepted') THEN
    RAISE EXCEPTION 'Only requested or accepted rides can be rescheduled (current: %).', v_ride.status;
  END IF;

  IF v_ride.scheduled_for IS NOT NULL AND v_ride.scheduled_for = v_new THEN
    RAISE EXCEPTION 'The new pickup time matches the existing one.';
  END IF;

  UPDATE public.rides
  SET scheduled_for = v_new,
      reschedule_count = COALESCE(reschedule_count, 0) + 1,
      last_rescheduled_at = timezone('utc', now()),
      last_rescheduled_by = auth.uid(),
      last_reschedule_reason = NULLIF(trim(coalesce(p_reason, '')), ''),
      updated_at = timezone('utc', now())
  WHERE id = p_ride_id
  RETURNING * INTO v_ride;

  INSERT INTO public.admin_audit_logs (action, target_id, target_type, details)
  VALUES (
    'RESCHEDULE_RIDE',
    p_ride_id,
    'ride',
    format('Rescheduled ride %s to %s.%s',
      p_ride_id,
      to_char(v_new, 'YYYY-MM-DD HH24:MI TZ'),
      CASE WHEN NULLIF(trim(coalesce(p_reason, '')), '') IS NULL
           THEN '' ELSE ' Reason: ' || p_reason END
    )
  );

  RETURN v_ride;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reschedule_ride(UUID, TIMESTAMPTZ, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reschedule_ride(UUID, TIMESTAMPTZ, TEXT) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- admin_cancel_scheduled_ride: a thin wrapper that calls transition_ride_status
-- but stamps reschedule metadata so we know the admin cancelled the booking.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_cancel_scheduled_ride(
  p_ride_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ride public.rides;
BEGIN
  IF NOT (
    public.has_admin_permission('fleet:read')
    OR public.has_admin_permission('finance:read')
    OR auth.role() = 'service_role'
  ) THEN
    RAISE EXCEPTION 'Only admin operators can cancel a scheduled ride.';
  END IF;

  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'Ride not found.';
  END IF;

  IF v_ride.status NOT IN ('requested', 'accepted') THEN
    RAISE EXCEPTION 'Only requested or accepted rides can be cancelled from the scheduled queue.';
  END IF;

  -- transition_ride_status already permits admin to cancel from any state;
  -- we route through it so payment_status, accepted_at, etc. stay consistent.
  PERFORM public.transition_ride_status(p_ride_id, 'cancelled');

  UPDATE public.rides
  SET last_reschedule_reason = format(
        'Cancelled by admin.%s',
        CASE WHEN NULLIF(trim(coalesce(p_reason, '')), '') IS NULL
             THEN '' ELSE ' Reason: ' || p_reason END
      ),
      last_rescheduled_at = timezone('utc', now()),
      last_rescheduled_by = auth.uid()
  WHERE id = p_ride_id;

  SELECT * INTO v_ride FROM public.rides WHERE id = p_ride_id;

  INSERT INTO public.admin_audit_logs (action, target_id, target_type, details)
  VALUES (
    'CANCEL_SCHEDULED_RIDE',
    p_ride_id,
    'ride',
    format('Admin cancelled scheduled ride %s.%s',
      p_ride_id,
      CASE WHEN NULLIF(trim(coalesce(p_reason, '')), '') IS NULL
           THEN '' ELSE ' Reason: ' || p_reason END
    )
  );

  RETURN v_ride;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_cancel_scheduled_ride(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_scheduled_ride(UUID, TEXT) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- Admin-only flattened view (matches the safety_incidents_admin_flat pattern)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.scheduled_rides_admin_flat AS
SELECT
  r.id,
  r.ride_reference,
  r.passenger_id,
  r.driver_id,
  r.origin,
  r.destination,
  r.pickup_lat,
  r.pickup_lng,
  r.dest_lat,
  r.dest_lng,
  r.fare,
  r.ride_type,
  r.payment_method,
  r.payment_status,
  r.payment_reference,
  r.status,
  r.distance_km,
  r.duration_mins,
  r.additional_passengers,
  r.requested_at,
  r.scheduled_for,
  r.accepted_at,
  r.started_at,
  r.completed_at,
  r.metadata,
  r.reschedule_count,
  r.last_rescheduled_at,
  r.last_rescheduled_by,
  r.last_reschedule_reason,
  passenger.full_name AS passenger_name,
  passenger.email AS passenger_email,
  passenger.phone AS passenger_phone,
  driver.full_name AS driver_name,
  driver.email AS driver_email,
  driver.phone AS driver_phone,
  driver.vehicle_plate AS driver_plate,
  operator.full_name AS last_rescheduled_by_name
FROM public.rides r
LEFT JOIN public.profiles passenger ON passenger.id = r.passenger_id
LEFT JOIN public.profiles driver ON driver.id = r.driver_id
LEFT JOIN public.profiles operator ON operator.id = r.last_rescheduled_by
WHERE r.scheduled_for IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- fetch function: return only future (or recent past) scheduled rides, plus
-- the cancelled history so the dashboard has full visibility.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fetch_admin_scheduled_rides(
  p_window_minutes INT DEFAULT 60 * 24 * 30
)
RETURNS TABLE (
  id UUID,
  ride_reference TEXT,
  passenger_id UUID,
  passenger_name TEXT,
  passenger_email TEXT,
  passenger_phone TEXT,
  driver_id UUID,
  driver_name TEXT,
  driver_phone TEXT,
  driver_plate TEXT,
  origin TEXT,
  destination TEXT,
  pickup_lat DOUBLE PRECISION,
  pickup_lng DOUBLE PRECISION,
  dest_lat DOUBLE PRECISION,
  dest_lng DOUBLE PRECISION,
  fare NUMERIC,
  ride_type TEXT,
  payment_method TEXT,
  payment_status TEXT,
  payment_reference TEXT,
  status TEXT,
  scheduled_for TIMESTAMPTZ,
  requested_at TIMESTAMPTZ,
  accepted_at TIMESTAMPTZ,
  reschedule_count INT,
  last_rescheduled_at TIMESTAMPTZ,
  last_rescheduled_by UUID,
  last_rescheduled_by_name TEXT,
  last_reschedule_reason TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_window_min INT := GREATEST(COALESCE(p_window_minutes, 60 * 24 * 30), 1);
BEGIN
  IF NOT (
    public.has_admin_permission('fleet:read')
    OR public.has_admin_permission('finance:read')
    OR public.has_admin_permission('dashboard:read')
    OR auth.role() = 'service_role'
  ) THEN
    RAISE EXCEPTION 'Only admin operators can read scheduled rides.';
  END IF;

  RETURN QUERY
  SELECT
    flat.id,
    flat.ride_reference,
    flat.passenger_id,
    COALESCE(flat.passenger_name, ''),
    COALESCE(flat.passenger_email, ''),
    COALESCE(flat.passenger_phone, ''),
    flat.driver_id,
    flat.driver_name,
    flat.driver_phone,
    flat.driver_plate,
    flat.origin,
    flat.destination,
    flat.pickup_lat,
    flat.pickup_lng,
    flat.dest_lat,
    flat.dest_lng,
    flat.fare,
    flat.ride_type,
    flat.payment_method,
    flat.payment_status,
    flat.payment_reference,
    flat.status,
    flat.scheduled_for,
    flat.requested_at,
    flat.accepted_at,
    flat.reschedule_count,
    flat.last_rescheduled_at,
    flat.last_rescheduled_by,
    flat.last_rescheduled_by_name,
    flat.last_reschedule_reason
  FROM public.scheduled_rides_admin_flat flat
  WHERE flat.scheduled_for >= timezone('utc', now()) - make_interval(mins => v_window_min)
     OR flat.status = 'cancelled'
  ORDER BY flat.scheduled_for ASC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_admin_scheduled_rides(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_admin_scheduled_rides(INT) TO service_role;

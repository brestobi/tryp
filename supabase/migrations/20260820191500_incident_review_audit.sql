-- Safety incident review & audit hardening.
--
-- Goals
--   1. Track which admin acknowledged/resolved an incident so the support
--      team can answer "who took ownership of this SOS?"
--   2. Restrict the existing update_safety_incident_status RPC to admins with
--      fleet:write permission (fleet dispatchers + super admins). KYC
--      officers intentionally cannot dismiss incidents.
--   3. Capture an internal audit trail (internal_notes JSONB) per incident
--      without exposing it to passengers/drivers.
--   4. Push safety_incidents over the realtime channel so the dashboard
--      reflects new SOS reports as they come in.

-- ─────────────────────────────────────────────────────────────────────────────
-- Columns
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.safety_incidents
  ADD COLUMN IF NOT EXISTS acknowledged_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS acknowledged_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS internal_notes JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_safety_incidents_status_created
  ON public.safety_incidents (status, created_at DESC);

COMMENT ON COLUMN public.safety_incidents.internal_notes IS
  'Private JSONB notes captured by admin operators. Read via the fetch_admin_incidents SECURITY DEFINER RPC; the admin client must not query the base table.';

GRANT SELECT ON public.safety_incidents TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- flatten view used by admin RPC
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.safety_incidents_admin_flat AS
SELECT
  si.id,
  si.ride_id,
  si.reporter_id,
  si.incident_type,
  si.message,
  si.latitude,
  si.longitude,
  si.status,
  si.created_at,
  si.acknowledged_by,
  si.acknowledged_at,
  si.resolved_by,
  si.resolved_at,
  si.internal_notes,
  reporter.full_name AS reporter_name,
  reporter.email AS reporter_email,
  reporter.phone AS reporter_phone,
  reporter.role AS reporter_role,
  acker.full_name AS acknowledged_by_name,
  resolver.full_name AS resolved_by_name,
  ride.ride_reference AS ride_reference,
  ride.status AS ride_status,
  ride.origin AS ride_origin,
  ride.destination AS ride_destination
FROM public.safety_incidents si
LEFT JOIN public.profiles reporter ON reporter.id = si.reporter_id
LEFT JOIN public.profiles acker ON acker.id = si.acknowledged_by
LEFT JOIN public.profiles resolver ON resolver.id = si.resolved_by
LEFT JOIN public.rides ride ON ride.id = si.ride_id;

-- The SECURITY DEFINER RPC below is the only way to read internal_notes from
-- the admin client. We never call the view directly from PostgREST.
-- ─────────────────────────────────────────────────────────────────────────────
-- Admin read RPC — surfaces internal_notes only to admin callers
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fetch_admin_incidents(
  p_limit INT DEFAULT 100
)
RETURNS TABLE (
  id UUID,
  ride_id UUID,
  reporter_id UUID,
  incident_type TEXT,
  message TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  status TEXT,
  created_at TIMESTAMPTZ,
  acknowledged_by UUID,
  acknowledged_at TIMESTAMPTZ,
  resolved_by UUID,
  resolved_at TIMESTAMPTZ,
  internal_notes JSONB,
  reporter_name TEXT,
  reporter_email TEXT,
  reporter_phone TEXT,
  reporter_role TEXT,
  acknowledged_by_name TEXT,
  resolved_by_name TEXT,
  ride_reference TEXT,
  ride_status TEXT,
  ride_origin TEXT,
  ride_destination TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit INT := GREATEST(COALESCE(p_limit, 100), 1);
BEGIN
  IF NOT (
    public.has_admin_permission('fleet:read')
    OR auth.role() = 'service_role'
  ) THEN
    RAISE EXCEPTION 'Only admin operators can read incident review data.';
  END IF;

  RETURN QUERY
  SELECT
    flat.id,
    flat.ride_id,
    flat.reporter_id,
    flat.incident_type,
    flat.message,
    flat.latitude,
    flat.longitude,
    flat.status,
    flat.created_at,
    flat.acknowledged_by,
    flat.acknowledged_at,
    flat.resolved_by,
    flat.resolved_at,
    flat.internal_notes,
    flat.reporter_name,
    flat.reporter_email,
    flat.reporter_phone,
    flat.reporter_role,
    flat.acknowledged_by_name,
    flat.resolved_by_name,
    flat.ride_reference,
    flat.ride_status,
    flat.ride_origin,
    flat.ride_destination
  FROM public.safety_incidents_admin_flat flat
  ORDER BY flat.created_at DESC
  LIMIT v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_admin_incidents(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_admin_incidents(INT) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- Tighten update_safety_incident_status to use has_admin_permission
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_safety_incident_status(
  p_incident_id UUID,
  p_status TEXT
)
RETURNS UUID AS $$
DECLARE
  v_incident public.safety_incidents;
BEGIN
  IF NOT (
    public.has_admin_permission('fleet:write')
    OR auth.role() = 'service_role'
  ) THEN
    RAISE EXCEPTION 'Only fleet operators or super admins can update incident status.';
  END IF;

  IF p_status NOT IN ('acknowledged', 'resolved') THEN
    RAISE EXCEPTION 'Invalid safety incident status.';
  END IF;

  SELECT * INTO v_incident
  FROM public.safety_incidents
  WHERE id = p_incident_id
  FOR UPDATE;

  IF v_incident.id IS NULL THEN
    RAISE EXCEPTION 'Safety incident not found.';
  END IF;

  IF v_incident.status = 'resolved' THEN
    RAISE EXCEPTION 'Resolved safety incidents cannot be reopened.';
  END IF;

  UPDATE public.safety_incidents
  SET status = p_status,
      acknowledged_by = CASE WHEN p_status = 'acknowledged' THEN auth.uid() ELSE acknowledged_by END,
      acknowledged_at = CASE WHEN p_status = 'acknowledged' THEN COALESCE(acknowledged_at, timezone('utc', now())) ELSE acknowledged_at END,
      resolved_by = CASE WHEN p_status = 'resolved' THEN auth.uid() ELSE resolved_by END,
      resolved_at = CASE WHEN p_status = 'resolved' THEN COALESCE(resolved_at, timezone('utc', now())) ELSE resolved_at END
  WHERE id = p_incident_id;

  RETURN p_incident_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.update_safety_incident_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_safety_incident_status(UUID, TEXT) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- Append an operator note to an incident
-- Public route path is `append_incident_note` (RPC). The fleet operator's
-- email and admin_role are stamped by the existing audit trigger.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.append_incident_note(
  p_incident_id UUID,
  p_note TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_incident public.safety_incidents;
  v_note JSONB;
  v_notes JSONB;
BEGIN
  IF NOT (
    public.has_admin_permission('fleet:read')
    OR auth.role() = 'service_role'
  ) THEN
    RAISE EXCEPTION 'Only admin operators can append incident notes.';
  END IF;

  IF NULLIF(trim(coalesce(p_note, '')), '') IS NULL THEN
    RAISE EXCEPTION 'A non-empty note is required.';
  END IF;
  IF char_length(p_note) > 1000 THEN
    RAISE EXCEPTION 'Incident note must be at most 1000 characters.';
  END IF;

  SELECT * INTO v_incident
  FROM public.safety_incidents
  WHERE id = p_incident_id
  FOR UPDATE;

  IF v_incident.id IS NULL THEN
    RAISE EXCEPTION 'Safety incident not found.';
  END IF;

  v_note := jsonb_build_object(
    'note', p_note,
    'operator_id', auth.uid(),
    'operator_email', auth.jwt() ->> 'email',
    'operator_role', public.get_my_admin_role(),
    'appended_at', timezone('utc', now())
  );

  v_notes := coalesce(v_incident.internal_notes, '[]'::jsonb) || v_note;

  UPDATE public.safety_incidents
  SET internal_notes = v_notes
  WHERE id = p_incident_id;

  -- Also record a high-level audit log entry so finance / compliance can
  -- spot check via the audit logs view without exposing the inner note text.
  INSERT INTO public.admin_audit_logs (action, target_id, target_type, details)
  VALUES (
    'APPEND_INCIDENT_NOTE',
    p_incident_id,
    'safety_incident',
    format('Operator appended note (%s chars) to incident %s', char_length(p_note), p_incident_id)
  );

  RETURN v_note;
END;
$$;

GRANT EXECUTE ON FUNCTION public.append_incident_note(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.append_incident_note(UUID, TEXT) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- Realtime: safety_incidents
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'safety_incidents'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.safety_incidents;
    END IF;
  END IF;
END
$$;

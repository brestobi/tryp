ALTER TABLE public.driver_documents
  ADD COLUMN IF NOT EXISTS issue_notes text,
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.flag_driver_document(
  p_document_id UUID,
  p_issue_notes TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_driver_id UUID;
  v_document_type TEXT;
  v_reason TEXT;
BEGIN
  IF NOT public.has_admin_permission('kyc:write') THEN
    RAISE EXCEPTION 'Only authorised KYC administrators can flag documents.';
  END IF;

  v_reason := NULLIF(trim(COALESCE(p_issue_notes, '')), '');
  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'A flag reason is required.';
  END IF;

  SELECT driver_id, document_type
    INTO v_driver_id, v_document_type
  FROM public.driver_documents
  WHERE id = p_document_id
  FOR UPDATE;

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Driver document was not found.';
  END IF;

  UPDATE public.driver_documents
  SET status = 'flagged',
      issue_notes = v_reason,
      reviewed_by = auth.uid(),
      reviewed_at = timezone('utc', now())
  WHERE id = p_document_id;

  PERFORM public.send_notification(
    v_driver_id,
    'Document requires re-upload',
    'Your ' || replace(v_document_type, '_', ' ') || ' was flagged: ' || v_reason,
    'system',
    '/driver/onboarding',
    jsonb_build_object(
      'event', 'driver_document_flagged',
      'document_id', p_document_id,
      'document_type', v_document_type,
      'issue_notes', v_reason
    )
  );

  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.flag_driver_document(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.flag_driver_document(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.flag_driver_document(UUID, TEXT) TO service_role;

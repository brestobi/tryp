-- Existing passenger verification rows created by the R2 client store object
-- keys in the legacy path columns. Record that provider explicitly so admin
-- readers can select the correct signed-URL flow.
UPDATE public.passenger_verifications
SET storage_provider = 'r2',
    id_document_object_key = id_document_path,
    selfie_object_key = selfie_path
WHERE storage_provider = 'supabase'
  AND id_document_path LIKE 'passengers/%'
  AND selfie_path LIKE 'passengers/%';

-- Keep the dedicated R2 columns synchronized for future submissions made
-- through submit_passenger_verification().
CREATE OR REPLACE FUNCTION public.submit_passenger_verification(
  p_id_document_path TEXT,
  p_selfie_path TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  verification_id UUID;
  expected_prefix TEXT := 'passengers/' || auth.uid()::text || '/';
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication is required.';
  END IF;

  IF p_id_document_path IS NULL OR p_selfie_path IS NULL
     OR p_id_document_path NOT LIKE expected_prefix || '%'
     OR p_selfie_path NOT LIKE expected_prefix || '%' THEN
    RAISE EXCEPTION 'Verification files must belong to the authenticated passenger.';
  END IF;

  INSERT INTO public.passenger_verifications (
    passenger_id, id_document_path, selfie_path, storage_provider,
    id_document_object_key, selfie_object_key, status,
    review_notes, reviewed_by, reviewed_at, submitted_at
  ) VALUES (
    auth.uid(), p_id_document_path, p_selfie_path, 'r2',
    p_id_document_path, p_selfie_path, 'pending',
    NULL, NULL, NULL, timezone('utc', now())
  )
  ON CONFLICT (passenger_id) DO UPDATE SET
    id_document_path = EXCLUDED.id_document_path,
    selfie_path = EXCLUDED.selfie_path,
    storage_provider = 'r2',
    id_document_object_key = EXCLUDED.id_document_object_key,
    selfie_object_key = EXCLUDED.selfie_object_key,
    status = 'pending',
    review_notes = NULL,
    reviewed_by = NULL,
    reviewed_at = NULL,
    submitted_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  RETURNING id INTO verification_id;

  PERFORM set_config('tryp.passenger_verification_write', 'true', true);
  UPDATE public.profiles
  SET passenger_verification_status = 'pending', updated_at = timezone('utc', now())
  WHERE id = auth.uid();

  RETURN verification_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_passenger_verification(TEXT, TEXT) TO authenticated;

-- Driver onboarding: live selfie verification.
-- The selfie is stored in the private driver-documents bucket and tracked like
-- the other verification documents. This migration is additive and idempotent.

DROP POLICY IF EXISTS "Allow all for authenticated on driver_documents" ON public.driver_documents;
DROP POLICY IF EXISTS "Authenticated users read driver documents" ON public.driver_documents;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS doc_selfie TEXT,
  ADD COLUMN IF NOT EXISTS doc_selfie_status TEXT DEFAULT 'pending';

DROP VIEW IF EXISTS public.driver_document_summary;

CREATE VIEW public.driver_document_summary AS
WITH normalized AS (
  SELECT
    driver_id,
    CASE
      WHEN document_type IN ('prdp', 'prdp_license') THEN 'prdp'
      ELSE document_type
    END AS logical_type,
    document_url,
    status,
    submitted_at
  FROM public.driver_documents
  WHERE document_type IN (
    'prdp', 'prdp_license', 'vehicle_registration', 'insurance',
    'roadworthiness', 'selfie'
  )
), logical_documents AS (
  SELECT
    driver_id,
    logical_type,
    MAX(document_url) AS document_url,
    MAX(submitted_at) AS submitted_at,
    CASE
      WHEN bool_or(status = 'rejected') THEN 'rejected'
      WHEN bool_or(status IN ('pending', 'under_review')) THEN 'under_review'
      WHEN bool_and(status = 'approved') THEN 'approved'
      ELSE 'pending'
    END AS status
  FROM normalized
  GROUP BY driver_id, logical_type
)
SELECT
  driver_id,
  MAX(document_url) FILTER (WHERE logical_type = 'prdp') AS doc_prdp,
  MAX(status) FILTER (WHERE logical_type = 'prdp') AS doc_prdp_status,
  MAX(submitted_at) FILTER (WHERE logical_type = 'prdp') AS doc_prdp_submitted_at,
  MAX(document_url) FILTER (WHERE logical_type = 'vehicle_registration') AS doc_vehicle_registration,
  MAX(status) FILTER (WHERE logical_type = 'vehicle_registration') AS doc_vehicle_registration_status,
  MAX(submitted_at) FILTER (WHERE logical_type = 'vehicle_registration') AS doc_vehicle_reg_submitted_at,
  MAX(document_url) FILTER (WHERE logical_type = 'insurance') AS doc_insurance,
  MAX(status) FILTER (WHERE logical_type = 'insurance') AS doc_insurance_status,
  MAX(submitted_at) FILTER (WHERE logical_type = 'insurance') AS doc_insurance_submitted_at,
  MAX(document_url) FILTER (WHERE logical_type = 'roadworthiness') AS doc_roadworthiness,
  MAX(status) FILTER (WHERE logical_type = 'roadworthiness') AS doc_roadworthiness_status,
  MAX(submitted_at) FILTER (WHERE logical_type = 'roadworthiness') AS doc_roadworthiness_submitted_at,
  MAX(document_url) FILTER (WHERE logical_type = 'selfie') AS doc_selfie,
  MAX(status) FILTER (WHERE logical_type = 'selfie') AS doc_selfie_status,
  MAX(submitted_at) FILTER (WHERE logical_type = 'selfie') AS doc_selfie_submitted_at,
  CASE
    WHEN COUNT(*) = 5 AND COUNT(*) FILTER (WHERE status = 'approved') = 5 THEN 'approved'
    WHEN bool_or(status = 'rejected') THEN 'rejected'
    WHEN COUNT(*) > 0 THEN 'under_review'
    ELSE 'pending'
  END AS overall_status,
  COUNT(*) AS docs_submitted,
  COUNT(*) FILTER (WHERE status = 'approved') AS docs_approved
FROM logical_documents
GROUP BY driver_id;

GRANT SELECT ON public.driver_document_summary TO authenticated;

-- Selfies are KYC data; keep the bucket private. Drivers and admins use the
-- authenticated storage policies from the security hardening migrations.
UPDATE storage.buckets SET public = false WHERE id = 'driver-documents';

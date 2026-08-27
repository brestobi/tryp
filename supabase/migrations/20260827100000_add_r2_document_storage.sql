-- Store object keys for Cloudflare R2 while preserving legacy Supabase URLs.
ALTER TABLE public.driver_documents
  ADD COLUMN IF NOT EXISTS storage_provider text NOT NULL DEFAULT 'supabase',
  ADD COLUMN IF NOT EXISTS object_key text,
  ADD COLUMN IF NOT EXISTS content_type text,
  ADD COLUMN IF NOT EXISTS file_size bigint;

ALTER TABLE public.passenger_verifications
  ADD COLUMN IF NOT EXISTS storage_provider text NOT NULL DEFAULT 'supabase',
  ADD COLUMN IF NOT EXISTS id_document_object_key text,
  ADD COLUMN IF NOT EXISTS selfie_object_key text;

ALTER TABLE public.driver_documents
  DROP CONSTRAINT IF EXISTS driver_documents_storage_provider_check;
ALTER TABLE public.driver_documents
  ADD CONSTRAINT driver_documents_storage_provider_check
  CHECK (storage_provider IN ('supabase', 'r2'));

ALTER TABLE public.passenger_verifications
  DROP CONSTRAINT IF EXISTS passenger_verifications_storage_provider_check;
ALTER TABLE public.passenger_verifications
  ADD CONSTRAINT passenger_verifications_storage_provider_check
  CHECK (storage_provider IN ('supabase', 'r2'));

CREATE INDEX IF NOT EXISTS idx_driver_documents_storage_provider
  ON public.driver_documents(storage_provider);

CREATE INDEX IF NOT EXISTS idx_passenger_verifications_storage_provider
  ON public.passenger_verifications(storage_provider);

COMMENT ON COLUMN public.driver_documents.document_url IS
  'Legacy Supabase URL or R2 object key. Use storage_provider to determine which.';
COMMENT ON COLUMN public.driver_documents.object_key IS
  'Cloudflare R2 object key for documents uploaded after R2 migration.';

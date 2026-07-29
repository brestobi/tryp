-- Migration: 20260729155000_fix_driver_documents_storage_and_sync.sql
-- Description: Fix Supabase Storage bucket policies & keep driver_documents + profiles in sync

-- 1. Ensure storage bucket 'driver-documents' is configured cleanly
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'driver-documents',
  'driver-documents',
  true,
  20971520, -- 20MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/heic', 'application/pdf', 'application/octet-stream']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 20971520,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/heic', 'application/pdf', 'application/octet-stream'];

-- 2. Clean up existing storage RLS policies for driver-documents bucket
DROP POLICY IF EXISTS "Drivers can upload their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Drivers can update their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for driver documents" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload driver documents" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update driver documents" ON storage.objects;

-- Allow any authenticated user (driver or admin) to upload verification documents
CREATE POLICY "Authenticated users can upload driver documents"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'driver-documents');

-- Allow any authenticated user (driver or admin) to update verification documents
CREATE POLICY "Authenticated users can update driver documents"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'driver-documents');

-- Allow public read access to uploaded verification documents
CREATE POLICY "Public read access for driver documents"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'driver-documents');


-- 3. Fix driver_documents table RLS policies
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Drivers can insert their own documents" ON public.driver_documents;
DROP POLICY IF EXISTS "Drivers can update their own documents" ON public.driver_documents;
DROP POLICY IF EXISTS "Authenticated users read driver documents" ON public.driver_documents;
DROP POLICY IF EXISTS "Allow all for authenticated on driver_documents" ON public.driver_documents;

CREATE POLICY "Allow all for authenticated on driver_documents"
  ON public.driver_documents
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);


-- 4. Trigger to automatically populate driver_documents table whenever profiles doc columns change
CREATE OR REPLACE FUNCTION public.sync_profile_docs_to_driver_documents()
RETURNS TRIGGER AS $$
BEGIN
  -- Sync PrDP document
  IF NEW.doc_prdp IS NOT NULL AND (OLD.doc_prdp IS NULL OR NEW.doc_prdp <> OLD.doc_prdp) THEN
    INSERT INTO public.driver_documents (driver_id, document_type, document_url, status, submitted_at)
    VALUES (NEW.id, 'prdp_license', NEW.doc_prdp, COALESCE(NEW.doc_prdp_status, 'pending'), timezone('utc', now()))
    ON CONFLICT DO NOTHING;
  END IF;

  -- Sync Vehicle Registration document
  IF NEW.doc_vehicle_registration IS NOT NULL AND (OLD.doc_vehicle_registration IS NULL OR NEW.doc_vehicle_registration <> OLD.doc_vehicle_registration) THEN
    INSERT INTO public.driver_documents (driver_id, document_type, document_url, status, submitted_at)
    VALUES (NEW.id, 'vehicle_registration', NEW.doc_vehicle_registration, COALESCE(NEW.doc_vehicle_registration_status, 'pending'), timezone('utc', now()))
    ON CONFLICT DO NOTHING;
  END IF;

  -- Sync Insurance document
  IF NEW.doc_insurance IS NOT NULL AND (OLD.doc_insurance IS NULL OR NEW.doc_insurance <> OLD.doc_insurance) THEN
    INSERT INTO public.driver_documents (driver_id, document_type, document_url, status, submitted_at)
    VALUES (NEW.id, 'insurance', NEW.doc_insurance, COALESCE(NEW.doc_insurance_status, 'pending'), timezone('utc', now()))
    ON CONFLICT DO NOTHING;
  END IF;

  -- Sync Roadworthiness document
  IF NEW.doc_roadworthiness IS NOT NULL AND (OLD.doc_roadworthiness IS NULL OR NEW.doc_roadworthiness <> OLD.doc_roadworthiness) THEN
    INSERT INTO public.driver_documents (driver_id, document_type, document_url, status, submitted_at)
    VALUES (NEW.id, 'roadworthiness', NEW.doc_roadworthiness, COALESCE(NEW.doc_roadworthiness_status, 'pending'), timezone('utc', now()))
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_sync_profile_docs ON public.profiles;
CREATE TRIGGER trigger_sync_profile_docs
  AFTER INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_docs_to_driver_documents();

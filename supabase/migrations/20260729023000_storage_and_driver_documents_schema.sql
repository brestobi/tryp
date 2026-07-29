-- Migration: 20260729023000_storage_and_driver_documents_schema.sql
-- Description: Driver document upload columns, online status, Supabase Storage bucket 'driver-documents' & RLS policies

-- 1. Extend profiles table for online status & direct document fields
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS doc_prdp TEXT,
  ADD COLUMN IF NOT EXISTS doc_prdp_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS doc_vehicle_registration TEXT,
  ADD COLUMN IF NOT EXISTS doc_vehicle_registration_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS doc_insurance TEXT,
  ADD COLUMN IF NOT EXISTS doc_insurance_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS doc_roadworthiness TEXT,
  ADD COLUMN IF NOT EXISTS doc_roadworthiness_status TEXT DEFAULT 'pending';

-- Index for searching online drivers
CREATE INDEX IF NOT EXISTS idx_profiles_is_online ON public.profiles(is_online) WHERE is_online = true;

-- 2. Create Storage Bucket for driver verification documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'driver-documents',
  'driver-documents',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

-- 3. Storage RLS Security Policies for driver-documents bucket
DROP POLICY IF EXISTS "Drivers can upload their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Drivers can update their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for driver documents" ON storage.objects;

-- Allow authenticated users to upload files into their driver folder
CREATE POLICY "Drivers can upload their own verification documents"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'driver-documents' AND
    (storage.foldername(name))[1] = 'drivers' AND
    (storage.foldername(name))[2] = auth.uid()::text
  );

-- Allow authenticated users to update/overwrite their own verification documents
CREATE POLICY "Drivers can update their own verification documents"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'driver-documents' AND
    (storage.foldername(name))[1] = 'drivers' AND
    (storage.foldername(name))[2] = auth.uid()::text
  );

-- Allow public read access to uploaded driver verification documents
CREATE POLICY "Public read access for driver documents"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'driver-documents');

-- 4. Enable Supabase Realtime for rides and profiles state sync
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'rides'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rides;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
END $$;

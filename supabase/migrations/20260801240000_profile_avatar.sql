-- =========================================================================
-- TRYP PLATFORM — Profile Picture & Avatar Storage Migration
-- Migration: 20260801240000_profile_avatar.sql
--
-- 1. Adds `avatar_url` to `public.profiles`
-- 2. Configures `avatars` bucket in Supabase Storage with RLS policies
-- =========================================================================

-- 1. Add avatar_url column to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

COMMENT ON COLUMN public.profiles.avatar_url IS 'Public CDN URL for user profile picture / avatar';


-- 2. Create `avatars` public storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic'];


-- 3. RLS Storage Policies for `avatars` bucket

-- Allow public read access to avatar images
DROP POLICY IF EXISTS "Public Avatar Access" ON storage.objects;
CREATE POLICY "Public Avatar Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Allow authenticated users to upload their own avatar file
DROP POLICY IF EXISTS "User Avatar Upload" ON storage.objects;
CREATE POLICY "User Avatar Upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to update their own avatar file
DROP POLICY IF EXISTS "User Avatar Update" ON storage.objects;
CREATE POLICY "User Avatar Update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to delete their own avatar file
DROP POLICY IF EXISTS "User Avatar Delete" ON storage.objects;
CREATE POLICY "User Avatar Delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

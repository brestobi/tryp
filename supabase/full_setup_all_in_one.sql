-- =========================================================================
-- TRYP PLATFORM — COMPLETE SUPABASE DATABASE & STORAGE MIGRATION SCRIPT
-- Copy and paste this script into your Supabase Dashboard SQL Editor to set
-- up all tables, storage buckets, indexes, RLS policies, and Realtime sync.
-- =========================================================================

-- 1. Create PROFILES Table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  phone TEXT UNIQUE,
  phone_number TEXT,
  role TEXT CHECK (role IN ('passenger', 'driver', 'admin', 'super_admin')) NOT NULL DEFAULT 'passenger',
  avatar_url TEXT,
  home_address TEXT,
  work_address TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  preferred_payment TEXT DEFAULT 'Cash',
  wallet_balance NUMERIC(10,2) DEFAULT 150.00,
  rating NUMERIC(3,2) DEFAULT 5.00,
  
  -- Driver Verification & Vehicle Details
  id_number TEXT,
  license_number TEXT,
  operating_city TEXT DEFAULT 'Johannesburg',
  driver_status TEXT DEFAULT 'pending' CHECK (driver_status IN ('pending', 'under_review', 'approved', 'rejected')),
  is_online BOOLEAN DEFAULT false,
  vehicle_make TEXT,
  vehicle_model TEXT,
  vehicle_year TEXT,
  vehicle_color TEXT,
  vehicle_plate TEXT,
  vehicle_category TEXT DEFAULT 'TRYP Go',
  
  -- Bank Payout Details
  bank_name TEXT,
  bank_account_number TEXT,
  bank_branch_code TEXT,
  bank_account_holder TEXT,
  
  -- Driver Verification Document URLs & Statuses
  doc_prdp TEXT,
  doc_prdp_status TEXT DEFAULT 'pending',
  doc_vehicle_registration TEXT,
  doc_vehicle_registration_status TEXT DEFAULT 'pending',
  doc_insurance TEXT,
  doc_insurance_status TEXT DEFAULT 'pending',
  doc_roadworthiness TEXT,
  doc_roadworthiness_status TEXT DEFAULT 'pending',
  
  -- Push Notifications Token
  push_token TEXT,
  push_token_updated_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now()) NOT NULL
);

-- 2. Create RIDES Table
CREATE TABLE IF NOT EXISTS public.rides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  origin TEXT NOT NULL,
  destination TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'requested', -- requested, accepted, arrived, in_trip, completed, cancelled
  ride_type TEXT DEFAULT 'Economy',
  payment_method TEXT DEFAULT 'Cash',
  payment_status TEXT DEFAULT 'pending',
  payment_reference TEXT,
  fare NUMERIC(10,2),
  distance_km NUMERIC(10,2),
  pickup_lat DOUBLE PRECISION,
  pickup_lng DOUBLE PRECISION,
  dest_lat DOUBLE PRECISION,
  dest_lng DOUBLE PRECISION,
  requested_at TIMESTAMPTZ DEFAULT timezone('utc', now()) NOT NULL,
  accepted_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  metadata JSONB
);

-- 3. Create FARE SCHEMAS Table
CREATE TABLE IF NOT EXISTS public.fare_schemas (
  id TEXT PRIMARY KEY DEFAULT 'default',
  base_fare NUMERIC(10,2) NOT NULL DEFAULT 15.00,
  per_km_rate NUMERIC(10,2) NOT NULL DEFAULT 5.00,
  min_fare NUMERIC(10,2) NOT NULL DEFAULT 20.00,
  currency_symbol TEXT NOT NULL DEFAULT 'R',
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now()) NOT NULL
);

-- Insert Default Fare Schema (R15 base fare + R5/km, minimum R20)
INSERT INTO public.fare_schemas (id, base_fare, per_km_rate, min_fare, currency_symbol)
VALUES ('default', 15.00, 5.00, 20.00, 'R')
ON CONFLICT (id) DO UPDATE SET
  base_fare = EXCLUDED.base_fare,
  per_km_rate = EXCLUDED.per_km_rate,
  min_fare = EXCLUDED.min_fare,
  updated_at = timezone('utc', now());

-- 4. Create SAVED PLACES Table
CREATE TABLE IF NOT EXISTS public.saved_places (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  address TEXT NOT NULL,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()) NOT NULL
);

-- 5. Create DRIVER DOCUMENTS Table
CREATE TABLE IF NOT EXISTS public.driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL,
  document_url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  submitted_at TIMESTAMPTZ DEFAULT timezone('utc', now()) NOT NULL,
  reviewed_at TIMESTAMPTZ
);

-- 6. Create Indexes for High Performance Querying
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_driver_status ON public.profiles(driver_status);
CREATE INDEX IF NOT EXISTS idx_profiles_is_online ON public.profiles(is_online) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_profiles_push_token ON public.profiles(id) WHERE push_token IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_rides_status ON public.rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_passenger_id ON public.rides(passenger_id);
CREATE INDEX IF NOT EXISTS idx_rides_driver_id ON public.rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_saved_places_user_id ON public.saved_places(user_id);

-- 7. Provision Supabase Storage Bucket for Driver Verification Documents
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

-- 8. Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fare_schemas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_places ENABLE ROW LEVEL SECURITY;

-- 9. Row Level Security (RLS) Policies
-- Profiles: Users can view and edit their own profiles; Drivers can be queried by Passengers
DROP POLICY IF EXISTS "Public profiles read access" ON public.profiles;
DROP POLICY IF EXISTS "Users can edit own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

CREATE POLICY "Public profiles read access" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can edit own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Rides: Passengers and Drivers can view and update their active trips
DROP POLICY IF EXISTS "Users can read own rides" ON public.rides;
DROP POLICY IF EXISTS "Passengers can create rides" ON public.rides;
DROP POLICY IF EXISTS "Participants can update rides" ON public.rides;

CREATE POLICY "Users can read own rides" ON public.rides FOR SELECT USING (auth.uid() = passenger_id OR auth.uid() = driver_id OR driver_id IS NULL);
CREATE POLICY "Passengers can create rides" ON public.rides FOR INSERT WITH CHECK (auth.uid() = passenger_id);
CREATE POLICY "Participants can update rides" ON public.rides FOR UPDATE USING (auth.uid() = passenger_id OR auth.uid() = driver_id OR driver_id IS NULL);

-- Fare Schemas: Read-only for all authenticated users
DROP POLICY IF EXISTS "Everyone can read fare schemas" ON public.fare_schemas;
CREATE POLICY "Everyone can read fare schemas" ON public.fare_schemas FOR SELECT USING (true);

-- Saved Places: Users can manage their own saved places
DROP POLICY IF EXISTS "Users manage own saved places" ON public.saved_places;
CREATE POLICY "Users manage own saved places" ON public.saved_places FOR ALL USING (auth.uid() = user_id);

-- Storage Policies for driver-documents bucket
DROP POLICY IF EXISTS "Drivers can upload their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Drivers can update their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for driver documents" ON storage.objects;

CREATE POLICY "Drivers can upload their own verification documents"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'driver-documents' AND (storage.foldername(name))[1] = 'drivers' AND (storage.foldername(name))[2] = auth.uid()::text);

CREATE POLICY "Drivers can update their own verification documents"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'driver-documents' AND (storage.foldername(name))[1] = 'drivers' AND (storage.foldername(name))[2] = auth.uid()::text);

CREATE POLICY "Public read access for driver documents"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'driver-documents');

-- 10. Enable Supabase Realtime for instant synchronization
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'rides'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rides;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
END $$;

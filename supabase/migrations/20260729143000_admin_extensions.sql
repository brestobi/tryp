-- =========================================================================
-- TRYP ADMIN CONSOLE — Schema Extensions Migration
-- Run this in Supabase SQL Editor to add missing columns/tables needed
-- by the admin console.
-- =========================================================================

-- 1. Extend profiles with realtime driver location columns
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION;

-- 2. Extend rides with admin-needed fields
ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS surge_multiplier NUMERIC(4,2) DEFAULT 1.00,
  ADD COLUMN IF NOT EXISTS duration_mins INTEGER;

-- 3. Extend fare_schemas to be per-tier instead of a single record
ALTER TABLE public.fare_schemas
  ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'TRYP Go',
  ADD COLUMN IF NOT EXISTS per_minute_rate NUMERIC(10,2) DEFAULT 1.20,
  ADD COLUMN IF NOT EXISTS commission_percentage NUMERIC(5,2) DEFAULT 15.00,
  ADD COLUMN IF NOT EXISTS surge_multiplier NUMERIC(4,2) DEFAULT 1.00;

-- Insert the 4 TRYP vehicle tier schemas if they don't exist
INSERT INTO public.fare_schemas (id, tier, base_fare, per_km_rate, min_fare, per_minute_rate, commission_percentage, surge_multiplier, currency_symbol)
VALUES
  ('schema-go',      'TRYP Go',      18.00, 6.50, 25.00, 1.20, 15.00, 1.00, 'R'),
  ('schema-comfort', 'TRYP Comfort', 28.00, 9.00, 40.00, 1.80, 18.00, 1.00, 'R'),
  ('schema-xl',      'TRYP XL',      45.00, 12.50, 65.00, 2.50, 20.00, 1.00, 'R'),
  ('schema-exec',    'TRYP Exec',    60.00, 16.00, 90.00, 3.20, 22.00, 1.00, 'R')
ON CONFLICT (id) DO NOTHING;

-- Remove the old default record if it exists
DELETE FROM public.fare_schemas WHERE id = 'default';

-- 4. Create admin_audit_logs table
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  admin_email TEXT,
  admin_role TEXT,
  action TEXT NOT NULL,
  target_id TEXT NOT NULL,
  target_type TEXT NOT NULL,
  details TEXT,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()) NOT NULL
);

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can read audit logs" ON public.admin_audit_logs;
DROP POLICY IF EXISTS "Admins can insert audit logs" ON public.admin_audit_logs;
CREATE POLICY "Admins can read audit logs" ON public.admin_audit_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert audit logs" ON public.admin_audit_logs FOR INSERT TO authenticated WITH CHECK (true);

-- 5. Create driver_payouts table (weekly settlement records)
CREATE TABLE IF NOT EXISTS public.driver_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period TEXT NOT NULL,
  gross_earnings NUMERIC(10,2) NOT NULL DEFAULT 0,
  platform_fee NUMERIC(10,2) NOT NULL DEFAULT 0,
  net_payout NUMERIC(10,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'paid', 'flagged')),
  verified_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now()) NOT NULL
);

ALTER TABLE public.driver_payouts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage payouts" ON public.driver_payouts;
CREATE POLICY "Admins can manage payouts" ON public.driver_payouts FOR ALL TO authenticated USING (true);

-- 6. Add admin/super_admin to profiles role constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('passenger', 'driver', 'admin', 'super_admin'));

-- 7. Realtime for audit logs and payouts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'admin_audit_logs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_audit_logs;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'driver_payouts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_payouts;
  END IF;
END $$;

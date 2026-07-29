-- =========================================================================
-- TRYP PLATFORM — GRANT ADMIN PRIVILEGES SCRIPT
-- Run this script in your Supabase Dashboard SQL Editor to promote
-- bresleydimpho@gmail.com to Super Admin.
-- =========================================================================

-- 1. Allow 'admin' and 'super_admin' roles in profiles table check constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('passenger', 'driver', 'admin', 'super_admin'));

-- 2. Grant super_admin role to bresleydimpho@gmail.com in public.profiles
UPDATE public.profiles
SET role = 'super_admin'
WHERE email = 'bresleydimpho@gmail.com';

-- 3. Ensure profile entry exists if user already registered via Supabase Auth
INSERT INTO public.profiles (id, full_name, email, role, created_at, updated_at)
SELECT 
  id, 
  COALESCE(raw_user_meta_data->>'full_name', 'Dimpho Bresley'), 
  email, 
  'super_admin',
  timezone('utc', now()),
  timezone('utc', now())
FROM auth.users
WHERE email = 'bresleydimpho@gmail.com'
ON CONFLICT (id) DO UPDATE SET role = 'super_admin';

-- 4. Verify admin user role grant
SELECT id, full_name, email, role, created_at 
FROM public.profiles 
WHERE email = 'bresleydimpho@gmail.com';

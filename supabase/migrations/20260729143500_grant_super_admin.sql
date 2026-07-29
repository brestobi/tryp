-- Promote bresleydimpho@gmail.com to super_admin in profiles table
UPDATE public.profiles
SET role = 'super_admin'
WHERE email = 'bresleydimpho@gmail.com';

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

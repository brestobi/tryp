-- =========================================================================
-- TRYP PLATFORM — PROMOTE USER TO ADMIN (CLI RUNNABLE)
-- Sets BOTH:
--   1. public.profiles.role = 'super_admin'  (app-level role column)
--   2. auth.users.raw_app_meta_data.role = 'super_admin' (JWT claim)
--
-- Run via:  supabase db execute --file supabase/promote_admin_elvisshai001.sql
-- =========================================================================

DO $$
DECLARE
  target_email TEXT := 'elvisshai001@gmail.com';
  target_uid   UUID;
BEGIN
  -- 1. Get the user's UUID from auth.users
  SELECT id INTO target_uid
  FROM auth.users
  WHERE email = target_email;

  IF target_uid IS NULL THEN
    RAISE EXCEPTION 'User with email % not found in auth.users. Make sure they have registered first.', target_email;
  END IF;

  -- 2. Set the role in auth.users.raw_app_meta_data (this populates the JWT claim)
  --    This is what the new is_admin() function reads from the JWT.
  UPDATE auth.users
  SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || '{"role": "super_admin"}'::jsonb
  WHERE id = target_uid;

  -- 3. Set the role in public.profiles (app-level, used for display + driver checks)
  UPDATE public.profiles
  SET role = 'super_admin',
      updated_at = timezone('utc', now())
  WHERE id = target_uid;

  -- 4. Insert the profile if it doesn't exist yet
  INSERT INTO public.profiles (id, email, role, created_at, updated_at)
  SELECT target_uid, target_email, 'super_admin', now(), now()
  WHERE NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = target_uid);

  RAISE NOTICE 'SUCCESS: User % (%) promoted to super_admin in both auth.users and profiles.', target_email, target_uid;
END $$;

-- Verify: show the result
SELECT
  u.id,
  u.email,
  u.raw_app_meta_data ->> 'role'  AS jwt_role,
  p.role                           AS profile_role,
  u.created_at
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE u.email = 'elvisshai001@gmail.com';

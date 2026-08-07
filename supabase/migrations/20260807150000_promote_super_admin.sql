-- Promote the existing admin-console account to super_admin.
--
-- The role must be written to both locations:
--   1. auth.users.raw_app_meta_data: used by public.is_admin() in RLS
--   2. public.profiles.role: used by the admin console UI
--
-- This migration is intentionally idempotent. It fails clearly if the
-- account has not been created yet instead of silently completing without
-- granting the requested access.

DO $$
DECLARE
  target_email CONSTANT text := 'bresleydimpho@gmail.com';
  target_uid uuid;
BEGIN
  SELECT id
    INTO target_uid
  FROM auth.users
  WHERE lower(email) = lower(target_email)
  LIMIT 1;

  IF target_uid IS NULL THEN
    RAISE EXCEPTION
      'Cannot promote %: the Auth account does not exist yet.',
      target_email;
  END IF;

  -- RLS admin checks read this server-managed JWT metadata claim.
  UPDATE auth.users
  SET raw_app_meta_data =
    coalesce(raw_app_meta_data, '{}'::jsonb)
    || jsonb_build_object('role', 'super_admin')
  WHERE id = target_uid;

  -- The role-escalation trigger allows this private migration context. This
  -- avoids disabling a security trigger while still permitting the controlled
  -- administrator promotion during migration execution.
  INSERT INTO public.driver_role_claim_context (user_id)
  VALUES (target_uid)
  ON CONFLICT (user_id) DO UPDATE
    SET created_at = EXCLUDED.created_at;

  INSERT INTO public.profiles (
    id,
    email,
    role,
    created_at,
    updated_at
  )
  VALUES (
    target_uid,
    target_email,
    'super_admin',
    timezone('utc', now()),
    timezone('utc', now())
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      role = 'super_admin',
      updated_at = timezone('utc', now());

  DELETE FROM public.driver_role_claim_context
  WHERE user_id = target_uid;

  RAISE NOTICE 'Promoted % (%) to super_admin.', target_email, target_uid;
END
$$;

-- Verify both the JWT source claim and the profile role after promotion.
SELECT
  u.id,
  u.email,
  u.raw_app_meta_data ->> 'role' AS jwt_role,
  p.role AS profile_role
FROM auth.users AS u
LEFT JOIN public.profiles AS p ON p.id = u.id
WHERE lower(u.email) = lower('bresleydimpho@gmail.com');

-- Track completion of the post-auth profile setup flow.
-- Existing profiles are treated as already onboarded so this change does not
-- interrupt current users. Newly created Google profiles must complete setup.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT true;

UPDATE public.profiles
SET onboarding_completed = true
WHERE onboarding_completed IS NULL;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  signup_role text;
  is_google_user boolean;
BEGIN
  signup_role := CASE
    WHEN NEW.raw_user_meta_data->>'role' = 'driver' THEN 'driver'
    ELSE 'passenger'
  END;

  -- Supabase records the auth provider in raw_app_meta_data for identities
  -- created through Google sign-in. Email/phone signups remain complete by
  -- default because their existing flows do not use this setup screen.
  is_google_user :=
    COALESCE(NEW.raw_app_meta_data->>'provider', '') = 'google'
    OR COALESCE(NEW.raw_user_meta_data->>'provider', '') = 'google'
    OR COALESCE(NEW.raw_user_meta_data->>'iss', '') = 'https://accounts.google.com'
    OR COALESCE(NEW.raw_app_meta_data->'providers', '[]'::jsonb) ? 'google'
    OR COALESCE(NEW.raw_user_meta_data->'providers', '[]'::jsonb) ? 'google';

  INSERT INTO public.profiles (
    id,
    full_name,
    email,
    role,
    onboarding_completed
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    signup_role,
    NOT is_google_user
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.profiles.full_name),
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

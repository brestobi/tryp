-- =========================================================================
-- TRYP PLATFORM — Fix Auth Trigger Profile Insertion
-- Migration: 20260801250000_fix_auth_trigger_upsert.sql
--
-- Ensures handle_new_user() uses ON CONFLICT (id) DO UPDATE to prevent
-- primary key duplication errors during user signup across all auth providers.
-- =========================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.profiles.full_name),
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

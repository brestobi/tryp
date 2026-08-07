-- Secure the separate driver app's Google registration flow.
--
-- A Google identity created by signInWithIdToken does not carry the driver's
-- app-specific signup metadata. New Google users therefore start as passengers
-- through handle_new_user(), then the driver app may claim the driver role once.
-- Existing passenger accounts cannot use this flow because the claim is limited
-- to newly-created profiles.

CREATE TABLE IF NOT EXISTS public.driver_role_claim_context (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- This table is only a private context channel for the SECURITY DEFINER RPC.
-- Regular clients cannot read or write it.
ALTER TABLE public.driver_role_claim_context ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.driver_role_claim_context FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.prevent_profile_role_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- The claim RPC creates a locked, transaction-local context row. Admins may
  -- also change roles through the admin console. Normal users cannot change
  -- their own role or spoof the context marker.
  IF TG_OP = 'UPDATE'
     AND OLD.role IS DISTINCT FROM NEW.role
     AND NOT EXISTS (
       SELECT 1 FROM public.driver_role_claim_context
       WHERE user_id = NEW.id
     )
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Profile role changes are restricted to approved server flows or administrators';
  END IF;

  -- A normal driver may submit onboarding only once from pending to
  -- under_review. Admin review remains the authority for all other states.
  IF TG_OP = 'UPDATE'
     AND OLD.driver_status IS DISTINCT FROM NEW.driver_status
     AND NOT public.is_admin()
     AND NOT (
       OLD.role = 'driver'
       AND OLD.driver_status = 'pending'
       AND NEW.driver_status = 'under_review'
     ) THEN
    RAISE EXCEPTION 'Driver status changes require administrator approval';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_prevent_role_escalation ON public.profiles;
CREATE TRIGGER profiles_prevent_role_escalation
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_profile_role_escalation();

CREATE OR REPLACE FUNCTION public.claim_driver_role()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_id uuid := auth.uid();
  existing_role text;
  auth_created_at timestamptz;
BEGIN
  IF caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required';
  END IF;

  SELECT role
    INTO existing_role
  FROM public.profiles
  WHERE id = caller_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Driver profile was not found';
  END IF;

  -- Read creation time from auth.users, not profiles. Users can update their
  -- own profile fields, but cannot rewrite the Auth account creation time.
  SELECT created_at
    INTO auth_created_at
  FROM auth.users
  WHERE id = caller_id;

  IF NOT FOUND OR auth_created_at IS NULL THEN
    RAISE EXCEPTION 'Authenticated account was not found';
  END IF;

  -- Idempotent for a driver who retries the registration button.
  IF existing_role = 'driver' THEN
    RETURN;
  END IF;

  IF existing_role <> 'passenger'
     OR auth_created_at < timezone('utc', now()) - interval '10 minutes' THEN
    RAISE EXCEPTION 'Existing passenger accounts cannot register as drivers through Google';
  END IF;

  INSERT INTO public.driver_role_claim_context (user_id)
  VALUES (caller_id)
  ON CONFLICT (user_id) DO UPDATE SET created_at = EXCLUDED.created_at;

  UPDATE public.profiles
  SET role = 'driver',
      driver_status = 'pending',
      updated_at = timezone('utc', now())
  WHERE id = caller_id;

  DELETE FROM public.driver_role_claim_context
  WHERE user_id = caller_id;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_driver_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_driver_role() TO authenticated;

-- Granular admin roles for the TRYP console.
--
-- `profiles.role` remains `admin` / `super_admin` for backwards-compatible
-- authentication and existing RLS. `profiles.admin_role` is the console's
-- scoped role and is read by the admin application after authentication.
-- Legacy admin accounts are intentionally promoted to super_admin until a
-- super admin assigns a narrower role.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS admin_role TEXT;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_admin_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_admin_role_check
  CHECK (
    admin_role IS NULL
    OR admin_role IN ('super_admin', 'kyc_officer', 'fleet_dispatcher', 'finance_manager')
  );

UPDATE public.profiles
SET admin_role = CASE
  WHEN role = 'super_admin' THEN 'super_admin'
  WHEN role = 'admin' THEN COALESCE(admin_role, 'super_admin')
  ELSE NULL
END
WHERE role IN ('admin', 'super_admin');

CREATE INDEX IF NOT EXISTS idx_profiles_admin_role
  ON public.profiles(admin_role)
  WHERE admin_role IS NOT NULL;

-- A profile's admin_role is never self-service. Existing super_admin accounts
-- may assign roles; all other callers must leave the value unchanged. This
-- protects the new column even while older broad profile policies remain in
-- place and before permission-specific RLS is rolled out.
CREATE OR REPLACE FUNCTION public.prevent_admin_role_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  jwt_role TEXT := coalesce(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() ->> 'role',
    ''
  );
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.admin_role IS DISTINCT FROM OLD.admin_role
     AND NOT (
       public.is_admin()
       AND (jwt_role = 'super_admin' OR OLD.admin_role = 'super_admin')
     ) THEN
    RAISE EXCEPTION 'Only a super admin may assign admin console roles';
  END IF;

  IF TG_OP = 'INSERT'
     AND NEW.admin_role IS NOT NULL
     AND NOT (public.is_admin() AND jwt_role = 'super_admin') THEN
    RAISE EXCEPTION 'Only a super admin may create an admin console role';
  END IF;

  IF NEW.admin_role IS NOT NULL
     AND NEW.role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Only admin profiles may have an admin console role';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_prevent_admin_role_escalation ON public.profiles;
CREATE TRIGGER profiles_prevent_admin_role_escalation
  BEFORE INSERT OR UPDATE OF admin_role, role ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_admin_role_escalation();

COMMENT ON COLUMN public.profiles.admin_role IS
  'Scoped TRYP admin-console role. NULL for passengers and drivers; legacy admin accounts default to super_admin.';

-- Migration: 20260729161500_harden_rls_security_policies.sql
-- Description: Enable RLS and implement role-based access control across all core database tables

-- 1. Helper security function to verify if user has admin/super_admin role
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Profiles RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles read" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile or admin" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile or admin" ON public.profiles;
DROP POLICY IF EXISTS "Admins can delete profiles" ON public.profiles;

CREATE POLICY "Users can read own profile or admin"
  ON public.profiles FOR SELECT TO authenticated
  USING (id = auth.uid() OR public.is_admin() OR role = 'driver');

CREATE POLICY "Users can update own profile or admin"
  ON public.profiles FOR UPDATE TO authenticated
  USING (id = auth.uid() OR public.is_admin())
  WITH CHECK (id = auth.uid() OR public.is_admin());

CREATE POLICY "Admins can delete profiles"
  ON public.profiles FOR DELETE TO authenticated
  USING (public.is_admin());


-- 3. Rides RLS
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read relevant rides" ON public.rides;
DROP POLICY IF EXISTS "Passengers can request rides" ON public.rides;
DROP POLICY IF EXISTS "Drivers or admins can update rides" ON public.rides;

CREATE POLICY "Users can read relevant rides"
  ON public.rides FOR SELECT TO authenticated
  USING (
    passenger_id = auth.uid() OR
    driver_id = auth.uid() OR
    public.is_admin() OR
    (status = 'requested' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'driver'))
  );

CREATE POLICY "Passengers can request rides"
  ON public.rides FOR INSERT TO authenticated
  WITH CHECK (passenger_id = auth.uid() OR public.is_admin());

CREATE POLICY "Drivers or admins can update rides"
  ON public.rides FOR UPDATE TO authenticated
  USING (
    passenger_id = auth.uid() OR
    driver_id = auth.uid() OR
    public.is_admin() OR
    (driver_id IS NULL AND status = 'requested')
  )
  WITH CHECK (
    passenger_id = auth.uid() OR
    driver_id = auth.uid() OR
    public.is_admin() OR
    (driver_id IS NULL AND status = 'requested')
  );


-- 4. Fare Schemas RLS
ALTER TABLE public.fare_schemas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users read fare schemas" ON public.fare_schemas;
DROP POLICY IF EXISTS "Admins manage fare schemas" ON public.fare_schemas;

CREATE POLICY "Authenticated users read fare schemas"
  ON public.fare_schemas FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Admins manage fare schemas"
  ON public.fare_schemas FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- 5. Saved Places RLS
ALTER TABLE public.saved_places ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own saved places" ON public.saved_places;

CREATE POLICY "Users manage own saved places"
  ON public.saved_places FOR ALL TO authenticated
  USING (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());


-- 6. Driver Payouts RLS
ALTER TABLE public.driver_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage payouts" ON public.driver_payouts;
DROP POLICY IF EXISTS "Drivers can view own payouts" ON public.driver_payouts;
DROP POLICY IF EXISTS "Only admins can modify payouts" ON public.driver_payouts;

CREATE POLICY "Drivers can view own payouts"
  ON public.driver_payouts FOR SELECT TO authenticated
  USING (driver_id = auth.uid() OR public.is_admin());

CREATE POLICY "Only admins can modify payouts"
  ON public.driver_payouts FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- 7. Admin Audit Logs RLS
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can read audit logs" ON public.admin_audit_logs;
DROP POLICY IF EXISTS "Admins can insert audit logs" ON public.admin_audit_logs;
DROP POLICY IF EXISTS "Strict admin audit log read" ON public.admin_audit_logs;
DROP POLICY IF EXISTS "Strict admin audit log insert" ON public.admin_audit_logs;

CREATE POLICY "Strict admin audit log read"
  ON public.admin_audit_logs FOR SELECT TO authenticated
  USING (public.is_admin());

CREATE POLICY "Strict admin audit log insert"
  ON public.admin_audit_logs FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

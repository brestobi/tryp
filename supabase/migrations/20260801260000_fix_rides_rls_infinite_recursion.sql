-- =========================================================================
-- TRYP PLATFORM — Fix Rides & Profiles RLS Infinite Recursion (Code 42P17)
-- Migration: 20260801260000_fix_rides_rls_infinite_recursion.sql
--
-- Resolves PostgrestException: infinite recursion detected in policy for relation "rides"
-- (Error 42P17) caused by circular RLS dependencies between public.rides and public.profiles.
--
-- Solution:
-- Encapsulate cross-table checks into STABLE SECURITY DEFINER functions so that
-- internal policy subqueries bypass recursive evaluation of target table RLS policies.
-- =========================================================================

-- 0. Re-define is_admin() using JWT claim (prevents profiles table query recursion)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role'),
    (auth.jwt() ->> 'role'),
    ''
  ) IN ('admin', 'super_admin');
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- 1. Helper function to check driver status without triggering profiles RLS
CREATE OR REPLACE FUNCTION public.is_approved_driver(p_uid UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_uid
      AND role = 'driver'
      AND driver_status = 'approved'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_approved_driver(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_approved_driver(UUID) TO service_role;

-- 2. Helper function to check online driver status without triggering profiles RLS
CREATE OR REPLACE FUNCTION public.is_online_approved_driver(p_uid UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_uid
      AND role = 'driver'
      AND driver_status = 'approved'
      AND is_online = true
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_online_approved_driver(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_online_approved_driver(UUID) TO service_role;

-- 3. Helper function to check active trip participant status without triggering rides RLS
CREATE OR REPLACE FUNCTION public.has_active_ride_with(p_target_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rides
    WHERE (
      (passenger_id = auth.uid() AND driver_id = p_target_id)
      OR
      (driver_id = auth.uid() AND passenger_id = p_target_id)
    )
    AND status IN ('accepted', 'arrived', 'in_trip')
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.has_active_ride_with(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_active_ride_with(UUID) TO service_role;


-- 4. Re-define Profiles SELECT policy using SECURITY DEFINER helper
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile or admin" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles read access" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles read" ON public.profiles;

CREATE POLICY "profiles_select_policy"
  ON public.profiles FOR SELECT TO authenticated
  USING (
    -- Own profile
    id = auth.uid()
    -- Admin can see any profile
    OR public.is_admin()
    -- Passenger or Driver can see counterparty of an active ride
    OR public.has_active_ride_with(id)
  );


-- 5. Re-define Rides SELECT & UPDATE policies using SECURITY DEFINER helpers
DROP POLICY IF EXISTS "rides_select_policy" ON public.rides;
DROP POLICY IF EXISTS "Users can read own rides" ON public.rides;
DROP POLICY IF EXISTS "Users can read relevant rides" ON public.rides;

CREATE POLICY "rides_select_policy"
  ON public.rides FOR SELECT TO authenticated
  USING (
    passenger_id = auth.uid()
    OR driver_id = auth.uid()
    OR public.is_admin()
    -- Approved drivers can see open ride requests to accept them
    OR (
      status = 'requested'
      AND driver_id IS NULL
      AND public.is_approved_driver(auth.uid())
    )
  );

DROP POLICY IF EXISTS "rides_update_policy" ON public.rides;
DROP POLICY IF EXISTS "Participants can update rides" ON public.rides;
DROP POLICY IF EXISTS "Drivers or admins can update rides" ON public.rides;

CREATE POLICY "rides_update_policy"
  ON public.rides FOR UPDATE TO authenticated
  USING (
    -- Passenger can cancel their own ride
    passenger_id = auth.uid()
    -- Assigned driver can update their own active ride
    OR driver_id = auth.uid()
    -- Admin can update any ride
    OR public.is_admin()
    -- Verified approved driver can claim an UNCLAIMED requested ride ONLY
    OR (
      driver_id IS NULL
      AND status = 'requested'
      AND public.is_online_approved_driver(auth.uid())
    )
  )
  WITH CHECK (
    passenger_id = auth.uid()
    OR driver_id = auth.uid()
    OR public.is_admin()
    OR (
      driver_id IS NULL
      AND status = 'requested'
      AND public.is_online_approved_driver(auth.uid())
    )
  );

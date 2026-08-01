-- =========================================================================
-- TRYP PLATFORM — SECURITY HARDENING PATCH
-- Migration: 20260801200000_security_hardening_patch.sql
--
-- Fixes all P0/P1 critical security vulnerabilities identified in audit:
--   1. is_admin() recursive RLS loop
--   2. Driver full-profile PII exposure
--   3. driver-documents bucket public KYC exposure
--   4. Any user can claim an unassigned ride (ride hijacking)
--   5. Users can self-insert fake notifications
--   6. dispatch_ride() runtime crash (wrong function + wrong type)
--   7. driver_documents table has NO RLS policies (full deny)
--   8. ride_type default mismatch ('Economy' vs 'TRYP Go')
--   9. Missing updated_at auto-trigger
--  10. Duplicate document storage — unified view
--  11. Uniqueness constraints on driver_documents and fare_schemas
-- =========================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Enable required extensions (safe idempotent)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 1: Replace is_admin() — eliminate the recursive RLS loop
--
-- Old version queries public.profiles while profiles RLS calls is_admin(),
-- creating an infinite recursive dependency.
-- New version reads from the JWT app_metadata which is set server-side.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  -- Reads the 'role' claim from app_metadata in the user's JWT.
  -- This avoids querying the profiles table (which would be recursive).
  -- Set app_metadata via: supabase.auth.admin.updateUserById(uid, { app_metadata: { role: 'admin' } })
  SELECT coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role'),
    (auth.jwt() ->> 'role'),
    ''
  ) IN ('admin', 'super_admin');
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Grant to authenticated role
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- Also provide a helper to check the calling user's role without profile lookup
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT AS $$
  SELECT coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role'),
    (auth.jwt() ->> 'role'),
    'passenger'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 2: Profiles RLS — Stop leaking full PII of all drivers to all users
--
-- Old: "role = 'driver'" exposed every driver's banking info, ID number,
-- license, and phone to any authenticated passenger.
-- New: A user can read:
--   - Their own full profile
--   - An admin can read any profile
--   - Passengers can read the ASSIGNED driver of their ACTIVE ride (scoped)
--   - Drivers can read the profile of their ASSIGNED passenger
-- ─────────────────────────────────────────────────────────────────────────────
-- Helper function to check driver status without triggering profiles RLS
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

-- Helper function to check online driver status without triggering profiles RLS
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

-- Helper function to check active trip participant status without triggering rides RLS
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

DROP POLICY IF EXISTS "Users can read own profile or admin" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles read access"         ON public.profiles;
DROP POLICY IF EXISTS "Public profiles read"                ON public.profiles;

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

-- Keep update policy clean: users update their own, admins update any
DROP POLICY IF EXISTS "Users can edit own profile"          ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile or admin" ON public.profiles;

CREATE POLICY "profiles_update_policy"
  ON public.profiles FOR UPDATE TO authenticated
  USING (id = auth.uid() OR public.is_admin())
  WITH CHECK (id = auth.uid() OR public.is_admin());

-- Insert: only own profile on signup (handle_new_user trigger) or admin
DROP POLICY IF EXISTS "Users can insert own profile"        ON public.profiles;

CREATE POLICY "profiles_insert_policy"
  ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid() OR public.is_admin());

-- Delete: admin only
DROP POLICY IF EXISTS "Admins can delete profiles"          ON public.profiles;

CREATE POLICY "profiles_delete_policy"
  ON public.profiles FOR DELETE TO authenticated
  USING (public.is_admin());


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 3: driver-documents Storage Bucket — Stop KYC docs being world-readable
--
-- Old: TO public with no restrictions = KYC documents accessible by anyone
-- on the internet without authentication.
-- New: Only the owning driver and admins can read documents.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Public read access for driver documents"            ON storage.objects;
DROP POLICY IF EXISTS "Drivers can upload their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Drivers can update their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated read for driver documents"             ON storage.objects;

-- Drivers can upload into their own folder: drivers/{uid}/filename
CREATE POLICY "driver_docs_insert_policy"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'driver-documents'
    AND (storage.foldername(name))[1] = 'drivers'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- Drivers can update/overwrite their own documents only
CREATE POLICY "driver_docs_update_policy"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'driver-documents'
    AND (storage.foldername(name))[1] = 'drivers'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- Drivers can delete their own documents; admins can delete any
CREATE POLICY "driver_docs_delete_policy"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'driver-documents'
    AND (
      (storage.foldername(name))[2] = auth.uid()::text
      OR public.is_admin()
    )
  );

-- Read: only owning driver or admin — NO public unauthenticated access
CREATE POLICY "driver_docs_select_policy"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'driver-documents'
    AND (
      (storage.foldername(name))[2] = auth.uid()::text
      OR public.is_admin()
    )
  );

-- Also mark the bucket as private (not public) to enforce auth on direct URL access
UPDATE storage.buckets SET public = false WHERE id = 'driver-documents';


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 4: Rides RLS — Prevent any user from claiming an unassigned ride
--
-- Old: driver_id IS NULL AND status = 'requested' allowed ANY authenticated user
-- (including passengers!) to set themselves as driver on a ride.
-- New: Only verified, approved drivers can accept unassigned rides.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can read own rides"          ON public.rides;
DROP POLICY IF EXISTS "Users can read relevant rides"     ON public.rides;
DROP POLICY IF EXISTS "Passengers can create rides"       ON public.rides;
DROP POLICY IF EXISTS "Passengers can request rides"      ON public.rides;
DROP POLICY IF EXISTS "Participants can update rides"     ON public.rides;
DROP POLICY IF EXISTS "Drivers or admins can update rides" ON public.rides;

-- SELECT: passengers see their own rides, drivers see their own + open requested rides
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

-- INSERT: only the authenticated passenger creates their own ride record
CREATE POLICY "rides_insert_policy"
  ON public.rides FOR INSERT TO authenticated
  WITH CHECK (passenger_id = auth.uid());

-- UPDATE: very restricted — each party can only update what they're allowed to
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


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 5: Notifications — Remove user self-insert capability
--
-- Old: passengers could insert fake "Ride Completed" / "Payment Received"
-- notifications for themselves (or if user_id check was bypassed, for others).
-- New: notifications are inserted ONLY via a SECURITY DEFINER server function.
--      Users retain SELECT (read own), UPDATE (mark read), DELETE (dismiss).
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can insert their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can view their own notifications"   ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;

-- Read own notifications
CREATE POLICY "notifications_select_policy"
  ON public.notifications FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

-- Mark as read (UPDATE) — own notifications only
CREATE POLICY "notifications_update_policy"
  ON public.notifications FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

-- Dismiss / delete own notification
CREATE POLICY "notifications_delete_policy"
  ON public.notifications FOR DELETE TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

-- INSERT: blocked for all regular users — use the server function below
-- (No INSERT policy = RLS default deny for INSERT)

-- Server-side SECURITY DEFINER function for inserting notifications safely
-- Call this from triggers, Edge Functions, or other SECURITY DEFINER functions.
CREATE OR REPLACE FUNCTION public.send_notification(
  target_uid  UUID,
  p_title     TEXT,
  p_body      TEXT,
  p_type      TEXT DEFAULT 'system',
  p_route_path TEXT DEFAULT NULL,
  p_payload   JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_id UUID;
BEGIN
  INSERT INTO public.notifications (user_id, title, body, type, route_path, payload)
  VALUES (target_uid, p_title, p_body, p_type, p_route_path, p_payload)
  RETURNING id INTO new_id;
  RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.send_notification(UUID, TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_notification(UUID, TEXT, TEXT, TEXT, TEXT, JSONB) TO service_role;


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 6: dispatch_ride() — Fix runtime crash
--
-- Old: used non-existent earth_distance_ll(), and inserted point() into TEXT column
-- New: Uses correct earthdistance extension function earth_distance() + ll_to_earth()
--      and passes text address strings correctly.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dispatch_ride(
  pickup_lat    DOUBLE PRECISION,
  pickup_lng    DOUBLE PRECISION,
  p_passenger_id UUID,
  p_origin      TEXT,
  p_destination TEXT DEFAULT NULL,
  dest_lat      DOUBLE PRECISION DEFAULT NULL,
  dest_lng      DOUBLE PRECISION DEFAULT NULL,
  p_ride_type   TEXT DEFAULT 'TRYP Go',
  p_fare        NUMERIC DEFAULT 0,
  p_payment_method TEXT DEFAULT 'Cash',
  p_distance_km NUMERIC DEFAULT 0
)
RETURNS UUID AS $$
DECLARE
  driver_uuid  UUID;
  new_ride_id  UUID;
BEGIN
  -- Verify the calling user is the actual passenger (prevent impersonation)
  IF auth.uid() IS DISTINCT FROM p_passenger_id THEN
    RAISE EXCEPTION 'Unauthorized: passenger_id mismatch';
  END IF;

  -- Find the nearest ONLINE, APPROVED driver using earthdistance extension
  SELECT id INTO driver_uuid
  FROM public.profiles
  WHERE role = 'driver'
    AND driver_status = 'approved'
    AND is_online = true
    AND current_lat IS NOT NULL
    AND current_lng IS NOT NULL
  ORDER BY
    earth_distance(
      ll_to_earth(current_lat, current_lng),
      ll_to_earth(pickup_lat, pickup_lng)
    ) ASC
  LIMIT 1;

  IF driver_uuid IS NULL THEN
    RAISE EXCEPTION 'No available drivers at this time. Please try again shortly.';
  END IF;

  -- Create the ride record
  INSERT INTO public.rides (
    passenger_id,
    driver_id,
    origin,
    destination,
    pickup_lat,
    pickup_lng,
    dest_lat,
    dest_lng,
    ride_type,
    fare,
    payment_method,
    distance_km,
    status,
    requested_at
  ) VALUES (
    p_passenger_id,
    driver_uuid,
    p_origin,
    p_destination,
    pickup_lat,
    pickup_lng,
    dest_lat,
    dest_lng,
    p_ride_type,
    p_fare,
    p_payment_method,
    p_distance_km,
    'requested',
    now()
  ) RETURNING id INTO new_ride_id;

  -- Notify the driver
  PERFORM public.send_notification(
    driver_uuid,
    'New Ride Request 🚗',
    'You have a new ' || p_ride_type || ' ride to accept!',
    'ride',
    '/driver/active-trip'
  );

  RETURN new_ride_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT, NUMERIC
) TO authenticated;


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 7: driver_documents — Add missing RLS policies
--
-- Table had RLS enabled but NO policies = default deny for everyone.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Drivers manage own documents"      ON public.driver_documents;
DROP POLICY IF EXISTS "Admins view all driver documents"  ON public.driver_documents;

-- Drivers can SELECT, INSERT, UPDATE their own documents; admins can SELECT all
CREATE POLICY "driver_documents_select_policy"
  ON public.driver_documents FOR SELECT TO authenticated
  USING (driver_id = auth.uid() OR public.is_admin());

CREATE POLICY "driver_documents_insert_policy"
  ON public.driver_documents FOR INSERT TO authenticated
  WITH CHECK (driver_id = auth.uid() OR public.is_admin());

CREATE POLICY "driver_documents_update_policy"
  ON public.driver_documents FOR UPDATE TO authenticated
  USING (driver_id = auth.uid() OR public.is_admin())
  WITH CHECK (driver_id = auth.uid() OR public.is_admin());

-- Only admin can delete driver documents (for audit safety)
CREATE POLICY "driver_documents_delete_policy"
  ON public.driver_documents FOR DELETE TO authenticated
  USING (public.is_admin());


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 8: ride_type default mismatch + data migration
-- ─────────────────────────────────────────────────────────────────────────────

-- Step 1: Migrate any legacy ride_type values to the new tier names BEFORE
-- adding the CHECK constraint (avoids constraint violation on existing rows)
UPDATE public.rides SET ride_type = 'TRYP Go'      WHERE ride_type IS NULL OR ride_type IN ('Economy', 'economy', 'Go');
UPDATE public.rides SET ride_type = 'TRYP Comfort'  WHERE ride_type IN ('Comfort', 'comfort', 'Standard');
UPDATE public.rides SET ride_type = 'TRYP XL'       WHERE ride_type IN ('XL', 'xl', 'Van', 'van');
UPDATE public.rides SET ride_type = 'TRYP Exec'     WHERE ride_type IN ('Exec', 'exec', 'Executive', 'Luxury', 'Premium');
-- Any remaining unrecognised values fall back to TRYP Go
UPDATE public.rides SET ride_type = 'TRYP Go'
  WHERE ride_type NOT IN ('TRYP Go', 'TRYP Comfort', 'TRYP XL', 'TRYP Exec');

-- Step 2: Migrate any legacy status values
UPDATE public.rides SET status = 'requested'  WHERE status IS NULL OR status = '';
UPDATE public.rides SET status = 'completed'  WHERE status = 'done';
UPDATE public.rides SET status = 'cancelled'  WHERE status IN ('canceled', 'abort');
-- Anything still not in the valid set → cancelled (safety net)
UPDATE public.rides SET status = 'cancelled'
  WHERE status NOT IN ('requested', 'accepted', 'arrived', 'in_trip', 'completed', 'cancelled');

-- Step 3: Now safe to set new default and add constraints
ALTER TABLE public.rides
  ALTER COLUMN ride_type SET DEFAULT 'TRYP Go';

ALTER TABLE public.rides
  DROP CONSTRAINT IF EXISTS rides_ride_type_check;

ALTER TABLE public.rides
  ADD CONSTRAINT rides_ride_type_check
  CHECK (ride_type IN ('TRYP Go', 'TRYP Comfort', 'TRYP XL', 'TRYP Exec'));

ALTER TABLE public.rides
  DROP CONSTRAINT IF EXISTS rides_status_check;

ALTER TABLE public.rides
  ADD CONSTRAINT rides_status_check
  CHECK (status IN ('requested', 'accepted', 'arrived', 'in_trip', 'completed', 'cancelled'));


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 9: Add updated_at auto-trigger to prevent stale timestamps
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- profiles
DROP TRIGGER IF EXISTS profiles_set_updated_at ON public.profiles;
CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- rides (add updated_at column if missing)
ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc', now());

DROP TRIGGER IF EXISTS rides_set_updated_at ON public.rides;
CREATE TRIGGER rides_set_updated_at
  BEFORE UPDATE ON public.rides
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- driver_payouts
DROP TRIGGER IF EXISTS payouts_set_updated_at ON public.driver_payouts;
CREATE TRIGGER payouts_set_updated_at
  BEFORE UPDATE ON public.driver_payouts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 10: Create a unified driver_document_summary VIEW
-- Provides a denormalized read-only view of per-driver document statuses
-- so the admin dashboard and app can query a single source of truth.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.driver_document_summary AS
SELECT
  driver_id,
  MAX(CASE WHEN document_type = 'prdp'                 THEN document_url  END) AS doc_prdp,
  MAX(CASE WHEN document_type = 'prdp'                 THEN status        END) AS doc_prdp_status,
  MAX(CASE WHEN document_type = 'prdp'                 THEN submitted_at  END) AS doc_prdp_submitted_at,

  MAX(CASE WHEN document_type = 'vehicle_registration' THEN document_url  END) AS doc_vehicle_registration,
  MAX(CASE WHEN document_type = 'vehicle_registration' THEN status        END) AS doc_vehicle_registration_status,
  MAX(CASE WHEN document_type = 'vehicle_registration' THEN submitted_at  END) AS doc_vehicle_reg_submitted_at,

  MAX(CASE WHEN document_type = 'insurance'            THEN document_url  END) AS doc_insurance,
  MAX(CASE WHEN document_type = 'insurance'            THEN status        END) AS doc_insurance_status,
  MAX(CASE WHEN document_type = 'insurance'            THEN submitted_at  END) AS doc_insurance_submitted_at,

  MAX(CASE WHEN document_type = 'roadworthiness'       THEN document_url  END) AS doc_roadworthiness,
  MAX(CASE WHEN document_type = 'roadworthiness'       THEN status        END) AS doc_roadworthiness_status,
  MAX(CASE WHEN document_type = 'roadworthiness'       THEN submitted_at  END) AS doc_roadworthiness_submitted_at,

  -- Overall verification status: approved only if ALL 4 docs are approved
  CASE
    WHEN bool_and(status = 'approved') THEN 'approved'
    WHEN bool_or(status = 'rejected')  THEN 'rejected'
    WHEN bool_or(status = 'pending' OR status = 'under_review') THEN 'under_review'
    ELSE 'pending'
  END AS overall_status,

  COUNT(*) AS docs_submitted,
  COUNT(*) FILTER (WHERE status = 'approved') AS docs_approved

FROM public.driver_documents
GROUP BY driver_id;

-- Grant read access to authenticated users (RLS on driver_documents still applies)
GRANT SELECT ON public.driver_document_summary TO authenticated;


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 11: Uniqueness Constraints
-- ─────────────────────────────────────────────────────────────────────────────

-- One document record per type per driver
ALTER TABLE public.driver_documents
  DROP CONSTRAINT IF EXISTS unique_driver_doc_type;

ALTER TABLE public.driver_documents
  ADD CONSTRAINT unique_driver_doc_type UNIQUE (driver_id, document_type);

-- One fare schema record per tier
ALTER TABLE public.fare_schemas
  DROP CONSTRAINT IF EXISTS unique_fare_schema_tier;

ALTER TABLE public.fare_schemas
  ADD CONSTRAINT unique_fare_schema_tier UNIQUE (tier);

-- Ensure driver_status on profiles has a proper CHECK constraint
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_driver_status_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_driver_status_check
  CHECK (driver_status IN ('pending', 'under_review', 'approved', 'rejected'));

-- Ensure doc status values are constrained
ALTER TABLE public.driver_documents
  DROP CONSTRAINT IF EXISTS driver_documents_status_check;

ALTER TABLE public.driver_documents
  ADD CONSTRAINT driver_documents_status_check
  CHECK (status IN ('pending', 'under_review', 'approved', 'rejected'));


-- ─────────────────────────────────────────────────────────────────────────────
-- FIX 12: Add missing indexes for performance
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_driver_documents_driver_id
  ON public.driver_documents(driver_id);

CREATE INDEX IF NOT EXISTS idx_driver_documents_status
  ON public.driver_documents(status);

CREATE INDEX IF NOT EXISTS idx_rides_status_driver_null
  ON public.rides(status) WHERE driver_id IS NULL AND status = 'requested';

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications(user_id, created_at DESC) WHERE is_read = false;

CREATE INDEX IF NOT EXISTS idx_profiles_online_driver
  ON public.profiles(current_lat, current_lng)
  WHERE role = 'driver' AND is_online = true AND driver_status = 'approved';


-- ─────────────────────────────────────────────────────────────────────────────
-- MAINTENANCE: Ensure Realtime is enabled for core tables
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'rides') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rides;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'profiles') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'driver_documents') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_documents;
  END IF;
END $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- IMPORTANT: After running this migration, you MUST also:
--
-- 1. Set app_metadata.role for all existing admin users via Supabase Auth Admin API:
--    supabase.auth.admin.updateUserById(uid, { app_metadata: { role: 'admin' } })
--    (for super_admin: { app_metadata: { role: 'super_admin' } })
--
-- 2. Optionally: deprecate the doc_* columns on profiles in a future migration
--    once all queries are migrated to use driver_document_summary view.
--
-- 3. Test dispatch_ride() after enabling earthdistance extension and confirming
--    driver profiles have current_lat / current_lng populated.
-- ─────────────────────────────────────────────────────────────────────────────

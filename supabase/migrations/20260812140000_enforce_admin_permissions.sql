-- Server-side companion to the admin console's granular role model.
-- Frontend checks improve UX, but these helpers are the authorization boundary
-- for direct PostgREST/RPC calls as well.

CREATE OR REPLACE FUNCTION public.get_my_admin_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'admin_role',
    (
      SELECT p.admin_role
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('admin', 'super_admin')
    ),
    CASE
      WHEN COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() ->> 'role') = 'super_admin'
        THEN 'super_admin'
      WHEN COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() ->> 'role') = 'admin'
        THEN 'super_admin'
      ELSE NULL
    END
  );
$$;

CREATE OR REPLACE FUNCTION public.has_admin_permission(p_permission TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE public.get_my_admin_role()
    WHEN 'super_admin' THEN true
    WHEN 'kyc_officer' THEN p_permission IN ('dashboard:read', 'kyc:read', 'kyc:write', 'users:read', 'audit:read')
    WHEN 'fleet_dispatcher' THEN p_permission IN ('dashboard:read', 'fleet:read', 'fleet:write', 'users:read', 'audit:read')
    WHEN 'finance_manager' THEN p_permission IN ('dashboard:read', 'fares:read', 'finance:read', 'finance:write', 'users:read', 'audit:read', 'statements:read')
    ELSE false
  END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_admin_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_admin_permission(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_admin_role() TO service_role;
GRANT EXECUTE ON FUNCTION public.has_admin_permission(TEXT) TO service_role;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  -- Keep the recursion-safe JWT check used by the existing RLS hardening.
  -- Granular permissions use has_admin_permission() below.
  SELECT COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() ->> 'role',
    ''
  ) IN ('admin', 'super_admin');
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO service_role;

-- Fare publishing is finance/super-admin work; read access remains available
-- to authenticated app users through the existing read policy.
DROP POLICY IF EXISTS "Admins manage fare schemas" ON public.fare_schemas;
CREATE POLICY "Admins manage fare schemas"
  ON public.fare_schemas FOR ALL TO authenticated
  USING (public.has_admin_permission('fares:write'))
  WITH CHECK (public.has_admin_permission('fares:write'));

-- Payout verification and wallet data are finance-scoped.
DROP POLICY IF EXISTS "Only admins can modify payouts" ON public.driver_payouts;
DROP POLICY IF EXISTS "Admins can manage payouts" ON public.driver_payouts;
CREATE POLICY "Finance admins can manage payouts"
  ON public.driver_payouts FOR ALL TO authenticated
  USING (public.has_admin_permission('finance:write'))
  WITH CHECK (public.has_admin_permission('finance:write'));

DROP POLICY IF EXISTS "Drivers and admins can read driver wallets" ON public.driver_wallets;
CREATE POLICY "Drivers and finance admins can read driver wallets"
  ON public.driver_wallets FOR SELECT TO authenticated
  USING (driver_id = auth.uid() OR public.has_admin_permission('finance:read'));

DROP POLICY IF EXISTS "Drivers and admins can read wallet transactions" ON public.driver_wallet_transactions;
CREATE POLICY "Drivers and finance admins can read wallet transactions"
  ON public.driver_wallet_transactions FOR SELECT TO authenticated
  USING (driver_id = auth.uid() OR public.has_admin_permission('finance:read'));

-- KYC officers own document and passenger-identity review actions.
DROP POLICY IF EXISTS "driver_documents_select_policy" ON public.driver_documents;
DROP POLICY IF EXISTS "driver_documents_update_policy" ON public.driver_documents;
DROP POLICY IF EXISTS "driver_documents_delete_policy" ON public.driver_documents;
CREATE POLICY "driver_documents_select_policy"
  ON public.driver_documents FOR SELECT TO authenticated
  USING (driver_id = auth.uid() OR public.has_admin_permission('kyc:read'));
CREATE POLICY "driver_documents_update_policy"
  ON public.driver_documents FOR UPDATE TO authenticated
  USING (driver_id = auth.uid() OR public.has_admin_permission('kyc:write'))
  WITH CHECK (driver_id = auth.uid() OR public.has_admin_permission('kyc:write'));
CREATE POLICY "driver_documents_delete_policy"
  ON public.driver_documents FOR DELETE TO authenticated
  USING (public.has_admin_permission('kyc:write'));

DROP POLICY IF EXISTS "Passengers can view own verification" ON public.passenger_verifications;
CREATE POLICY "Passengers and KYC admins can view verification"
  ON public.passenger_verifications FOR SELECT TO authenticated
  USING (passenger_id = auth.uid() OR public.has_admin_permission('kyc:read'));
DROP POLICY IF EXISTS "Admins can update passenger verification" ON public.passenger_verifications;
CREATE POLICY "KYC admins can update passenger verification"
  ON public.passenger_verifications FOR UPDATE TO authenticated
  USING (public.has_admin_permission('kyc:write'))
  WITH CHECK (public.has_admin_permission('kyc:write'));

-- The signed-document bucket must follow the same KYC permission boundary.
DROP POLICY IF EXISTS "Passengers and admins read verification images" ON storage.objects;
CREATE POLICY "Passengers and KYC admins read verification images"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'passenger-verification'
    AND (
      (storage.foldername(name))[2] = auth.uid()::text
      OR public.has_admin_permission('kyc:read')
    )
  );
DROP POLICY IF EXISTS "Passengers and admins delete verification images" ON storage.objects;
CREATE POLICY "Passengers and KYC admins delete verification images"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'passenger-verification'
    AND (
      (storage.foldername(name))[2] = auth.uid()::text
      OR public.has_admin_permission('kyc:write')
    )
  );

DROP POLICY IF EXISTS "driver_docs_select_policy" ON storage.objects;
CREATE POLICY "driver_docs_select_policy"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'driver-documents'
    AND (
      (storage.foldername(name))[2] = auth.uid()::text
      OR public.has_admin_permission('kyc:read')
    )
  );
DROP POLICY IF EXISTS "driver_docs_delete_policy" ON storage.objects;
CREATE POLICY "driver_docs_delete_policy"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'driver-documents'
    AND (
      (storage.foldername(name))[2] = auth.uid()::text
      OR public.has_admin_permission('kyc:write')
    )
  );

-- All scoped roles may read and write audit entries for their permitted work;
-- only the server-side role is trusted for the permission decision.
DROP POLICY IF EXISTS "Strict admin audit log read" ON public.admin_audit_logs;
DROP POLICY IF EXISTS "Strict admin audit log insert" ON public.admin_audit_logs;
CREATE POLICY "Scoped admins can read audit logs"
  ON public.admin_audit_logs FOR SELECT TO authenticated
  USING (public.has_admin_permission('audit:read'));
CREATE POLICY "Scoped admins can insert audit logs"
  ON public.admin_audit_logs FOR INSERT TO authenticated
  WITH CHECK (public.has_admin_permission('audit:read'));

-- Broadcasts are intentionally limited to super_admin in the current role map.
CREATE OR REPLACE FUNCTION public.broadcast_notification(
  p_title TEXT,
  p_body TEXT,
  p_type TEXT DEFAULT 'system',
  p_route_path TEXT DEFAULT NULL,
  p_payload JSONB DEFAULT NULL,
  p_target_role TEXT DEFAULT 'all'
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  IF NOT public.has_admin_permission('broadcast:write') THEN
    RAISE EXCEPTION 'Only authorised administrators can broadcast notifications.';
  END IF;
  IF p_target_role NOT IN ('all', 'passenger', 'driver') THEN
    RAISE EXCEPTION 'Invalid target role "%".', p_target_role;
  END IF;
  IF p_type NOT IN ('ride', 'promo', 'system', 'payment') THEN
    RAISE EXCEPTION 'Invalid notification type "%".', p_type;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, route_path, payload)
  SELECT p.id, public.strip_notification_emoji(p_title), public.strip_notification_emoji(p_body), p_type, p_route_path, p_payload
  FROM public.profiles p
  WHERE p.role IN ('passenger', 'driver')
    AND (p_target_role = 'all' OR p.role = p_target_role);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.broadcast_notification(TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.broadcast_notification(TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) TO service_role;

-- Dispatch overrides are fleet-scoped. Passengers and assigned drivers retain
-- their normal lifecycle access through the existing participant predicates.
DROP POLICY IF EXISTS "rides_update_policy" ON public.rides;
CREATE POLICY "rides_update_policy"
  ON public.rides FOR UPDATE TO authenticated
  USING (
    passenger_id = auth.uid()
    OR driver_id = auth.uid()
    OR public.has_admin_permission('fleet:write')
    OR (
      driver_id IS NULL
      AND status = 'requested'
      AND public.is_online_approved_driver(auth.uid())
    )
  )
  WITH CHECK (
    passenger_id = auth.uid()
    OR driver_id = auth.uid()
    OR public.has_admin_permission('fleet:write')
    OR (
      driver_id IS NULL
      AND status = 'requested'
      AND public.is_online_approved_driver(auth.uid())
    )
  );

-- Only super admins may delete or promote profiles. KYC officers need profile
-- update access for driver_status review; the existing role-escalation trigger
-- continues to prevent them from changing the base role.
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
CREATE POLICY "profiles_update_policy"
  ON public.profiles FOR UPDATE TO authenticated
  USING (
    id = auth.uid()
    OR public.has_admin_permission('users:write')
    OR public.has_admin_permission('kyc:write')
  )
  WITH CHECK (
    id = auth.uid()
    OR public.has_admin_permission('users:write')
    OR public.has_admin_permission('kyc:write')
  );

DROP POLICY IF EXISTS "profiles_delete_policy" ON public.profiles;
CREATE POLICY "profiles_delete_policy"
  ON public.profiles FOR DELETE TO authenticated
  USING (public.has_admin_permission('users:write'));

-- Make audit actor fields server-authoritative rather than trusting values from
-- the browser. Action/target/details remain the submitted case information.
CREATE OR REPLACE FUNCTION public.set_admin_audit_actor()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.admin_id := auth.uid();
  NEW.admin_email := COALESCE(auth.jwt() ->> 'email', NEW.admin_email);
  NEW.admin_role := public.get_my_admin_role();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS admin_audit_logs_set_actor ON public.admin_audit_logs;
CREATE TRIGGER admin_audit_logs_set_actor
  BEFORE INSERT ON public.admin_audit_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.set_admin_audit_actor();

-- Harden the existing profile role/status trigger for scoped admin roles.
CREATE OR REPLACE FUNCTION public.prevent_profile_role_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.role IS DISTINCT FROM NEW.role
     AND NOT EXISTS (
       SELECT 1 FROM public.driver_role_claim_context
       WHERE user_id = NEW.id
     )
     AND NOT public.has_admin_permission('admin:manage') THEN
    RAISE EXCEPTION 'Profile role changes require a super admin';
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.driver_status IS DISTINCT FROM NEW.driver_status
     AND NOT public.has_admin_permission('kyc:write')
     AND NOT (
       OLD.role = 'driver'
       AND OLD.driver_status = 'pending'
       AND NEW.driver_status = 'under_review'
     ) THEN
    RAISE EXCEPTION 'Driver status changes require KYC approval';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_prevent_role_escalation ON public.profiles;
CREATE TRIGGER profiles_prevent_role_escalation
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_profile_role_escalation();

-- KYC officers may review driver_status, but may not use broad profile RLS
-- access to edit identity, banking, wallet, vehicle, or online-state fields.
CREATE OR REPLACE FUNCTION public.prevent_kyc_profile_overreach()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND auth.uid() IS DISTINCT FROM NEW.id
     AND public.get_my_admin_role() = 'kyc_officer'
     AND (
       NEW.full_name IS DISTINCT FROM OLD.full_name
       OR NEW.email IS DISTINCT FROM OLD.email
       OR NEW.phone IS DISTINCT FROM OLD.phone
       OR NEW.role IS DISTINCT FROM OLD.role
       OR NEW.admin_role IS DISTINCT FROM OLD.admin_role
       OR NEW.avatar_url IS DISTINCT FROM OLD.avatar_url
       OR NEW.id_number IS DISTINCT FROM OLD.id_number
       OR NEW.license_number IS DISTINCT FROM OLD.license_number
       OR NEW.vehicle_make IS DISTINCT FROM OLD.vehicle_make
       OR NEW.vehicle_model IS DISTINCT FROM OLD.vehicle_model
       OR NEW.vehicle_year IS DISTINCT FROM OLD.vehicle_year
       OR NEW.vehicle_color IS DISTINCT FROM OLD.vehicle_color
       OR NEW.vehicle_plate IS DISTINCT FROM OLD.vehicle_plate
       OR NEW.operating_city IS DISTINCT FROM OLD.operating_city
       OR NEW.bank_name IS DISTINCT FROM OLD.bank_name
       OR NEW.bank_account_number IS DISTINCT FROM OLD.bank_account_number
       OR NEW.bank_branch_code IS DISTINCT FROM OLD.bank_branch_code
       OR NEW.bank_account_holder IS DISTINCT FROM OLD.bank_account_holder
       OR NEW.wallet_balance IS DISTINCT FROM OLD.wallet_balance
       OR NEW.rating IS DISTINCT FROM OLD.rating
       OR NEW.is_online IS DISTINCT FROM OLD.is_online
       OR NEW.current_lat IS DISTINCT FROM OLD.current_lat
       OR NEW.current_lng IS DISTINCT FROM OLD.current_lng
       OR NEW.passenger_verification_status IS DISTINCT FROM OLD.passenger_verification_status
     ) THEN
    RAISE EXCEPTION 'KYC officers may only update driver verification status';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_prevent_kyc_overreach ON public.profiles;
CREATE TRIGGER profiles_prevent_kyc_overreach
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_kyc_profile_overreach();

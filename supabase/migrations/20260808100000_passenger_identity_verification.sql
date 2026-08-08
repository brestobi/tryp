-- Passenger identity verification: camera-captured ID + live selfie held together.
-- Files remain private and are only exposed through short-lived signed URLs to
-- the submitting passenger or an authenticated admin reviewer.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS passenger_verification_status TEXT NOT NULL DEFAULT 'unverified';

-- Prevent a passenger from self-approving by updating their own profile. The
-- review RPC sets the transaction-local flag immediately before its trusted
-- status update.
CREATE OR REPLACE FUNCTION public.prevent_passenger_verification_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.passenger_verification_status <> 'unverified' THEN
    RAISE EXCEPTION 'Passenger verification status is managed by the review workflow.';
  END IF;
  IF TG_OP = 'UPDATE'
     AND NEW.passenger_verification_status IS DISTINCT FROM OLD.passenger_verification_status
     AND COALESCE(current_setting('tryp.passenger_verification_write', true), '') <> 'true' THEN
    RAISE EXCEPTION 'Passenger verification status is managed by the review workflow.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_passenger_verification_escalation ON public.profiles;
CREATE TRIGGER prevent_passenger_verification_escalation
  BEFORE INSERT OR UPDATE OF passenger_verification_status ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_passenger_verification_escalation();

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_passenger_verification_status_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_passenger_verification_status_check
  CHECK (passenger_verification_status IN ('unverified', 'pending', 'under_review', 'approved', 'rejected'));

CREATE TABLE IF NOT EXISTS public.passenger_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  id_document_path TEXT NOT NULL,
  selfie_path TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'under_review', 'approved', 'rejected')),
  review_notes TEXT,
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_passenger_verifications_status
  ON public.passenger_verifications(status);
CREATE INDEX IF NOT EXISTS idx_passenger_verifications_passenger
  ON public.passenger_verifications(passenger_id);

ALTER TABLE public.passenger_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Passengers can view own verification" ON public.passenger_verifications;
CREATE POLICY "Passengers can view own verification"
  ON public.passenger_verifications FOR SELECT TO authenticated
  USING (passenger_id = auth.uid() OR public.is_admin());

-- Passenger submissions are written through submit_passenger_verification(),
-- not direct table updates. This prevents a passenger from changing a rejected
-- row directly to approved.
DROP POLICY IF EXISTS "Passengers can update rejected verification" ON public.passenger_verifications;

DROP POLICY IF EXISTS "Admins can update passenger verification" ON public.passenger_verifications;
CREATE POLICY "Admins can update passenger verification"
  ON public.passenger_verifications FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP TRIGGER IF EXISTS passenger_verifications_set_updated_at ON public.passenger_verifications;
CREATE TRIGGER passenger_verifications_set_updated_at
  BEFORE UPDATE ON public.passenger_verifications
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- A private bucket is mandatory for ID documents and selfies.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'passenger-verification',
  'passenger-verification',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DROP POLICY IF EXISTS "Passengers upload own verification images" ON storage.objects;
CREATE POLICY "Passengers upload own verification images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'passenger-verification'
    AND (storage.foldername(name))[1] = 'passengers'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Passengers update own verification images" ON storage.objects;
CREATE POLICY "Passengers update own verification images"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'passenger-verification'
    AND (storage.foldername(name))[1] = 'passengers'
    AND (storage.foldername(name))[2] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'passenger-verification'
    AND (storage.foldername(name))[1] = 'passengers'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Passengers and admins read verification images" ON storage.objects;
CREATE POLICY "Passengers and admins read verification images"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'passenger-verification'
    AND (
      (storage.foldername(name))[2] = auth.uid()::text
      OR public.is_admin()
    )
  );

DROP POLICY IF EXISTS "Passengers and admins delete verification images" ON storage.objects;
CREATE POLICY "Passengers and admins delete verification images"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'passenger-verification'
    AND (
      (storage.foldername(name))[2] = auth.uid()::text
      OR public.is_admin()
    )
  );

CREATE OR REPLACE FUNCTION public.submit_passenger_verification(
  p_id_document_path TEXT,
  p_selfie_path TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  verification_id UUID;
  expected_prefix TEXT := 'passengers/' || auth.uid()::text || '/';
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication is required.';
  END IF;

  IF p_id_document_path IS NULL OR p_selfie_path IS NULL
     OR p_id_document_path NOT LIKE expected_prefix || '%'
     OR p_selfie_path NOT LIKE expected_prefix || '%' THEN
    RAISE EXCEPTION 'Verification files must belong to the authenticated passenger.';
  END IF;

  INSERT INTO public.passenger_verifications (
    passenger_id, id_document_path, selfie_path, status,
    review_notes, reviewed_by, reviewed_at, submitted_at
  ) VALUES (
    auth.uid(), p_id_document_path, p_selfie_path, 'pending',
    NULL, NULL, NULL, timezone('utc', now())
  )
  ON CONFLICT (passenger_id) DO UPDATE SET
    id_document_path = EXCLUDED.id_document_path,
    selfie_path = EXCLUDED.selfie_path,
    status = 'pending',
    review_notes = NULL,
    reviewed_by = NULL,
    reviewed_at = NULL,
    submitted_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  RETURNING id INTO verification_id;

  PERFORM set_config('tryp.passenger_verification_write', 'true', true);
  UPDATE public.profiles
  SET passenger_verification_status = 'pending',
      updated_at = timezone('utc', now())
  WHERE id = auth.uid();

  RETURN verification_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_passenger_verification(TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.review_passenger_verification(
  p_verification_id UUID,
  p_status TEXT,
  p_review_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  verification_passenger UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admins can review passenger verification.';
  END IF;

  IF p_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Review status must be approved or rejected.';
  END IF;

  SELECT passenger_id INTO verification_passenger
  FROM public.passenger_verifications
  WHERE id = p_verification_id
  FOR UPDATE;

  IF verification_passenger IS NULL THEN
    RAISE EXCEPTION 'Passenger verification submission was not found.';
  END IF;

  UPDATE public.passenger_verifications
  SET status = p_status,
      review_notes = NULLIF(trim(COALESCE(p_review_notes, '')), ''),
      reviewed_by = auth.uid(),
      reviewed_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  WHERE id = p_verification_id;

  PERFORM set_config('tryp.passenger_verification_write', 'true', true);
  UPDATE public.profiles
  SET passenger_verification_status = p_status,
      updated_at = timezone('utc', now())
  WHERE id = verification_passenger;

  RETURN p_verification_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.review_passenger_verification(UUID, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.is_verified_passenger(p_uid UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN public.passenger_verifications v ON v.passenger_id = p.id
    WHERE p.id = p_uid
      AND p.role = 'passenger'
      AND v.status = 'approved'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_verified_passenger(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_verified_passenger(UUID) TO service_role;

-- Rebuild the canonical dispatch function with a server-side verification gate.
CREATE OR REPLACE FUNCTION public.dispatch_ride(
  pickup_lat DOUBLE PRECISION,
  pickup_lng DOUBLE PRECISION,
  p_passenger_id UUID,
  p_origin TEXT,
  p_destination TEXT DEFAULT NULL,
  dest_lat DOUBLE PRECISION DEFAULT NULL,
  dest_lng DOUBLE PRECISION DEFAULT NULL,
  p_ride_type TEXT DEFAULT 'TRYP Go',
  p_fare NUMERIC DEFAULT 0,
  p_payment_method TEXT DEFAULT 'Cash',
  p_distance_km NUMERIC DEFAULT 0,
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  new_ride_id UUID;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_passenger_id THEN
    RAISE EXCEPTION 'Unauthorized: passenger_id mismatch';
  END IF;

  IF NOT public.is_verified_passenger(p_passenger_id) THEN
    RAISE EXCEPTION 'Passenger verification is required before requesting rides.';
  END IF;

  INSERT INTO public.rides (
    passenger_id, origin, destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, ride_type, fare, payment_method,
    distance_km, payment_status, metadata, status, requested_at
  ) VALUES (
    p_passenger_id, p_origin, p_destination, pickup_lat, pickup_lng,
    dest_lat, dest_lng, p_ride_type, p_fare, p_payment_method,
    p_distance_km, 'pending', p_metadata, 'requested', now()
  ) RETURNING id INTO new_ride_id;

  RETURN new_ride_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_ride(
  DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, NUMERIC, TEXT, NUMERIC, JSONB
) TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'passenger_verifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.passenger_verifications;
  END IF;
END $$;

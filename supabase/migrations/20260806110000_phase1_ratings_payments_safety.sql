-- TRYP Phase 1: ratings, payment state, and safety incidents

-- ─────────────────────────────────────────────────────────────────────────────
-- Ratings and reviews
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ride_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  rater_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  ratee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (ride_id, rater_id),
  CHECK (rater_id <> ratee_id)
);

ALTER TABLE public.ride_ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ride_ratings_select_policy" ON public.ride_ratings;
CREATE POLICY "ride_ratings_select_policy"
  ON public.ride_ratings FOR SELECT TO authenticated
  USING (
    rater_id = auth.uid()
    OR ratee_id = auth.uid()
    OR public.is_admin()
  );

-- Ratings are submitted through the participant-checked RPC below.
DROP POLICY IF EXISTS "ride_ratings_insert_policy" ON public.ride_ratings;

CREATE OR REPLACE FUNCTION public.submit_ride_rating(
  p_ride_id UUID,
  p_rating INTEGER,
  p_review TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_ride public.rides;
  v_ratee_id UUID;
  v_rating_id UUID;
BEGIN
  IF p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'Rating must be between 1 and 5.';
  END IF;

  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id;

  IF v_ride.id IS NULL OR v_ride.status <> 'completed' THEN
    RAISE EXCEPTION 'Only completed rides can be rated.';
  END IF;

  IF auth.uid() = v_ride.passenger_id THEN
    v_ratee_id := v_ride.driver_id;
  ELSIF auth.uid() = v_ride.driver_id THEN
    v_ratee_id := v_ride.passenger_id;
  ELSE
    RAISE EXCEPTION 'Only ride participants can submit a rating.';
  END IF;

  IF v_ratee_id IS NULL THEN
    RAISE EXCEPTION 'This ride has no participant to rate.';
  END IF;

  INSERT INTO public.ride_ratings (ride_id, rater_id, ratee_id, rating, review)
  VALUES (p_ride_id, auth.uid(), v_ratee_id, p_rating, NULLIF(trim(p_review), ''))
  ON CONFLICT (ride_id, rater_id) DO UPDATE
  SET rating = EXCLUDED.rating,
      review = EXCLUDED.review,
      updated_at = timezone('utc', now())
  RETURNING id INTO v_rating_id;

  UPDATE public.profiles
  SET rating = (
    SELECT round(avg(rr.rating)::numeric, 2)
    FROM public.ride_ratings rr
    WHERE rr.ratee_id = v_ratee_id
  )
  WHERE id = v_ratee_id;

  RETURN v_rating_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.submit_ride_rating(UUID, INTEGER, TEXT) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Payment state transitions
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.rides
  DROP CONSTRAINT IF EXISTS rides_payment_status_check;

-- Normalize values written by older clients before adding the stricter check.
UPDATE public.rides
SET payment_status = 'pending'
WHERE payment_status IS NULL
   OR payment_status NOT IN ('pending', 'processing', 'paid', 'failed', 'cancelled');

ALTER TABLE public.rides
  ADD CONSTRAINT rides_payment_status_check
  CHECK (payment_status IN ('pending', 'processing', 'paid', 'failed', 'cancelled'));

CREATE OR REPLACE FUNCTION public.set_ride_payment_status(
  p_ride_id UUID,
  p_status TEXT,
  p_reference TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_ride public.rides;
  v_is_trusted BOOLEAN := public.is_admin() OR auth.role() = 'service_role';
BEGIN
  IF p_status NOT IN ('pending', 'processing', 'paid', 'failed', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid payment status.';
  END IF;

  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id
  FOR UPDATE;

  IF v_ride.id IS NULL THEN
    RAISE EXCEPTION 'Ride not found.';
  END IF;

  IF NOT v_is_trusted
     AND auth.uid() IS DISTINCT FROM v_ride.passenger_id THEN
    RAISE EXCEPTION 'Only the passenger or an admin can update ride payment.';
  END IF;

  -- Passenger clients may only create/update their own checkout state. Only a
  -- trusted admin/webhook path may finalize an online payment as paid.
  IF NOT v_is_trusted AND p_status NOT IN ('pending', 'processing', 'failed', 'cancelled') THEN
    RAISE EXCEPTION 'Passengers cannot finalize ride payments.';
  END IF;

  IF p_status = 'paid' AND NOT v_is_trusted THEN
    RAISE EXCEPTION 'Online payments must be verified by the payment webhook.';
  END IF;

  -- Once settled, a client callback cannot regress a payment to failed or
  -- cancelled. Refunds/chargebacks must use a separate trusted workflow.
  IF v_ride.payment_status = 'paid' AND NOT v_is_trusted
     AND p_status <> 'paid' THEN
    RAISE EXCEPTION 'A settled payment cannot be changed by the passenger.';
  END IF;

  IF p_status = 'paid' AND v_ride.payment_method <> 'Cash'
     AND NULLIF(trim(COALESCE(p_reference, v_ride.payment_reference)), '') IS NULL THEN
    RAISE EXCEPTION 'A payment reference is required for online payments.';
  END IF;

  UPDATE public.rides
  SET payment_status = p_status,
      payment_reference = COALESCE(NULLIF(trim(p_reference), ''), payment_reference)
  WHERE id = p_ride_id;

  RETURN p_ride_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.set_ride_payment_status(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_ride_payment_status(UUID, TEXT, TEXT) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- Safety incidents / SOS reports
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.safety_incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID REFERENCES public.rides(id) ON DELETE SET NULL,
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  incident_type TEXT NOT NULL CHECK (incident_type IN ('emergency', 'unsafe_driving', 'medical', 'harassment', 'other')),
  message TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'resolved')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  resolved_at TIMESTAMPTZ
);

ALTER TABLE public.safety_incidents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "safety_incidents_select_policy" ON public.safety_incidents;
CREATE POLICY "safety_incidents_select_policy"
  ON public.safety_incidents FOR SELECT TO authenticated
  USING (
    reporter_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.rides r
      WHERE r.id = safety_incidents.ride_id
        AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
    )
  );

CREATE OR REPLACE FUNCTION public.create_safety_incident(
  p_ride_id UUID DEFAULT NULL,
  p_incident_type TEXT DEFAULT 'emergency',
  p_message TEXT DEFAULT NULL,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_ride public.rides;
  v_incident_id UUID;
BEGIN
  IF p_incident_type NOT IN ('emergency', 'unsafe_driving', 'medical', 'harassment', 'other') THEN
    RAISE EXCEPTION 'Invalid safety incident type.';
  END IF;

  IF p_ride_id IS NOT NULL THEN
    SELECT * INTO v_ride FROM public.rides WHERE id = p_ride_id;
    IF v_ride.id IS NULL THEN
      RAISE EXCEPTION 'Ride not found.';
    END IF;
    IF auth.uid() IS DISTINCT FROM v_ride.passenger_id
       AND auth.uid() IS DISTINCT FROM v_ride.driver_id THEN
      RAISE EXCEPTION 'Only ride participants can report an incident.';
    END IF;
  END IF;

  INSERT INTO public.safety_incidents (
    ride_id, reporter_id, incident_type, message, latitude, longitude
  ) VALUES (
    p_ride_id, auth.uid(), p_incident_type, NULLIF(trim(p_message), ''), p_latitude, p_longitude
  ) RETURNING id INTO v_incident_id;

  RETURN v_incident_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.create_safety_incident(UUID, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

CREATE OR REPLACE FUNCTION public.update_safety_incident_status(
  p_incident_id UUID,
  p_status TEXT
)
RETURNS UUID AS $$
DECLARE
  v_incident public.safety_incidents;
BEGIN
  IF NOT (public.is_admin() OR auth.role() = 'service_role') THEN
    RAISE EXCEPTION 'Only safety administrators can update incident status.';
  END IF;

  IF p_status NOT IN ('acknowledged', 'resolved') THEN
    RAISE EXCEPTION 'Invalid safety incident status.';
  END IF;

  SELECT * INTO v_incident
  FROM public.safety_incidents
  WHERE id = p_incident_id
  FOR UPDATE;

  IF v_incident.id IS NULL THEN
    RAISE EXCEPTION 'Safety incident not found.';
  END IF;

  IF v_incident.status = 'resolved' THEN
    RAISE EXCEPTION 'Resolved safety incidents cannot be reopened.';
  END IF;

  UPDATE public.safety_incidents
  SET status = p_status,
      resolved_at = CASE
        WHEN p_status = 'resolved' THEN COALESCE(resolved_at, timezone('utc', now()))
        ELSE NULL
      END
  WHERE id = p_incident_id;

  RETURN p_incident_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.update_safety_incident_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_safety_incident_status(UUID, TEXT) TO service_role;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'ride_ratings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ride_ratings;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'safety_incidents'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.safety_incidents;
  END IF;
END $$;

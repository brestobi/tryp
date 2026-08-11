-- Secure long-distance booking lifecycle.
-- Booking creation, seat reservation, payment settlement, and booking status
-- changes are server-controlled. The client can only read its own bookings.

ALTER TABLE public.long_distance_trips
  ADD COLUMN IF NOT EXISTS seats_reserved INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.long_distance_bookings
  ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS payment_reference TEXT,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

ALTER TABLE public.long_distance_bookings
  DROP CONSTRAINT IF EXISTS long_distance_bookings_payment_status_check;
ALTER TABLE public.long_distance_bookings
  ADD CONSTRAINT long_distance_bookings_payment_status_check
  CHECK (payment_status IN ('pending', 'processing', 'paid', 'failed', 'cancelled'));

ALTER TABLE public.long_distance_bookings
  DROP CONSTRAINT IF EXISTS long_distance_bookings_seats_check;
ALTER TABLE public.long_distance_bookings
  ADD CONSTRAINT long_distance_bookings_seats_check
  CHECK (seats BETWEEN 1 AND 8);

ALTER TABLE public.long_distance_trips
  DROP CONSTRAINT IF EXISTS long_distance_trips_seats_reserved_check;
ALTER TABLE public.long_distance_trips
  ADD CONSTRAINT long_distance_trips_seats_reserved_check
  CHECK (seats_reserved >= 0 AND seats_reserved <= seats_available);

CREATE INDEX IF NOT EXISTS idx_long_distance_trips_active_departure
  ON public.long_distance_trips (departure_at)
  WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_long_distance_bookings_trip_status
  ON public.long_distance_bookings (trip_id, status, expires_at);

-- Normalize records created by the original client-side flow before applying
-- the active-booking uniqueness rule. A passenger may retain their newest
-- confirmed booking; stale/pending duplicates are cancelled.
UPDATE public.long_distance_bookings
SET expires_at = COALESCE(expires_at, created_at + interval '30 minutes')
WHERE status = 'pending' AND expires_at IS NULL;

WITH duplicate_active AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY trip_id, passenger_id
           ORDER BY (status = 'confirmed') DESC, created_at DESC, id DESC
         ) AS duplicate_rank
  FROM public.long_distance_bookings
  WHERE status IN ('pending', 'confirmed')
)
UPDATE public.long_distance_bookings b
SET status = 'cancelled', payment_status = 'cancelled'
FROM duplicate_active d
WHERE b.id = d.id AND d.duplicate_rank > 1;

-- Rebuild counters for legacy rows so the new atomic model reflects
-- bookings created before this migration was installed.
UPDATE public.long_distance_bookings
SET payment_status = 'paid'
WHERE status = 'confirmed' AND payment_status = 'pending';
UPDATE public.long_distance_bookings
SET status = 'cancelled', payment_status = 'cancelled'
WHERE status = 'pending'
  AND expires_at <= timezone('utc', now());

UPDATE public.long_distance_trips t
SET seats_booked = COALESCE(confirmed.seats, 0)
FROM (
  SELECT trip_id, SUM(seats)::INTEGER AS seats
  FROM public.long_distance_bookings
  WHERE status = 'confirmed' AND payment_status = 'paid'
  GROUP BY trip_id
) confirmed
WHERE t.id = confirmed.trip_id;
UPDATE public.long_distance_trips
SET seats_booked = 0
WHERE NOT EXISTS (
  SELECT 1 FROM public.long_distance_bookings b
  WHERE b.trip_id = public.long_distance_trips.id
    AND b.status = 'confirmed' AND b.payment_status = 'paid'
);

UPDATE public.long_distance_trips t
SET seats_reserved = COALESCE(active_pending.seats, 0)
FROM (
  SELECT trip_id, SUM(seats)::INTEGER AS seats
  FROM public.long_distance_bookings
  WHERE status = 'pending'
    AND expires_at > timezone('utc', now())
  GROUP BY trip_id
) active_pending
WHERE t.id = active_pending.trip_id;
UPDATE public.long_distance_trips
SET seats_reserved = 0
WHERE NOT EXISTS (
  SELECT 1 FROM public.long_distance_bookings b
  WHERE b.trip_id = public.long_distance_trips.id
    AND b.status = 'pending'
    AND b.expires_at > timezone('utc', now())
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_long_distance_one_active_booking_per_passenger
  ON public.long_distance_bookings (trip_id, passenger_id)
  WHERE status IN ('pending', 'confirmed');

ALTER TABLE public.long_distance_trips
  DROP CONSTRAINT IF EXISTS long_distance_trips_seat_totals_check;
ALTER TABLE public.long_distance_trips
  ADD CONSTRAINT long_distance_trips_seat_totals_check
  CHECK (seats_available >= 1 AND seats_booked >= 0 AND seats_reserved >= 0
         AND seats_booked + seats_reserved <= seats_available);
ALTER TABLE public.long_distance_trips
  DROP CONSTRAINT IF EXISTS long_distance_trips_price_check;
ALTER TABLE public.long_distance_trips
  ADD CONSTRAINT long_distance_trips_price_check CHECK (price_per_seat > 0);

DROP POLICY IF EXISTS "drivers_manage_own_ld_trips" ON public.long_distance_trips;
DROP POLICY IF EXISTS "passengers_view_active_ld_trips" ON public.long_distance_trips;
DROP POLICY IF EXISTS "passengers_manage_own_bookings" ON public.long_distance_bookings;
DROP POLICY IF EXISTS "drivers_view_trip_bookings" ON public.long_distance_bookings;

CREATE POLICY "long_distance_trips_select_policy"
  ON public.long_distance_trips FOR SELECT TO authenticated
  USING (status = 'active' OR driver_id = auth.uid());

CREATE POLICY "long_distance_trips_insert_policy"
  ON public.long_distance_trips FOR INSERT TO authenticated
  WITH CHECK (
    driver_id = auth.uid()
    AND public.is_approved_driver(auth.uid())
  );

CREATE POLICY "long_distance_trips_update_policy"
  ON public.long_distance_trips FOR UPDATE TO authenticated
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());

CREATE POLICY "long_distance_bookings_select_policy"
  ON public.long_distance_bookings FOR SELECT TO authenticated
  USING (
    passenger_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.long_distance_trips t
      WHERE t.id = trip_id AND t.driver_id = auth.uid()
    )
  );

-- No direct INSERT/UPDATE/DELETE policies are granted to passengers. The
-- SECURITY DEFINER RPCs below enforce ownership and authoritative pricing.

CREATE OR REPLACE FUNCTION public.prevent_client_long_distance_counter_edits()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_setting('tryp.long_distance_internal', true) = 'true'
     OR auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF auth.role() <> 'service_role' THEN
      IF NEW.driver_id IS DISTINCT FROM auth.uid()
         OR NOT public.is_approved_driver(auth.uid()) THEN
        RAISE EXCEPTION 'Only an approved driver may create this listing.';
      END IF;
      NEW.seats_booked := 0;
      NEW.seats_reserved := 0;
      NEW.status := 'active';
    END IF;
    RETURN NEW;
  END IF;

  IF auth.role() <> 'service_role' AND (
    NEW.driver_id IS DISTINCT FROM OLD.driver_id OR
    NEW.seats_booked IS DISTINCT FROM OLD.seats_booked OR
    NEW.seats_reserved IS DISTINCT FROM OLD.seats_reserved
  ) THEN
    RAISE EXCEPTION 'Seat counters and driver ownership are server-controlled.';
  END IF;
  IF auth.role() <> 'service_role' AND OLD.seats_booked > 0 AND (
    NEW.origin IS DISTINCT FROM OLD.origin OR
    NEW.destination IS DISTINCT FROM OLD.destination OR
    NEW.departure_at IS DISTINCT FROM OLD.departure_at OR
    NEW.seats_available IS DISTINCT FROM OLD.seats_available OR
    NEW.price_per_seat IS DISTINCT FROM OLD.price_per_seat
  ) THEN
    RAISE EXCEPTION 'Route, capacity, departure, and price cannot change after booking.';
  END IF;

  -- A driver may cancel a listing, but cannot mark it completed or cancel a
  -- trip after a paid passenger has been accepted. Pending reservations are
  -- released as part of the same row update.
  IF auth.role() <> 'service_role' AND NEW.status IS DISTINCT FROM OLD.status THEN
    IF OLD.status <> 'active' OR NEW.status <> 'cancelled' THEN
      RAISE EXCEPTION 'Only active listings may be cancelled.';
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.long_distance_bookings
      WHERE trip_id = OLD.id AND status = 'confirmed'
    ) THEN
      RAISE EXCEPTION 'A trip with confirmed passengers cannot be cancelled.';
    END IF;
    UPDATE public.long_distance_bookings
    SET status = 'cancelled', payment_status = 'cancelled'
    WHERE trip_id = OLD.id AND status = 'pending';
    NEW.seats_reserved := 0;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_long_distance_counter_edits
  ON public.long_distance_trips;
CREATE TRIGGER protect_long_distance_counter_edits
  BEFORE UPDATE ON public.long_distance_trips
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_client_long_distance_counter_edits();

CREATE OR REPLACE FUNCTION public.create_long_distance_booking(
  p_trip_id UUID,
  p_seats INTEGER DEFAULT 1
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_trip public.long_distance_trips;
  v_booking_id UUID;
  v_expired_seats INTEGER := 0;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication is required.'; END IF;
  PERFORM set_config('tryp.long_distance_internal', 'true', true);
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'passenger'
  ) THEN
    RAISE EXCEPTION 'Only passenger accounts can book long-distance trips.';
  END IF;
  IF p_seats IS NULL OR p_seats < 1 OR p_seats > 8 THEN
    RAISE EXCEPTION 'Seats must be between 1 and 8.';
  END IF;

  SELECT * INTO v_trip
  FROM public.long_distance_trips
  WHERE id = p_trip_id
  FOR UPDATE;
  IF v_trip.id IS NULL THEN RAISE EXCEPTION 'Trip not found.'; END IF;
  IF v_trip.status <> 'active' OR v_trip.departure_at <= timezone('utc', now()) THEN
    RAISE EXCEPTION 'This trip is no longer available.';
  END IF;
  IF NOT public.is_approved_driver(v_trip.driver_id) THEN
    RAISE EXCEPTION 'This driver is not currently approved.';
  END IF;

  WITH expired AS (
    UPDATE public.long_distance_bookings
    SET status = 'cancelled', payment_status = 'cancelled'
    WHERE trip_id = v_trip.id
      AND status = 'pending'
      AND expires_at IS NOT NULL
      AND expires_at <= timezone('utc', now())
    RETURNING seats
  )
  SELECT COALESCE(SUM(seats), 0)::INTEGER INTO v_expired_seats FROM expired;

  IF v_expired_seats > 0 THEN
    UPDATE public.long_distance_trips
    SET seats_reserved = GREATEST(0, seats_reserved - v_expired_seats)
    WHERE id = v_trip.id;
    v_trip.seats_reserved := GREATEST(0, v_trip.seats_reserved - v_expired_seats);
  END IF;

  IF v_trip.seats_available - v_trip.seats_booked - v_trip.seats_reserved < p_seats THEN
    RAISE EXCEPTION 'Not enough seats are available.';
  END IF;

  INSERT INTO public.long_distance_bookings (
    trip_id, passenger_id, seats, amount_paid, payment_method,
    status, payment_status, expires_at
  ) VALUES (
    v_trip.id, auth.uid(), p_seats, ROUND(v_trip.price_per_seat * p_seats, 2),
    'Paystack Card', 'pending', 'pending',
    timezone('utc', now()) + interval '30 minutes'
  )
  RETURNING id INTO v_booking_id;

  UPDATE public.long_distance_trips
  SET seats_reserved = seats_reserved + p_seats
  WHERE id = v_trip.id;
  RETURN v_booking_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_long_distance_booking(UUID, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_long_distance_booking(UUID, INTEGER) TO authenticated;

CREATE OR REPLACE FUNCTION public.cancel_long_distance_booking(p_booking_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_booking public.long_distance_bookings;
BEGIN
  PERFORM set_config('tryp.long_distance_internal', 'true', true);
  SELECT * INTO v_booking
  FROM public.long_distance_bookings
  WHERE id = p_booking_id AND passenger_id = auth.uid()
  FOR UPDATE;
  IF v_booking.id IS NULL THEN RAISE EXCEPTION 'Booking not found.'; END IF;
  IF v_booking.status NOT IN ('pending', 'confirmed') THEN RETURN; END IF;
  IF v_booking.status = 'confirmed' THEN
    RAISE EXCEPTION 'A confirmed booking cannot be cancelled from the app.';
  END IF;

  UPDATE public.long_distance_bookings
  SET status = 'cancelled', payment_status = 'cancelled'
  WHERE id = v_booking.id AND payment_status IN ('pending', 'processing');
  UPDATE public.long_distance_trips
  SET seats_reserved = GREATEST(0, seats_reserved - v_booking.seats)
  WHERE id = v_booking.trip_id;
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_long_distance_booking(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_long_distance_booking(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.begin_long_distance_payment(
  p_booking_id UUID,
  p_reference TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_booking public.long_distance_bookings;
BEGIN
  IF auth.role() <> 'service_role' THEN RAISE EXCEPTION 'Only the payment server can initialize a transaction.'; END IF;
  PERFORM set_config('tryp.long_distance_internal', 'true', true);
  IF p_reference IS NULL OR p_reference !~ '^LD-[A-Za-z0-9-]{8,100}$' THEN
    RAISE EXCEPTION 'Invalid long-distance payment reference.';
  END IF;
  SELECT * INTO v_booking FROM public.long_distance_bookings WHERE id = p_booking_id FOR UPDATE;
  IF v_booking.id IS NULL THEN RAISE EXCEPTION 'Booking not found.'; END IF;
  IF v_booking.status <> 'pending' THEN RAISE EXCEPTION 'This booking is no longer payable.'; END IF;
  IF v_booking.expires_at IS NOT NULL AND v_booking.expires_at <= timezone('utc', now()) THEN
    RAISE EXCEPTION 'This booking reservation has expired.';
  END IF;
  IF v_booking.payment_status = 'paid' THEN RAISE EXCEPTION 'This booking is already paid.'; END IF;
  IF v_booking.payment_status = 'processing'
     AND v_booking.created_at > timezone('utc', now()) - interval '30 minutes' THEN
    RAISE EXCEPTION 'A payment is already being processed for this booking.';
  END IF;
  UPDATE public.long_distance_bookings
  SET payment_status = 'processing',
      payment_reference = p_reference,
      expires_at = GREATEST(
        COALESCE(expires_at, timezone('utc', now())),
        timezone('utc', now()) + interval '2 hours'
      )
  WHERE id = p_booking_id;
  RETURN p_booking_id;
END;
$$;

REVOKE ALL ON FUNCTION public.begin_long_distance_payment(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.begin_long_distance_payment(UUID, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION public.settle_long_distance_booking(
  p_booking_id UUID, p_status TEXT, p_reference TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_booking public.long_distance_bookings;
  v_trip public.long_distance_trips;
  v_result TEXT;
BEGIN
  IF auth.role() <> 'service_role' THEN RAISE EXCEPTION 'Only the payment server can settle a booking.'; END IF;
  PERFORM set_config('tryp.long_distance_internal', 'true', true);
  IF p_status NOT IN ('paid', 'failed', 'cancelled') THEN RAISE EXCEPTION 'Invalid settlement status.'; END IF;
  SELECT * INTO v_booking FROM public.long_distance_bookings WHERE id = p_booking_id FOR UPDATE;
  IF v_booking.id IS NULL THEN RAISE EXCEPTION 'Booking not found.'; END IF;
  IF v_booking.payment_status = 'paid' THEN RETURN 'paid'; END IF;
  SELECT * INTO v_trip FROM public.long_distance_trips WHERE id = v_booking.trip_id FOR UPDATE;
  IF v_trip.id IS NULL THEN RAISE EXCEPTION 'Trip not found.'; END IF;

  IF p_status = 'paid' THEN
    IF v_booking.status <> 'pending' THEN RAISE EXCEPTION 'Booking is not payable.'; END IF;
    IF v_booking.expires_at IS NOT NULL AND v_booking.expires_at <= timezone('utc', now()) THEN
      RAISE EXCEPTION 'Booking reservation has expired.';
    END IF;
    UPDATE public.long_distance_bookings
    SET status = 'confirmed', payment_status = 'paid',
        payment_reference = COALESCE(NULLIF(trim(p_reference), ''), payment_reference)
    WHERE id = p_booking_id;
    UPDATE public.long_distance_trips
    SET seats_reserved = GREATEST(0, seats_reserved - v_booking.seats),
        seats_booked = seats_booked + v_booking.seats
    WHERE id = v_trip.id;
    v_result := 'paid';
    PERFORM public.send_notification(
      v_booking.passenger_id, 'Long-distance booking confirmed',
      'Your seat from ' || v_trip.origin || ' to ' || v_trip.destination || ' is confirmed.',
      'ride', '/passenger/long-distance',
      jsonb_build_object('booking_id', v_booking.id, 'trip_id', v_trip.id)
    );
    PERFORM public.send_notification(
      v_trip.driver_id, 'New long-distance passenger',
      'A passenger booked a seat on your ' || v_trip.origin || ' to ' || v_trip.destination || ' trip.',
      'ride', '/driver/long-distance',
      jsonb_build_object('booking_id', v_booking.id, 'trip_id', v_trip.id)
    );
  ELSE
    UPDATE public.long_distance_bookings
    SET status = 'cancelled', payment_status = p_status,
        payment_reference = COALESCE(NULLIF(trim(p_reference), ''), payment_reference)
    WHERE id = p_booking_id AND status IN ('pending', 'confirmed')
      AND payment_status IN ('pending', 'processing');
    IF FOUND THEN
      UPDATE public.long_distance_trips
      SET seats_reserved = GREATEST(0, seats_reserved - v_booking.seats)
      WHERE id = v_trip.id;
    END IF;
    v_result := p_status;
  END IF;
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.settle_long_distance_booking(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.settle_long_distance_booking(UUID, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION public.get_my_long_distance_bookings()
RETURNS TABLE (
  booking_id UUID, trip_id UUID, passenger_id UUID, passenger_name TEXT,
  passenger_phone TEXT, seats INTEGER, amount_paid NUMERIC, status TEXT,
  payment_status TEXT, created_at TIMESTAMPTZ, origin TEXT,
  destination TEXT, departure_at TIMESTAMPTZ
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT b.id, b.trip_id, b.passenger_id, p.full_name, p.phone, b.seats,
         b.amount_paid, b.status, b.payment_status, b.created_at,
         t.origin, t.destination, t.departure_at
  FROM public.long_distance_bookings b
  JOIN public.long_distance_trips t ON t.id = b.trip_id
  JOIN public.profiles p ON p.id = b.passenger_id
  WHERE t.driver_id = auth.uid()
    AND b.status = 'confirmed'
    AND b.payment_status = 'paid'
    AND EXISTS (
      SELECT 1 FROM public.profiles d
      WHERE d.id = auth.uid() AND d.role = 'driver'
        AND d.driver_status IN ('approved', 'under_review')
    )
  ORDER BY b.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.get_my_long_distance_bookings() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_long_distance_bookings() TO authenticated;

-- Return only safe driver-facing fields so passenger listing queries do not
-- bypass the restricted profiles table used for KYC and banking data.
CREATE OR REPLACE FUNCTION public.get_active_long_distance_trips()
RETURNS TABLE (
  id UUID, driver_id UUID, origin TEXT, destination TEXT,
  departure_at TIMESTAMPTZ, seats_available INTEGER, seats_booked INTEGER,
  seats_reserved INTEGER, price_per_seat NUMERIC, notes TEXT, status TEXT,
  driver_name TEXT, vehicle_make TEXT, vehicle_model TEXT,
  vehicle_plate TEXT, driver_rating NUMERIC
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT t.id, t.driver_id, t.origin, t.destination, t.departure_at,
         t.seats_available, t.seats_booked, t.seats_reserved,
         t.price_per_seat, t.notes, t.status,
         p.full_name, p.vehicle_make, p.vehicle_model,
         p.vehicle_plate, p.rating
  FROM public.long_distance_trips t
  JOIN public.profiles p ON p.id = t.driver_id
  WHERE t.status = 'active'
    AND t.departure_at > timezone('utc', now())
    AND p.role = 'driver'
    AND p.driver_status = 'approved'
  ORDER BY t.departure_at ASC
  LIMIT 50;
$$;

REVOKE ALL ON FUNCTION public.get_active_long_distance_trips() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_active_long_distance_trips() TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'long_distance_trips') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.long_distance_trips;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'long_distance_bookings') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.long_distance_bookings;
  END IF;
END $$;

-- Refunds & Disputes workflow.
--
-- The TRYP admin console needs an auditable refund pipeline that:
--   * Lists every refund request initiated by the support team
--   * Tracks the underlying Paystack refund identifier so finance can reconcile
--   * Records the responsible admin and the customer-facing reason so the
--     passenger-finance team can answer disputes
--   * Allows the ride payment_status to enter a 'refunded' or 'disputed' state
--     without breaking the older migration's CHECK constraint
--
-- Server-side enforcement: refunds writes are reserved for finance and
-- super admins. KYC officers and fleet dispatchers must NOT be able to move
-- money through this table.

-- ─────────────────────────────────────────────────────────────────────────────
-- Extend ride payment_status to include refund / dispute outcomes
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.rides
  DROP CONSTRAINT IF EXISTS rides_payment_status_check;

-- Pre-existing values stay, refunds / disputes are new states written by the
-- admin console (and the paystack-refund edge function).
DO $$
DECLARE
  v_invalid_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_invalid_count
  FROM public.rides
  WHERE payment_status IS NULL
     OR payment_status NOT IN (
       'pending', 'processing', 'paid', 'failed', 'cancelled', 'refunded', 'disputed'
     );

  IF v_invalid_count > 0 THEN
    RAISE NOTICE 'Refusing to tighten rides.payment_status: % legacy rows.',
                 v_invalid_count;
    RETURN;
  END IF;

  ALTER TABLE public.rides
    ADD CONSTRAINT rides_payment_status_check
    CHECK (
      payment_status IN (
        'pending', 'processing', 'paid', 'failed', 'cancelled', 'refunded', 'disputed'
      )
    );
END
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Refunds table
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE RESTRICT,
  payment_reference TEXT NOT NULL,
  requested_amount NUMERIC(12, 2) NOT NULL CHECK (requested_amount >= 0),
  processed_amount NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (processed_amount >= 0),
  currency TEXT NOT NULL DEFAULT 'ZAR',
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'disputed')),
  paystack_refund_id TEXT,
  paystack_response JSONB,
  failure_reason TEXT,
  requested_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  passenger_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  driver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  completed_at TIMESTAMPTZ
);

COMMENT ON TABLE public.refunds IS
  'Paystack refund / dispute ledger. Every refund initiated from the admin console or the paystack-refund edge function writes here, even if Paystack subsequently fails.';

CREATE INDEX IF NOT EXISTS idx_refunds_ride_id ON public.refunds (ride_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status_created ON public.refunds (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_refunds_payment_reference ON public.refunds (payment_reference);

ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Finance admins can read refunds" ON public.refunds;
CREATE POLICY "Finance admins can read refunds"
  ON public.refunds FOR SELECT TO authenticated
  USING (public.has_admin_permission('finance:read'));

DROP POLICY IF EXISTS "Finance admins can create refunds" ON public.refunds;
CREATE POLICY "Finance admins can create refunds"
  ON public.refunds FOR INSERT TO authenticated
  WITH CHECK (
    public.has_admin_permission('finance:write')
    AND requested_by = auth.uid()
  );

DROP POLICY IF EXISTS "Finance admins can update refunds" ON public.refunds;
CREATE POLICY "Finance admins can update refunds"
  ON public.refunds FOR UPDATE TO authenticated
  USING (public.has_admin_permission('finance:write'))
  WITH CHECK (public.has_admin_permission('finance:write'));

GRANT SELECT, INSERT, UPDATE ON public.refunds TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.refunds TO service_role;

-- Ride updates from this table must respect finance permissions.
DROP POLICY IF EXISTS "Finance admins can mark rides refunded" ON public.rides;
CREATE POLICY "Finance admins can mark rides refunded"
  ON public.rides FOR UPDATE TO authenticated
  USING (
    public.has_admin_permission('finance:write')
    OR passenger_id = auth.uid()
    OR driver_id = auth.uid()
    OR public.has_admin_permission('fleet:write')
    OR (driver_id IS NULL AND status = 'requested' AND public.is_online_approved_driver(auth.uid()))
  )
  WITH CHECK (
    public.has_admin_permission('finance:write')
    OR passenger_id = auth.uid()
    OR driver_id = auth.uid()
    OR public.has_admin_permission('fleet:write')
    OR (driver_id IS NULL AND status = 'requested' AND public.is_online_approved_driver(auth.uid()))
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- Trigger: keep updated_at fresh on refund row writes
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS refunds_set_updated_at ON public.refunds;
CREATE TRIGGER refunds_set_updated_at
  BEFORE UPDATE ON public.refunds
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: finalize a refund and propagate the ride payment_status
-- Called by the paystack-refund Edge Function via service-role client so the
-- finance RLS gate is bypassed only at the trusted call site.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.finalize_refund(
  p_refund_id UUID,
  p_status TEXT,
  p_processed_amount NUMERIC,
  p_paystack_refund_id TEXT DEFAULT NULL,
  p_paystack_response JSONB DEFAULT NULL,
  p_failure_reason TEXT DEFAULT NULL
)
RETURNS public.refunds
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_refund public.refunds;
  v_status TEXT;
BEGIN
  -- Only the trusted edge function (service_role) may finalize a refund.
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Refund finalization is reserved for the service-role trust path.';
  END IF;

  SELECT * INTO v_refund FROM public.refunds WHERE id = p_refund_id FOR UPDATE;
  IF v_refund.id IS NULL THEN
    RAISE EXCEPTION 'Refund % not found.', p_refund_id;
  END IF;

  v_status := lower(coalesce(p_status, ''));
  IF v_status NOT IN ('completed', 'failed', 'disputed') THEN
    RAISE EXCEPTION 'finalize_refund only accepts completed / failed / disputed, got "%".', p_status;
  END IF;

  UPDATE public.refunds
  SET status = v_status,
      processed_amount = GREATEST(p_processed_amount, 0),
      paystack_refund_id = COALESCE(p_paystack_refund_id, paystack_refund_id),
      paystack_response = COALESCE(p_paystack_response, paystack_response),
      failure_reason = COALESCE(p_failure_reason, failure_reason),
      completed_at = CASE
        WHEN v_status = 'completed' THEN timezone('utc', now())
        ELSE completed_at
      END
  WHERE id = p_refund_id
  RETURNING * INTO v_refund;

  IF v_status = 'completed' THEN
    UPDATE public.rides
    SET payment_status = 'refunded',
        updated_at = timezone('utc', now())
    WHERE id = v_refund.ride_id;
  ELSIF v_status = 'disputed' THEN
    UPDATE public.rides
    SET payment_status = 'disputed',
        updated_at = timezone('utc', now())
    WHERE id = v_refund.ride_id;
  END IF;

  RETURN v_refund;
END;
$$;

GRANT EXECUTE ON FUNCTION public.finalize_refund(
  UUID, TEXT, NUMERIC, TEXT, JSONB, TEXT
) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- Realtime: refunds dashboard updates
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'refunds'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.refunds;
    END IF;
  END IF;
END
$$;

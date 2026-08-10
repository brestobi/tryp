-- TRYP driver wallet ledger
--
-- Balances are server-authoritative. Clients can read their own wallet, but can
-- never write balances or ledger entries. A unique ride_id makes settlement
-- idempotent when completion and payment verification arrive in either order.

CREATE TABLE IF NOT EXISTS public.driver_wallets (
  driver_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  cash_collected NUMERIC(12, 2) NOT NULL DEFAULT 0,
  online_held NUMERIC(12, 2) NOT NULL DEFAULT 0,
  cash_platform_fee_owed NUMERIC(12, 2) NOT NULL DEFAULT 0,
  platform_fees_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT driver_wallets_non_negative_check CHECK (
    cash_collected >= 0
    AND online_held >= 0
    AND cash_platform_fee_owed >= 0
    AND platform_fees_total >= 0
  )
);

CREATE TABLE IF NOT EXISTS public.driver_wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  ride_id UUID NOT NULL UNIQUE REFERENCES public.rides(id) ON DELETE CASCADE,
  payment_method TEXT NOT NULL,
  gross_amount NUMERIC(12, 2) NOT NULL,
  platform_fee NUMERIC(12, 2) NOT NULL,
  driver_net_amount NUMERIC(12, 2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT driver_wallet_transactions_amounts_check CHECK (
    gross_amount >= 0
    AND platform_fee >= 0
    AND driver_net_amount >= 0
  )
);

CREATE INDEX IF NOT EXISTS idx_driver_wallet_transactions_driver_created
  ON public.driver_wallet_transactions (driver_id, created_at DESC);

ALTER TABLE public.driver_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Drivers and admins can read driver wallets" ON public.driver_wallets;
CREATE POLICY "Drivers and admins can read driver wallets"
  ON public.driver_wallets FOR SELECT TO authenticated
  USING (driver_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "Drivers and admins can read wallet transactions" ON public.driver_wallet_transactions;
CREATE POLICY "Drivers and admins can read wallet transactions"
  ON public.driver_wallet_transactions FOR SELECT TO authenticated
  USING (driver_id = auth.uid() OR public.is_admin());

GRANT SELECT ON public.driver_wallets TO authenticated;
GRANT SELECT ON public.driver_wallet_transactions TO authenticated;
GRANT SELECT ON public.driver_wallets TO service_role;
GRANT SELECT ON public.driver_wallet_transactions TO service_role;

-- Ensure every existing and future driver has a wallet row. Balance changes are
-- only performed by the settlement function below.
INSERT INTO public.driver_wallets (driver_id)
SELECT id
FROM public.profiles
WHERE role = 'driver'
ON CONFLICT (driver_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.ensure_driver_wallet()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.role = 'driver' THEN
    INSERT INTO public.driver_wallets (driver_id)
    VALUES (NEW.id)
    ON CONFLICT (driver_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ensure_driver_wallet_after_profile_change ON public.profiles;
CREATE TRIGGER ensure_driver_wallet_after_profile_change
  AFTER INSERT OR UPDATE OF role ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_driver_wallet();

CREATE OR REPLACE FUNCTION public.settle_driver_wallet_for_ride(p_ride_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ride public.rides;
  v_commission_rate NUMERIC := 15;
  v_gross NUMERIC;
  v_platform_fee NUMERIC;
  v_driver_net NUMERIC;
  v_transaction_id UUID;
  v_is_cash BOOLEAN;
BEGIN
  SELECT * INTO v_ride
  FROM public.rides
  WHERE id = p_ride_id;

  IF v_ride.id IS NULL OR v_ride.driver_id IS NULL THEN
    RETURN p_ride_id;
  END IF;

  -- Cash is settled when the driver completes the ride. Online funds are
  -- settled only after the trusted Paystack path marks the payment paid.
  v_is_cash := lower(COALESCE(v_ride.payment_method, 'cash')) = 'cash';
  IF v_ride.status <> 'completed' OR (NOT v_is_cash AND v_ride.payment_status <> 'paid') THEN
    RETURN p_ride_id;
  END IF;

  SELECT COALESCE(fs.commission_percentage, 15)
  INTO v_commission_rate
  FROM public.fare_schemas fs
  WHERE fs.tier = v_ride.ride_type
  ORDER BY fs.updated_at DESC NULLS LAST
  LIMIT 1;

  v_gross := ROUND(GREATEST(COALESCE(v_ride.fare, 0), 0), 2);
  v_platform_fee := ROUND(v_gross * GREATEST(v_commission_rate, 0) / 100, 2);
  v_driver_net := GREATEST(v_gross - v_platform_fee, 0);

  -- The unique ride_id is the idempotency key. This protects against duplicate
  -- completion callbacks and a payment webhook arriving at the same time.
  INSERT INTO public.driver_wallet_transactions (
    driver_id, ride_id, payment_method, gross_amount, platform_fee, driver_net_amount
  ) VALUES (
    v_ride.driver_id,
    v_ride.id,
    CASE WHEN v_is_cash THEN 'Cash' ELSE 'Online' END,
    v_gross,
    v_platform_fee,
    v_driver_net
  )
  ON CONFLICT (ride_id) DO NOTHING
  RETURNING id INTO v_transaction_id;

  IF v_transaction_id IS NULL THEN
    RETURN p_ride_id;
  END IF;

  INSERT INTO public.driver_wallets (driver_id)
  VALUES (v_ride.driver_id)
  ON CONFLICT (driver_id) DO NOTHING;

  UPDATE public.driver_wallets
  SET cash_collected = cash_collected + CASE WHEN v_is_cash THEN v_gross ELSE 0 END,
      -- Keep online_held gross: this is the amount currently held by TRYP.
      -- platform_fees_total separately records the commission withheld.
      online_held = online_held + CASE WHEN v_is_cash THEN 0 ELSE v_gross END,
      cash_platform_fee_owed = cash_platform_fee_owed + CASE WHEN v_is_cash THEN v_platform_fee ELSE 0 END,
      platform_fees_total = platform_fees_total + v_platform_fee,
      updated_at = timezone('utc', now())
  WHERE driver_id = v_ride.driver_id;

  RETURN p_ride_id;
END;
$$;

-- This is an internal trigger target, not a client-callable balance mutation.
REVOKE ALL ON FUNCTION public.settle_driver_wallet_for_ride(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.settle_driver_wallet_for_ride(UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.settle_driver_wallet_for_ride(UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.settle_driver_wallet_after_ride_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status = 'completed'
     AND (
       lower(COALESCE(NEW.payment_method, 'cash')) = 'cash'
       OR NEW.payment_status = 'paid'
     ) THEN
    PERFORM public.settle_driver_wallet_for_ride(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS settle_driver_wallet_after_ride_change ON public.rides;
CREATE TRIGGER settle_driver_wallet_after_ride_change
  AFTER UPDATE OF status, payment_status ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.settle_driver_wallet_after_ride_change();

-- Backfill eligible historical completed rides through the same idempotent path.
DO $$
DECLARE
  v_ride_id UUID;
BEGIN
  FOR v_ride_id IN
    SELECT id
    FROM public.rides
    WHERE status = 'completed'
      AND driver_id IS NOT NULL
      AND (
        lower(COALESCE(payment_method, 'cash')) = 'cash'
        OR payment_status = 'paid'
      )
  LOOP
    PERFORM public.settle_driver_wallet_for_ride(v_ride_id);
  END LOOP;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'driver_wallets'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_wallets;
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'driver_wallet_transactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_wallet_transactions;
  END IF;
END
$$;

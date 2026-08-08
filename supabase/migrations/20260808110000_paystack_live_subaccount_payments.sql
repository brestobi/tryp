-- Secure Paystack payment bookkeeping.
-- The Paystack secret and subaccount code are stored in Supabase Edge Function
-- secrets, never in this migration or in a client application.

CREATE UNIQUE INDEX IF NOT EXISTS idx_rides_payment_reference_unique
  ON public.rides (payment_reference)
  WHERE payment_reference IS NOT NULL;

COMMENT ON COLUMN public.rides.payment_reference IS
  'Server-created Paystack transaction reference for online payments; never client-authored.';

-- Paystack references are used as the webhook lookup key. Keep them unique
-- for long-distance bookings just as they are for normal rides.
-- If legacy duplicates exist, this migration fails deliberately so operations
-- can reconcile those references without silently breaking webhook history.
CREATE UNIQUE INDEX IF NOT EXISTS idx_long_distance_payment_reference_unique
  ON public.long_distance_bookings (payment_reference)
  WHERE payment_reference IS NOT NULL;

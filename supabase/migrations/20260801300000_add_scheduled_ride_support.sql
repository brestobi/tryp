-- Add scheduled_for column to rides table
ALTER TABLE public.rides
ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ;

-- Add index to help query upcoming scheduled rides
CREATE INDEX IF NOT EXISTS idx_rides_scheduled_for ON public.rides(scheduled_for) WHERE scheduled_for IS NOT NULL;

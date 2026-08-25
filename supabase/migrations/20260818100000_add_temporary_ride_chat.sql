-- Temporary passenger/driver chat for active rides.
-- Messages are removed when a ride is completed or cancelled.

CREATE TABLE IF NOT EXISTS public.ride_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT ride_messages_message_length CHECK (
    char_length(btrim(message)) BETWEEN 1 AND 500
  )
);

CREATE INDEX IF NOT EXISTS idx_ride_messages_ride_created
  ON public.ride_messages(ride_id, created_at);

ALTER TABLE public.ride_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ride participants can read active chat" ON public.ride_messages;
CREATE POLICY "Ride participants can read active chat"
  ON public.ride_messages FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.rides r
      WHERE r.id = ride_messages.ride_id
        AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
        AND r.status IN ('accepted', 'arrived', 'in_trip')
    )
  );

DROP POLICY IF EXISTS "Ride participants can send active chat" ON public.ride_messages;
CREATE POLICY "Ride participants can send active chat"
  ON public.ride_messages FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.rides r
      WHERE r.id = ride_messages.ride_id
        AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
        AND r.status IN ('accepted', 'arrived', 'in_trip')
    )
  );

GRANT SELECT, INSERT ON public.ride_messages TO authenticated;

-- Keep the conversation temporary and unavailable after the ride ends.
CREATE OR REPLACE FUNCTION public.cleanup_terminal_ride_chat()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status IN ('completed', 'cancelled') THEN
    DELETE FROM public.ride_messages WHERE ride_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rides_cleanup_terminal_chat ON public.rides;
CREATE TRIGGER rides_cleanup_terminal_chat
  AFTER UPDATE OF status ON public.rides
  FOR EACH ROW
  WHEN (NEW.status IN ('completed', 'cancelled'))
  EXECUTE FUNCTION public.cleanup_terminal_ride_chat();

ALTER TABLE public.ride_messages REPLICA IDENTITY FULL;

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ride_messages;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END $$;

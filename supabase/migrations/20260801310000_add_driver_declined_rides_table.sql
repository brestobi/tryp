-- Create table to track declined rides
CREATE TABLE IF NOT EXISTS public.driver_declined_rides (
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
    declined_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    PRIMARY KEY (driver_id, ride_id)
);

-- Enable RLS
ALTER TABLE public.driver_declined_rides ENABLE ROW LEVEL SECURITY;

-- Policy: Drivers can only see/insert their own declined rides
CREATE POLICY "Drivers can manage own declined rides" ON public.driver_declined_rides
    FOR ALL TO authenticated
    USING (driver_id = auth.uid());

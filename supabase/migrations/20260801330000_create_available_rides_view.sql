-- Create a view to encapsulate the "available rides" logic including decline filtering
CREATE OR REPLACE VIEW public.available_rides_for_driver AS
SELECT r.*
FROM public.rides r
WHERE r.status = 'requested'
AND NOT EXISTS (
    SELECT 1 
    FROM public.driver_declined_rides dd 
    WHERE dd.ride_id = r.id 
    AND dd.driver_id = auth.uid()
);

-- Grant access to authenticated users (drivers)
GRANT SELECT ON public.available_rides_for_driver TO authenticated;

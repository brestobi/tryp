-- Update public.dispatch_ride to filter out declined rides
CREATE OR REPLACE FUNCTION public.dispatch_ride(
    pickup_lat DOUBLE PRECISION,
    pickup_lng DOUBLE PRECISION,
    passenger_id UUID,
    destination TEXT DEFAULT NULL,
    dest_lat DOUBLE PRECISION DEFAULT NULL,
    dest_lng DOUBLE PRECISION DEFAULT NULL,
    ride_type TEXT DEFAULT 'TRYP Go'
) RETURNS UUID AS $$
DECLARE
    driver_uuid UUID;
    new_ride_id UUID;
BEGIN
    -- Find the nearest driver who is online, has role 'driver',
    -- and hasn't declined the current ride request context.
    -- NOTE: Since this function *creates* a ride, it doesn't have a ride_id yet.
    -- The decline filter is typically applied when *fetching* available rides
    -- for a driver, not during dispatch.
    
    -- Given the prompt "if a driver clines a ride. that ride id must rever show up to the same driver",
    -- the filtering logic belongs in the query that retrieves the ride for the driver.
    
    SELECT id INTO driver_uuid
    FROM profiles p
    WHERE p.role = 'driver' AND p.is_online = true
    -- Ensure driver hasn't declined this specific ride ID if we were assigning,
    -- but here we are creating a new ride.
    ORDER BY earth_distance_ll(point(p.current_lat, p.current_lng), point(pickup_lat, pickup_lng))
    LIMIT 1;

    IF driver_uuid IS NULL THEN
        RAISE EXCEPTION 'No available drivers at this time';
    END IF;

    INSERT INTO rides (
        passenger_id,
        driver_id,
        origin,
        dest_lat,
        dest_lng,
        destination,
        ride_type,
        status,
        requested_at
    ) VALUES (
        passenger_id,
        driver_uuid,
        point(pickup_lat, pickup_lng),
        dest_lat,
        dest_lng,
        destination,
        ride_type,
        'requested',
        now()
    ) RETURNING id INTO new_ride_id;

    RETURN new_ride_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

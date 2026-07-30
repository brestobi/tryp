-- Migration: 20260730120000_add_dispatch_ride_function.sql
-- Description: Adds a function to create a ride and assign the nearest online driver.

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
    -- Find the nearest driver who is online and has role 'driver'
    SELECT id INTO driver_uuid
    FROM profiles
    WHERE role = 'driver' AND is_online = true
    ORDER BY earth_distance_ll(point(current_lat, current_lng), point(pickup_lat, pickup_lng))
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

-- Grant execution rights to authenticated role
GRANT EXECUTE ON FUNCTION public.dispatch_ride(DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO authenticated;

-- Assign the driver role for driver-app email signups.
-- Only the explicitly supported "driver" value is accepted; all other
-- metadata values retain the passenger default.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  signup_role text;
BEGIN
  signup_role := CASE
    WHEN NEW.raw_user_meta_data->>'role' = 'driver' THEN 'driver'
    ELSE 'passenger'
  END;

  INSERT INTO public.profiles (id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    signup_role
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.profiles.full_name),
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

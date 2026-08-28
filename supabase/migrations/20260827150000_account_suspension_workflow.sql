ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS account_status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS suspension_reason text,
  ADD COLUMN IF NOT EXISTS suspended_at timestamptz;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_account_status_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_account_status_check
  CHECK (account_status IN ('active', 'suspended'));

CREATE OR REPLACE FUNCTION public.suspend_account(
  p_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_email text;
  v_name text;
  v_role text;
  v_project_ref text;
  v_service_key text;
  v_webhook_secret text;
BEGIN
  IF NOT public.has_admin_permission('users:write') THEN
    RAISE EXCEPTION 'Only authorised administrators can suspend accounts.';
  END IF;

  SELECT email, full_name, role INTO v_email, v_name, v_role
  FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Account not found.'; END IF;

  UPDATE public.profiles
  SET account_status = 'suspended',
      suspension_reason = NULLIF(trim(COALESCE(p_reason, '')), ''),
      suspended_at = timezone('utc', now()),
      is_online = false,
      updated_at = timezone('utc', now())
  WHERE id = p_user_id;

  PERFORM public.send_notification(
    p_user_id,
    'Account suspended',
    'Your TRYP account has been suspended. Please contact support for assistance.',
    'system', '/support', jsonb_build_object('event', 'account_suspended', 'reason', p_reason)
  );

  BEGIN
    SELECT decrypted_secret INTO v_project_ref FROM vault.decrypted_secrets WHERE name IN ('supabase_project_ref', 'tryp_supabase_project_ref') ORDER BY name LIMIT 1;
    SELECT decrypted_secret INTO v_service_key FROM vault.decrypted_secrets WHERE name IN ('supabase_service_role_key', 'tryp_push_supabase_service_key') ORDER BY name LIMIT 1;
    SELECT decrypted_secret INTO v_webhook_secret FROM vault.decrypted_secrets WHERE name = 'suspension_webhook_secret' LIMIT 1;
    IF COALESCE(v_project_ref, '') <> '' AND COALESCE(v_service_key, '') <> '' THEN
      PERFORM net.http_post(
        url := 'https://' || v_project_ref || '.supabase.co/functions/v1/notify-account-suspension',
        headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_service_key, 'x-tryp-suspension-secret', COALESCE(v_webhook_secret, '')),
        body := jsonb_build_object('email', v_email, 'name', v_name, 'role', v_role, 'reason', COALESCE(p_reason, 'Account suspended pending review.'))
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[suspend_account] Email queue failed: %', SQLERRM;
  END;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.reinstate_account(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.has_admin_permission('users:write') THEN RAISE EXCEPTION 'Only authorised administrators can reinstate accounts.'; END IF;
  UPDATE public.profiles SET account_status = 'active', suspension_reason = NULL, suspended_at = NULL, updated_at = timezone('utc', now()) WHERE id = p_user_id;
  RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.suspend_account(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reinstate_account(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.is_account_suspended(p_user_id uuid DEFAULT auth.uid())
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id AND account_status = 'suspended');
$$;
GRANT EXECUTE ON FUNCTION public.is_account_suspended(uuid) TO authenticated;

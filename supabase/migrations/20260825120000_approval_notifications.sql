-- Notify approved users through the in-app/push pipeline and approval email.
-- The email request is best-effort; approval itself must not fail when email
-- configuration or the external provider is unavailable.

CREATE OR REPLACE FUNCTION public.notify_account_approval(
  p_user_id UUID,
  p_account_type TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_name TEXT;
  v_email TEXT;
  v_title TEXT;
  v_body TEXT;
  v_project_ref TEXT;
  v_service_key TEXT;
  v_email_secret TEXT;
BEGIN
  IF NOT public.has_admin_permission('kyc:write') THEN
    RAISE EXCEPTION 'Only authorised KYC administrators can approve accounts.';
  END IF;

  IF p_account_type NOT IN ('driver', 'passenger') THEN
    RAISE EXCEPTION 'Invalid approval account type.';
  END IF;

  SELECT full_name, email INTO v_name, v_email
  FROM public.profiles
  WHERE id = p_user_id
    AND role = p_account_type;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Approved account was not found.';
  END IF;

  IF p_account_type = 'driver' THEN
    v_title := 'Driver account approved';
    v_body := 'Your TRYP driver account has been approved. You can now go online and accept rides.';
  ELSE
    v_title := 'Identity verification approved';
    v_body := 'Your TRYP identity verification has been approved. You can now request rides.';
  END IF;

  -- This insert is consumed by the existing push trigger and appears in the
  -- user's in-app notification feed.
  PERFORM public.send_notification(
    p_user_id,
    v_title,
    v_body,
    'system',
    '/notifications',
    jsonb_build_object('event', 'account_approval', 'account_type', p_account_type)
  );

  -- Queue email through pg_net when the deployment has the required Vault
  -- settings. Missing settings only skip email; they never undo approval.
  BEGIN
    SELECT decrypted_secret INTO v_project_ref
    FROM vault.decrypted_secrets
    WHERE name IN ('supabase_project_ref', 'tryp_supabase_project_ref')
    ORDER BY CASE name WHEN 'supabase_project_ref' THEN 1 ELSE 2 END
    LIMIT 1;
    SELECT decrypted_secret INTO v_service_key
    FROM vault.decrypted_secrets
    WHERE name IN ('supabase_service_role_key', 'tryp_push_supabase_service_key')
    ORDER BY CASE name WHEN 'supabase_service_role_key' THEN 1 ELSE 2 END
    LIMIT 1;
    SELECT decrypted_secret INTO v_email_secret
    FROM vault.decrypted_secrets
    WHERE name = 'approval_email_webhook_secret'
    LIMIT 1;

    IF COALESCE(v_project_ref, '') <> '' AND COALESCE(v_service_key, '') <> '' THEN
      PERFORM net.http_post(
        url := 'https://' || v_project_ref || '.supabase.co/functions/v1/send-approval-email',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_service_key,
          'x-tryp-approval-secret', COALESCE(v_email_secret, '')
        ),
        body := jsonb_build_object(
          'email', v_email,
          'name', v_name,
          'accountType', p_account_type
        )
      );
    ELSE
      RAISE WARNING '[notify_account_approval] Email delivery skipped: Vault configuration is missing.';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[notify_account_approval] Email delivery queue failed: %', SQLERRM;
  END;

  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_account_approval(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.notify_account_approval(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.notify_account_approval(UUID, TEXT) TO service_role;

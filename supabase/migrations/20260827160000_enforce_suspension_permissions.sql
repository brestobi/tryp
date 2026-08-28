CREATE OR REPLACE FUNCTION public.suspend_account(
  p_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp
AS $$
DECLARE v_email text; v_name text; v_role text;
BEGIN
  IF NOT public.has_admin_permission('users:write') THEN RAISE EXCEPTION 'Only authorised administrators can suspend accounts.'; END IF;
  SELECT email, full_name, role INTO v_email, v_name, v_role FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND OR v_role NOT IN ('passenger', 'driver') THEN RAISE EXCEPTION 'Only passenger and driver accounts can be suspended.'; END IF;
  UPDATE public.profiles SET account_status='suspended', suspension_reason=NULLIF(trim(COALESCE(p_reason,'')),''), suspended_at=timezone('utc',now()), is_online=false, updated_at=timezone('utc',now()) WHERE id=p_user_id;
  PERFORM public.send_notification(p_user_id, 'Account suspended', 'Your TRYP account has been suspended. Please contact support for assistance.', 'system', '/support', jsonb_build_object('event','account_suspended','reason',p_reason));
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.reinstate_account(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.has_admin_permission('users:write') THEN RAISE EXCEPTION 'Only authorised administrators can reinstate accounts.'; END IF;
  UPDATE public.profiles SET account_status='active', suspension_reason=NULL, suspended_at=NULL, updated_at=timezone('utc',now()) WHERE id=p_user_id AND role IN ('passenger','driver');
  RETURN FOUND;
END;
$$;

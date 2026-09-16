-- Applied to careflow (alsgbnbzzdsfixgsaiak) 2026-09-16.
-- Admin-mediated membership management: deactivate, reactivate, change
-- role. Ordinary users can never write company_memberships directly
-- (no INSERT/UPDATE policy exists), and self-service changes to one's
-- own membership are explicitly blocked here even for otherwise
-- authorised admins, per "users cannot alter their own company
-- membership" / no self-escalation.

create or replace function public.deactivate_membership(target_membership_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_cm record;
begin
  select * into v_cm from public.company_memberships where id = target_membership_id;
  if v_cm is null then
    raise exception 'membership not found';
  end if;

  if v_cm.user_id = auth.uid() and not public.is_platform_admin() then
    raise exception 'cannot alter your own membership';
  end if;

  if not (public.has_company_capability(v_cm.company_id, 'settings.manage') or public.is_platform_admin()) then
    raise exception 'not authorised';
  end if;

  update public.company_memberships set status = 'deactivated' where id = target_membership_id;

  perform public.insert_audit_event(
    v_cm.company_id, auth.uid(), 'membership_deactivated', 'company_memberships', target_membership_id,
    jsonb_build_object('status', v_cm.status), jsonb_build_object('status', 'deactivated'), p_reason, null
  );
end;
$$;
revoke execute on function public.deactivate_membership(uuid, text) from public;
grant execute on function public.deactivate_membership(uuid, text) to authenticated;

create or replace function public.reactivate_membership(target_membership_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_cm record;
begin
  select * into v_cm from public.company_memberships where id = target_membership_id;
  if v_cm is null then
    raise exception 'membership not found';
  end if;

  if v_cm.user_id = auth.uid() and not public.is_platform_admin() then
    raise exception 'cannot alter your own membership';
  end if;

  if not (public.has_company_capability(v_cm.company_id, 'settings.manage') or public.is_platform_admin()) then
    raise exception 'not authorised';
  end if;

  update public.company_memberships set status = 'active' where id = target_membership_id;

  perform public.insert_audit_event(
    v_cm.company_id, auth.uid(), 'membership_reactivated', 'company_memberships', target_membership_id,
    jsonb_build_object('status', v_cm.status), jsonb_build_object('status', 'active'), p_reason, null
  );
end;
$$;
revoke execute on function public.reactivate_membership(uuid, text) from public;
grant execute on function public.reactivate_membership(uuid, text) to authenticated;

create or replace function public.change_membership_role(target_membership_id uuid, new_role_key text, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_cm      record;
  v_old_key text;
  v_new_id  uuid;
begin
  select * into v_cm from public.company_memberships where id = target_membership_id;
  if v_cm is null then
    raise exception 'membership not found';
  end if;

  if v_cm.user_id = auth.uid() and not public.is_platform_admin() then
    raise exception 'cannot alter your own membership';
  end if;

  if not (public.has_company_capability(v_cm.company_id, 'settings.manage') or public.is_platform_admin()) then
    raise exception 'not authorised';
  end if;

  select key into v_old_key from public.roles where id = v_cm.role_id;
  select id into v_new_id from public.roles where key = new_role_key;
  if v_new_id is null then
    raise exception 'invalid role key: %', new_role_key;
  end if;

  update public.company_memberships set role_id = v_new_id where id = target_membership_id;

  perform public.insert_audit_event(
    v_cm.company_id, auth.uid(), 'membership_role_changed', 'company_memberships', target_membership_id,
    jsonb_build_object('role', v_old_key), jsonb_build_object('role', new_role_key), p_reason, null
  );
end;
$$;
revoke execute on function public.change_membership_role(uuid, text, text) from public;
grant execute on function public.change_membership_role(uuid, text, text) to authenticated;

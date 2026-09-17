-- A settings manager must be able to see an area they are authorised to
-- create. Previously the write policy allowed creation while can_access_area
-- could hide the new row immediately afterwards for area-scoped memberships.

create or replace function public.can_access_area(
  target_company_id uuid,
  target_area_id uuid
) returns boolean
language sql stable security definer
set search_path = pg_catalog, public as $$
  select public.is_active_member(target_company_id) and (
    public.is_platform_admin()
    or public.current_role_key(target_company_id) = 'company_admin'
    or public.has_company_capability(target_company_id, 'settings.manage')
    or exists (
      select 1
      from public.company_memberships cm
      where cm.company_id = target_company_id
        and cm.user_id = auth.uid()
        and cm.status = 'active'
        and cm.all_areas
    )
    or target_area_id is null
    or exists (
      select 1
      from public.membership_area_access maa
      join public.company_memberships cm
        on cm.id = maa.membership_id
       and cm.company_id = maa.company_id
      where maa.company_id = target_company_id
        and maa.area_id = target_area_id
        and cm.user_id = auth.uid()
        and cm.status = 'active'
    )
  );
$$;

revoke all on function public.can_access_area(uuid, uuid) from public;
grant execute on function public.can_access_area(uuid, uuid) to authenticated;

-- Re-state the policy so upgraded databases have one unambiguous read rule.
drop policy if exists operational_areas_select on public.operational_areas;
create policy operational_areas_select
  on public.operational_areas for select
  using (public.can_access_area(company_id, id));


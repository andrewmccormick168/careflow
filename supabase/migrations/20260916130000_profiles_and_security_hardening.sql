-- Forward-only hardening migration. Earlier migrations may already be deployed.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  avatar_url text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create policy profiles_select_self_or_colleague on public.profiles for select
using (
  id = auth.uid() or exists (
    select 1 from public.company_memberships mine
    join public.company_memberships theirs on theirs.company_id = mine.company_id
    where mine.user_id = auth.uid() and mine.status = 'active'
      and theirs.user_id = profiles.id and theirs.status = 'active'
      and public.is_active_member(mine.company_id)
  )
);
create policy profiles_update_self on public.profiles for update
using (id = auth.uid()) with check (id = auth.uid());

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public as $$
begin
  insert into public.profiles (id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)), new.email)
  on conflict (id) do update set email = excluded.email;
  insert into public.user_account_status (user_id, status)
  values (new.id, 'active') on conflict (user_id) do nothing;
  return new;
end; $$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert or update of email on auth.users
for each row execute function public.handle_new_user();

insert into public.profiles (id, full_name, email)
select id, coalesce(raw_user_meta_data->>'full_name', split_part(email, '@', 1)), email from auth.users
on conflict (id) do nothing;
insert into public.user_account_status (user_id, status)
select id, 'active' from auth.users on conflict (user_id) do nothing;

alter table public.company_memberships
  add constraint company_memberships_profile_fk foreign key (user_id)
  references public.profiles(id) on delete cascade;

-- Assignment paths must never bypass membership/company suspension.
drop policy if exists employees_select on public.employees;
create policy employees_select on public.employees for select using (
  public.is_active_member(company_id)
  and (user_id = auth.uid() or public.has_company_capability(company_id, 'employees.view'))
);
drop policy if exists service_users_select_via_assignment on public.service_users;
create policy service_users_select_via_assignment on public.service_users for select using (
  public.is_active_member(company_id) and exists (
    select 1 from public.service_user_assignments sua
    join public.employees e on e.id = sua.employee_id and e.company_id = sua.company_id
    where sua.service_user_id = service_users.id and sua.company_id = service_users.company_id
      and sua.status = 'active' and e.user_id = auth.uid()
  )
);
drop policy if exists service_user_assignments_select on public.service_user_assignments;
create policy service_user_assignments_select on public.service_user_assignments for select using (
  public.is_active_member(company_id) and (
    public.has_company_capability(company_id, 'assignments.manage')
    or public.has_company_capability(company_id, 'service_users.view')
    or exists (select 1 from public.employees e where e.id = employee_id and e.company_id = company_id and e.user_id = auth.uid())
  )
);

create or replace function public.current_role_key(target_company_id uuid)
returns text language sql security definer stable
set search_path = pg_catalog, public as $$
  select r.key from public.company_memberships cm join public.roles r on r.id = cm.role_id
  where cm.company_id = target_company_id and cm.user_id = auth.uid()
    and cm.status = 'active' and public.is_active_member(target_company_id) limit 1;
$$;
revoke execute on function public.current_role_key(uuid) from public;
grant execute on function public.current_role_key(uuid) to authenticated;

create or replace function public.can_access_service_user(target_company_id uuid, target_service_user_id uuid)
returns boolean language sql security definer stable
set search_path = pg_catalog, public as $$
  select public.is_active_member(target_company_id) and (
    public.current_role_key(target_company_id) in ('company_admin','manager','coordinator')
    or exists (
      select 1 from public.service_user_assignments a
      join public.employees e on e.id = a.employee_id and e.company_id = a.company_id
      where a.company_id = target_company_id and a.service_user_id = target_service_user_id
        and a.status = 'active' and e.user_id = auth.uid()
        and a.start_date <= current_date and (a.end_date is null or a.end_date >= current_date)
    )
  );
$$;
revoke execute on function public.can_access_service_user(uuid, uuid) from public;
grant execute on function public.can_access_service_user(uuid, uuid) to authenticated;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin new.updated_at = now(); return new; end; $$;
revoke execute on function public.set_updated_at() from public, anon, authenticated;

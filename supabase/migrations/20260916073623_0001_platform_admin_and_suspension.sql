-- Applied to careflow (alsgbnbzzdsfixgsaiak) 2026-09-16.
-- See docs/architecture.md §2-3 for the design this implements.

create table public.platform_administrators (
  user_id     uuid primary key references auth.users(id),
  status      text not null default 'active' check (status in ('active','revoked')),
  granted_by  uuid not null references auth.users(id),
  granted_at  timestamptz not null default now(),
  revoked_at  timestamptz
);
revoke all on public.platform_administrators from public, authenticated;

create table public.user_account_status (
  user_id  uuid primary key references auth.users(id),
  status   text not null default 'active' check (status in ('active','suspended')),
  reason   text,
  set_by   uuid references auth.users(id),
  set_at   timestamptz not null default now()
);
revoke all on public.user_account_status from public, authenticated;

alter table public.platform_administrators enable row level security;
alter table public.user_account_status enable row level security;
-- No policies yet: with RLS on and zero policies, every role is denied by
-- default until is_platform_admin()/is_active_member() etc. are added in
-- the next migration, which is the deliberate, safe order of operations.

create or replace function public.is_platform_admin()
returns boolean
language sql
security definer
set search_path = pg_catalog, public
stable
as $$
  select exists (
    select 1 from public.platform_administrators pa
    join public.user_account_status uas on uas.user_id = pa.user_id
    where pa.user_id = auth.uid()
      and pa.status = 'active'
      and uas.status = 'active'
  );
$$;
revoke execute on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated;

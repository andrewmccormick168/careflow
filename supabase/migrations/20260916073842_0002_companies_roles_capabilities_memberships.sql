-- Applied to careflow (alsgbnbzzdsfixgsaiak) 2026-09-16.
-- See docs/architecture.md §4-6, §14 for the design this implements.

-- Defense-in-depth: pre-existing event-trigger function does not need
-- direct RPC execution grants (it's invoked by the event trigger
-- mechanism itself), so tighten per SECURITY DEFINER conventions.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- ============ companies ============
create table public.companies (
  id                       uuid primary key default gen_random_uuid(),
  name                     text not null,
  trading_name             text,
  registered_number        text,
  contact_email            text,
  contact_phone            text,
  address                  text,
  logo_url                 text,
  timezone                 text not null default 'Europe/London',
  status                   text not null default 'active' check (status in ('active','suspended')),
  session_timeout_minutes  integer not null default 30,
  retention_years          integer not null default 7,
  created_at               timestamptz not null default now()
);
revoke update (id) on public.companies from authenticated;
alter table public.companies enable row level security;

-- ============ roles (fixed global catalogue) ============
create table public.roles (
  id    uuid primary key default gen_random_uuid(),
  key   text not null unique,
  label text not null
);
alter table public.roles enable row level security;
insert into public.roles (key, label) values
  ('company_admin', 'Company Administrator'),
  ('manager', 'Manager'),
  ('coordinator', 'Coordinator'),
  ('carer', 'Carer'),
  ('finance', 'Finance');

-- ============ capabilities ============
create table public.capabilities (
  id          uuid primary key default gen_random_uuid(),
  key         text not null unique,
  description text
);
alter table public.capabilities enable row level security;
insert into public.capabilities (key, description) values
  ('employees.view', 'View employee records'),
  ('employees.manage', 'Create/edit employee records'),
  ('service_users.view', 'View service user records'),
  ('service_users.manage', 'Create/edit service user records'),
  ('assignments.manage', 'Manage service user assignments'),
  ('care_plans.view', 'View care plans'),
  ('care_plans.manage', 'Create/edit care plans'),
  ('visits.view', 'View visits'),
  ('visits.schedule', 'Schedule visits'),
  ('visits.complete', 'Complete visits'),
  ('risks.view', 'View risk assessments'),
  ('risks.manage', 'Create/edit risk assessments'),
  ('medication.view', 'View medication records'),
  ('medication.administer', 'Administer medication (MAR)'),
  ('medication.manage', 'Manage medication profiles/schedules'),
  ('incidents.view', 'View incidents'),
  ('incidents.create', 'Create incidents'),
  ('incidents.manage', 'Manage incident workflow'),
  ('safeguarding.view', 'View safeguarding records'),
  ('safeguarding.create', 'Create safeguarding records'),
  ('safeguarding.manage', 'Manage safeguarding workflow'),
  ('rota.view', 'View rota'),
  ('rota.manage', 'Manage rota'),
  ('timesheets.view', 'View timesheets'),
  ('timesheets.approve', 'Approve timesheets'),
  ('payroll.view', 'View payroll'),
  ('payroll.manage', 'Manage payroll'),
  ('invoices.view', 'View invoices'),
  ('invoices.manage', 'Manage invoices'),
  ('documents.view', 'View documents'),
  ('documents.manage', 'Manage documents'),
  ('reports.view', 'View reports'),
  ('exports.create', 'Create exports'),
  ('audit.view', 'View audit history'),
  ('settings.manage', 'Manage company settings and memberships');

-- ============ role_capabilities ============
create table public.role_capabilities (
  role_id       uuid not null references public.roles(id),
  capability_id uuid not null references public.capabilities(id),
  primary key (role_id, capability_id)
);
alter table public.role_capabilities enable row level security;

-- Seed: company_admin gets everything; other roles get a sensible
-- starter subset, refined per-module in later phases.
insert into public.role_capabilities (role_id, capability_id)
select r.id, c.id from public.roles r cross join public.capabilities c
where r.key = 'company_admin';

insert into public.role_capabilities (role_id, capability_id)
select r.id, c.id from public.roles r, public.capabilities c
where r.key = 'manager' and c.key in (
  'employees.view','employees.manage','service_users.view','service_users.manage',
  'assignments.manage','care_plans.view','care_plans.manage','visits.view','visits.schedule',
  'risks.view','risks.manage','incidents.view','incidents.create','incidents.manage',
  'rota.view','rota.manage','timesheets.view','timesheets.approve','documents.view',
  'documents.manage','reports.view','exports.create'
);

insert into public.role_capabilities (role_id, capability_id)
select r.id, c.id from public.roles r, public.capabilities c
where r.key = 'coordinator' and c.key in (
  'employees.view','service_users.view','assignments.manage','care_plans.view',
  'visits.view','visits.schedule','rota.view','rota.manage','documents.view'
);

insert into public.role_capabilities (role_id, capability_id)
select r.id, c.id from public.roles r, public.capabilities c
where r.key = 'carer' and c.key in (
  'service_users.view','care_plans.view','visits.view','visits.complete',
  'medication.view','medication.administer','incidents.view','incidents.create','documents.view'
);

insert into public.role_capabilities (role_id, capability_id)
select r.id, c.id from public.roles r, public.capabilities c
where r.key = 'finance' and c.key in (
  'timesheets.view','payroll.view','payroll.manage','invoices.view','invoices.manage','reports.view','exports.create'
);

-- ============ company_memberships ============
create table public.company_memberships (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id),
  user_id     uuid not null references auth.users(id),
  role_id     uuid not null references public.roles(id),
  status      text not null default 'active' check (status in ('active','deactivated')),
  invited_by  uuid references auth.users(id),
  created_at  timestamptz not null default now(),
  unique (company_id, user_id)
);
revoke update (company_id, user_id) on public.company_memberships from authenticated;
alter table public.company_memberships enable row level security;

-- ============ RLS helper functions ============
create or replace function public.is_active_member(target_company_id uuid)
returns boolean
language sql
security definer
set search_path = pg_catalog, public
stable
as $$
  select
    auth.uid() is not null
    and not exists (
      select 1 from public.user_account_status uas
      where uas.user_id = auth.uid() and uas.status = 'suspended'
    )
    and exists (
      select 1 from public.companies c
      where c.id = target_company_id and c.status = 'active'
    )
    and exists (
      select 1 from public.company_memberships cm
      where cm.user_id = auth.uid()
        and cm.company_id = target_company_id
        and cm.status = 'active'
    );
$$;
revoke execute on function public.is_active_member(uuid) from public;
grant execute on function public.is_active_member(uuid) to authenticated;

create or replace function public.has_company_capability(target_company_id uuid, capability_key text)
returns boolean
language sql
security definer
set search_path = pg_catalog, public
stable
as $$
  select
    public.is_active_member(target_company_id)
    and exists (
      select 1
      from public.company_memberships cm
      join public.role_capabilities rc on rc.role_id = cm.role_id
      join public.capabilities cap on cap.id = rc.capability_id
      where cm.user_id = auth.uid()
        and cm.company_id = target_company_id
        and cm.status = 'active'
        and cap.key = capability_key
    );
$$;
revoke execute on function public.has_company_capability(uuid, text) from public;
grant execute on function public.has_company_capability(uuid, text) to authenticated;

-- ============ RLS policies ============
create policy companies_select on public.companies for select
using ( public.is_active_member(id) or public.is_platform_admin() );

create policy companies_insert_platform_admin on public.companies for insert
with check ( public.is_platform_admin() );

create policy companies_update on public.companies for update
using ( public.is_active_member(id) and public.has_company_capability(id, 'settings.manage') )
with check ( public.is_active_member(id) and public.has_company_capability(id, 'settings.manage') );
-- No delete policy: companies are never hard-deleted via the API.

create policy roles_select on public.roles for select using ( auth.uid() is not null );
create policy capabilities_select on public.capabilities for select using ( auth.uid() is not null );
create policy role_capabilities_select on public.role_capabilities for select using ( auth.uid() is not null );
-- No insert/update/delete policies on roles/capabilities/role_capabilities:
-- this is reference data maintained only via reviewed migrations.

create policy company_memberships_select on public.company_memberships for select
using (
  user_id = auth.uid()
  or public.has_company_capability(company_id, 'settings.manage')
  or public.is_platform_admin()
);
-- No insert/update/delete policies yet: membership creation/changes go
-- exclusively through SECURITY DEFINER functions (accept_invitation and
-- an admin membership-management function).

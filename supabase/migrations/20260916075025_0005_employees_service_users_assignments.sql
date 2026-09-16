-- Applied to careflow (alsgbnbzzdsfixgsaiak) 2026-09-16.
-- See docs/architecture.md §7-8 for the design this implements.
-- Note: table creation is ordered before any cross-table policy that
-- references service_user_assignments, since that table must exist
-- first (an earlier attempt at this migration failed for that reason
-- and was rolled back atomically by Postgres before being corrected).

create extension if not exists btree_gist;

-- ============ employees ============
create table public.employees (
  id                      uuid primary key default gen_random_uuid(),
  company_id              uuid not null references public.companies(id),
  user_id                 uuid references auth.users(id),
  full_name               text not null,
  job_title                text,
  contact_email            text,
  contact_phone            text,
  start_date               date,
  leaving_date             date,
  status                   text not null default 'active' check (status in ('active','leaver')),
  emergency_contact_name   text,
  emergency_contact_phone  text,
  created_at               timestamptz not null default now(),
  constraint employees_id_company_unique unique (id, company_id)
);
create unique index employees_company_user_unique
  on public.employees (company_id, user_id) where user_id is not null;
revoke update (company_id) on public.employees from authenticated;
alter table public.employees enable row level security;

-- ============ employee_sensitive ============
create table public.employee_sensitive (
  id                      uuid primary key default gen_random_uuid(),
  employee_id             uuid not null unique,
  company_id              uuid not null references public.companies(id),
  dbs_check_type          text,
  dbs_certificate_number  text,
  dbs_issue_date          date,
  dbs_status              text,
  notes                   text,
  created_at              timestamptz not null default now(),
  constraint employee_sensitive_employee_company_fk
    foreign key (employee_id, company_id) references public.employees (id, company_id)
);
revoke update (company_id) on public.employee_sensitive from authenticated;
alter table public.employee_sensitive enable row level security;

-- ============ service_users ============
create table public.service_users (
  id                          uuid primary key default gen_random_uuid(),
  company_id                  uuid not null references public.companies(id),
  full_name                   text not null,
  preferred_name               text,
  address                      text,
  contact_phone                text,
  communication_requirements   text,
  accessibility_requirements   text,
  important_alerts             text,
  status                       text not null default 'active' check (status in ('active','ended','archived')),
  start_date                   date,
  end_date                     date,
  created_at                   timestamptz not null default now(),
  constraint service_users_id_company_unique unique (id, company_id)
);
revoke update (company_id) on public.service_users from authenticated;
alter table public.service_users enable row level security;

-- ============ service_user_contacts ============
create table public.service_user_contacts (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies(id),
  service_user_id uuid not null,
  contact_type    text not null,
  name            text,
  phone           text,
  email           text,
  notes           text,
  created_at      timestamptz not null default now(),
  constraint service_user_contacts_su_company_fk
    foreign key (service_user_id, company_id) references public.service_users (id, company_id)
);
revoke update (company_id) on public.service_user_contacts from authenticated;
alter table public.service_user_contacts enable row level security;

-- ============ service_user_assignments ============
create table public.service_user_assignments (
  id               uuid primary key default gen_random_uuid(),
  company_id       uuid not null references public.companies(id),
  employee_id      uuid not null,
  service_user_id  uuid not null,
  assignment_type  text not null default 'carer',
  start_date       date not null default current_date,
  end_date         date,
  status           text not null default 'active' check (status in ('active','ended')),
  created_at       timestamptz not null default now(),
  constraint sua_employee_company_fk
    foreign key (employee_id, company_id) references public.employees (id, company_id),
  constraint sua_service_user_company_fk
    foreign key (service_user_id, company_id) references public.service_users (id, company_id),
  constraint sua_dates_valid check (end_date is null or end_date >= start_date),
  -- No two ACTIVE assignments for the same employee+service-user pair may
  -- have overlapping date ranges.
  exclude using gist (
    employee_id with =,
    service_user_id with =,
    daterange(start_date, coalesce(end_date, 'infinity'::date), '[]') with &&
  ) where (status = 'active')
);
revoke update (company_id) on public.service_user_assignments from authenticated;
alter table public.service_user_assignments enable row level security;

-- ============ policies (all tables now exist) ============

create policy employees_select on public.employees for select
using (
  user_id = auth.uid()
  or (public.is_active_member(company_id) and public.has_company_capability(company_id, 'employees.view'))
);
create policy employees_insert on public.employees for insert
with check ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'employees.manage') );
create policy employees_update on public.employees for update
using ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'employees.manage') )
with check ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'employees.manage') );

create policy employee_sensitive_select on public.employee_sensitive for select
using ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'employees.manage') );
create policy employee_sensitive_insert on public.employee_sensitive for insert
with check ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'employees.manage') );
create policy employee_sensitive_update on public.employee_sensitive for update
using ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'employees.manage') )
with check ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'employees.manage') );

create policy service_users_select_by_capability on public.service_users for select
using ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'service_users.view') );

-- Carers see only service users they are actively assigned to, even
-- without the broader service_users.view capability (additive policy —
-- Postgres RLS ORs multiple permissive SELECT policies together).
create policy service_users_select_via_assignment on public.service_users for select
using (
  exists (
    select 1
    from public.service_user_assignments sua
    join public.employees e on e.id = sua.employee_id
    where sua.service_user_id = service_users.id
      and sua.status = 'active'
      and sua.company_id = service_users.company_id
      and e.user_id = auth.uid()
  )
);

create policy service_users_insert on public.service_users for insert
with check ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'service_users.manage') );
create policy service_users_update on public.service_users for update
using ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'service_users.manage') )
with check ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'service_users.manage') );

create policy service_user_contacts_select on public.service_user_contacts for select
using ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'service_users.view') );
create policy service_user_contacts_insert on public.service_user_contacts for insert
with check ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'service_users.manage') );
create policy service_user_contacts_update on public.service_user_contacts for update
using ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'service_users.manage') )
with check ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'service_users.manage') );

create policy service_user_assignments_select on public.service_user_assignments for select
using (
  (public.is_active_member(company_id)
    and (public.has_company_capability(company_id, 'assignments.manage')
         or public.has_company_capability(company_id, 'service_users.view')))
  or exists (
    select 1 from public.employees e
    where e.id = service_user_assignments.employee_id and e.user_id = auth.uid()
  )
);
create policy service_user_assignments_insert on public.service_user_assignments for insert
with check ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'assignments.manage') );
create policy service_user_assignments_update on public.service_user_assignments for update
using ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'assignments.manage') )
with check ( public.is_active_member(company_id) and public.has_company_capability(company_id, 'assignments.manage') );

-- Phases 2-7: operational care, medication, compliance, workforce and finance.

-- Refine the starter role matrix now that the full modules exist. Carers use
-- assignment-scoped service-user policies rather than tenant-wide viewing.
delete from public.role_capabilities rc using public.roles r, public.capabilities c
where rc.role_id=r.id and rc.capability_id=c.id and r.key='carer'
  and c.key in ('service_users.view','incidents.view');
insert into public.role_capabilities(role_id,capability_id)
select r.id,c.id from public.roles r cross join public.capabilities c
where r.key='manager' and c.key in (
 'medication.view','medication.administer','medication.manage',
 'safeguarding.view','safeguarding.create','safeguarding.manage',
 'payroll.view','invoices.view','invoices.manage','audit.view'
) on conflict do nothing;
insert into public.role_capabilities(role_id,capability_id)
select r.id,c.id from public.roles r cross join public.capabilities c
where r.key='coordinator' and c.key in ('medication.view','incidents.view','incidents.create','documents.manage')
on conflict do nothing;

create table public.care_plans (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
  service_user_id uuid not null, title text not null default 'Care and support plan',
  summary text, outcomes text, preferences text, status text not null default 'draft' check (status in ('draft','active','superseded','archived')),
  version integer not null default 1, effective_from date, review_due date, approved_by uuid references auth.users(id), approved_at timestamptz,
  created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key (service_user_id, company_id) references public.service_users(id, company_id), unique (id, company_id)
);
create table public.care_plan_sections (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), care_plan_id uuid not null,
  section_key text not null, heading text not null, content text, sort_order integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key (care_plan_id, company_id) references public.care_plans(id, company_id) on delete cascade
);
create table public.risk_assessments (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid not null,
  category text not null, hazard text not null, who_at_risk text, likelihood integer not null default 1 check (likelihood between 1 and 5),
  severity integer not null default 1 check (severity between 1 and 5), controls text, residual_likelihood integer check (residual_likelihood between 1 and 5),
  residual_severity integer check (residual_severity between 1 and 5), status text not null default 'open' check (status in ('open','controlled','closed')),
  review_due date, owner_id uuid, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key (service_user_id, company_id) references public.service_users(id, company_id),
  foreign key (owner_id, company_id) references public.employees(id, company_id)
);

create table public.working_patterns (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), employee_id uuid not null,
  weekday integer not null check (weekday between 0 and 6), starts_at time not null, ends_at time not null, effective_from date not null default current_date, effective_to date,
  foreign key (employee_id, company_id) references public.employees(id, company_id)
);
create table public.availability_exceptions (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), employee_id uuid not null,
  starts_at timestamptz not null, ends_at timestamptz not null, available boolean not null default false, reason text,
  check (ends_at > starts_at), foreign key (employee_id, company_id) references public.employees(id, company_id)
);
create table public.visits (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid not null,
  employee_id uuid, visit_type text not null default 'Care visit', starts_at timestamptz not null, ends_at timestamptz not null,
  status text not null default 'scheduled' check (status in ('scheduled','in_progress','completed','missed','cancelled')),
  recurrence_group_id uuid, actual_arrival_at timestamptz, actual_departure_at timestamptz, arrival_lat numeric, arrival_lng numeric,
  departure_lat numeric, departure_lng numeric, notes text, cancellation_reason text, created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check (ends_at > starts_at), unique (id, company_id),
  foreign key (service_user_id, company_id) references public.service_users(id, company_id),
  foreign key (employee_id, company_id) references public.employees(id, company_id)
);
create table public.visit_tasks (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), visit_id uuid not null,
  title text not null, instructions text, required boolean not null default true, completed boolean not null default false,
  completed_at timestamptz, completed_by uuid references auth.users(id), sort_order integer not null default 0,
  foreign key (visit_id, company_id) references public.visits(id, company_id) on delete cascade
);
create table public.care_records (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), visit_id uuid not null unique,
  service_user_id uuid not null, personal_care text, nutrition_hydration text, mobility text, wellbeing text, notes text,
  completed_by uuid not null default auth.uid() references auth.users(id), completed_at timestamptz not null default now(), amended_at timestamptz, amendment_reason text,
  foreign key (visit_id, company_id) references public.visits(id, company_id), foreign key (service_user_id, company_id) references public.service_users(id, company_id)
);

create table public.medications (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid not null,
  name text not null, form text, strength text, route text, instructions text, prn boolean not null default false,
  start_date date not null default current_date, end_date date, status text not null default 'active' check (status in ('active','stopped','archived')),
  prescriber text, pharmacy text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (id, company_id),
  foreign key (service_user_id, company_id) references public.service_users(id, company_id)
);
create table public.medication_schedules (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), medication_id uuid not null,
  dose text not null, scheduled_time time, days_of_week integer[] not null default '{0,1,2,3,4,5,6}', notes text,
  foreign key (medication_id, company_id) references public.medications(id, company_id) on delete cascade
);
create table public.mar_entries (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), medication_id uuid not null,
  service_user_id uuid not null, visit_id uuid, scheduled_for timestamptz not null, outcome text not null check (outcome in ('given','refused','omitted','not_available','asleep','other')),
  dose_given text, reason text, administered_by uuid not null default auth.uid() references auth.users(id), administered_at timestamptz not null default now(),
  foreign key (medication_id, company_id) references public.medications(id, company_id), foreign key (service_user_id, company_id) references public.service_users(id, company_id),
  foreign key (visit_id, company_id) references public.visits(id, company_id)
);

create table public.incidents (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid,
  incident_type text not null, severity text not null default 'low' check (severity in ('low','medium','high','critical')),
  occurred_at timestamptz not null, location text, description text not null, immediate_action text, status text not null default 'open' check (status in ('open','investigating','actions_pending','closed')),
  reported_by uuid not null default auth.uid() references auth.users(id), assigned_to uuid references auth.users(id), regulator_notifiable boolean not null default false,
  closed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key (service_user_id, company_id) references public.service_users(id, company_id), unique(id,company_id)
);
create table public.incident_actions (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), incident_id uuid not null,
  action text not null, owner_id uuid references auth.users(id), due_date date, completed_at timestamptz, created_at timestamptz not null default now(),
  foreign key (incident_id,company_id) references public.incidents(id,company_id) on delete cascade
);
create table public.safeguarding_records (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid not null,
  concern_type text not null, concern_details text not null, risk_level text not null check (risk_level in ('low','medium','high','immediate')),
  status text not null default 'open' check (status in ('open','referred','investigating','closed')),
  reported_by uuid not null default auth.uid() references auth.users(id), local_authority_ref text, police_ref text, referral_at timestamptz,
  outcome text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key (service_user_id, company_id) references public.service_users(id, company_id)
);

create table public.timesheets (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), employee_id uuid not null,
  period_start date not null, period_end date not null, regular_minutes integer not null default 0, overtime_minutes integer not null default 0,
  status text not null default 'draft' check (status in ('draft','submitted','approved','rejected','exported')), submitted_at timestamptz,
  approved_by uuid references auth.users(id), approved_at timestamptz, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (period_end >= period_start), foreign key (employee_id, company_id) references public.employees(id, company_id), unique (employee_id, period_start, period_end)
);
create table public.expenses (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), employee_id uuid not null,
  expense_date date not null, category text not null, description text, amount numeric(12,2) not null check (amount >= 0), receipt_path text,
  status text not null default 'submitted' check (status in ('draft','submitted','approved','rejected','paid')), approved_by uuid references auth.users(id), created_at timestamptz not null default now(),
  foreign key (employee_id, company_id) references public.employees(id, company_id)
);
create table public.mileage_claims (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), employee_id uuid not null,
  journey_date date not null, origin text, destination text, miles numeric(10,2) not null check (miles >= 0), rate numeric(8,4) not null default 0.45,
  purpose text, status text not null default 'submitted' check (status in ('draft','submitted','approved','rejected','paid')), created_at timestamptz not null default now(),
  foreign key (employee_id, company_id) references public.employees(id, company_id)
);
create table public.pay_rates (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), employee_id uuid not null,
  hourly_rate numeric(10,2) not null, overtime_rate numeric(10,2), effective_from date not null, effective_to date,
  foreign key (employee_id, company_id) references public.employees(id, company_id)
);
create table public.charge_rates (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid,
  name text not null, hourly_rate numeric(10,2) not null, effective_from date not null, effective_to date,
  foreign key (service_user_id, company_id) references public.service_users(id, company_id)
);
create table public.invoices (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid,
  invoice_number text not null, period_start date, period_end date, issue_date date not null default current_date, due_date date,
  subtotal numeric(12,2) not null default 0, tax numeric(12,2) not null default 0, total numeric(12,2) generated always as (subtotal + tax) stored,
  status text not null default 'draft' check (status in ('draft','issued','part_paid','paid','void')), paid_at timestamptz, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (company_id, invoice_number), unique (id, company_id),
  foreign key (service_user_id, company_id) references public.service_users(id, company_id)
);
create table public.invoice_items (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), invoice_id uuid not null,
  description text not null, quantity numeric(10,2) not null default 1, unit_price numeric(12,2) not null, line_total numeric(12,2) generated always as (quantity * unit_price) stored,
  foreign key (invoice_id, company_id) references public.invoices(id, company_id) on delete cascade
);

create table public.documents (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid,
  employee_id uuid, category text not null, name text not null, storage_path text not null, mime_type text, size_bytes bigint,
  uploaded_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now(),
  foreign key (service_user_id, company_id) references public.service_users(id, company_id), foreign key (employee_id, company_id) references public.employees(id, company_id)
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), user_id uuid not null references auth.users(id),
  title text not null, body text, severity text not null default 'info' check (severity in ('info','warning','critical')),
  link text, read_at timestamptz, created_at timestamptz not null default now()
);
create table public.export_jobs (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), requested_by uuid not null default auth.uid() references auth.users(id),
  export_type text not null, filters jsonb not null default '{}', status text not null default 'queued' check (status in ('queued','processing','ready','failed','expired')),
  storage_path text, expires_at timestamptz, created_at timestamptz not null default now()
);

-- Protect tenant ownership on every new tenant table.
create or replace function public.prevent_company_id_change() returns trigger language plpgsql
set search_path = pg_catalog, public as $$ begin if new.company_id <> old.company_id then raise exception 'company_id is immutable'; end if; return new; end; $$;
revoke execute on function public.prevent_company_id_change() from public, anon, authenticated;
do $$ declare t text; begin foreach t in array array[
  'care_plans','care_plan_sections','risk_assessments','working_patterns','availability_exceptions','visits','visit_tasks','care_records',
  'medications','medication_schedules','mar_entries','incidents','incident_actions','safeguarding_records','timesheets','expenses','mileage_claims',
  'pay_rates','charge_rates','invoices','invoice_items','documents','notifications','export_jobs'
] loop execute format('create trigger %I before update on public.%I for each row execute function public.prevent_company_id_change()', t || '_company_immutable', t); end loop; end $$;

-- Enable RLS first; no table is exposed before its policies exist.
do $$ declare t text; begin foreach t in array array[
  'care_plans','care_plan_sections','risk_assessments','working_patterns','availability_exceptions','visits','visit_tasks','care_records',
  'medications','medication_schedules','mar_entries','incidents','incident_actions','safeguarding_records','timesheets','expenses','mileage_claims',
  'pay_rates','charge_rates','invoices','invoice_items','documents','notifications','export_jobs'
] loop execute format('alter table public.%I enable row level security', t); end loop; end $$;

-- Care-plan and risk policies.
create policy care_plans_select on public.care_plans for select using (public.can_access_service_user(company_id, service_user_id) and public.has_company_capability(company_id,'care_plans.view'));
create policy care_plans_write on public.care_plans for all using (public.has_company_capability(company_id,'care_plans.manage')) with check (public.has_company_capability(company_id,'care_plans.manage'));
create policy care_plan_sections_select on public.care_plan_sections for select using (public.has_company_capability(company_id,'care_plans.view') and exists(select 1 from public.care_plans p where p.id=care_plan_id and public.can_access_service_user(company_id,p.service_user_id)));
create policy care_plan_sections_write on public.care_plan_sections for all using (public.has_company_capability(company_id,'care_plans.manage')) with check (public.has_company_capability(company_id,'care_plans.manage'));
create policy risks_select on public.risk_assessments for select using (public.can_access_service_user(company_id,service_user_id) and public.has_company_capability(company_id,'risks.view'));
create policy risks_write on public.risk_assessments for all using (public.has_company_capability(company_id,'risks.manage')) with check (public.has_company_capability(company_id,'risks.manage'));

-- Rota and visit policies.
create policy working_patterns_select on public.working_patterns for select using (public.is_active_member(company_id) and (public.has_company_capability(company_id,'rota.view') or exists(select 1 from public.employees e where e.id=employee_id and e.company_id=working_patterns.company_id and e.user_id=auth.uid())));
create policy working_patterns_write on public.working_patterns for all using (public.has_company_capability(company_id,'rota.manage')) with check (public.has_company_capability(company_id,'rota.manage'));
create policy availability_select on public.availability_exceptions for select using (public.is_active_member(company_id) and (public.has_company_capability(company_id,'rota.view') or exists(select 1 from public.employees e where e.id=employee_id and e.company_id=availability_exceptions.company_id and e.user_id=auth.uid())));
create policy availability_write on public.availability_exceptions for all using (public.is_active_member(company_id) and (public.has_company_capability(company_id,'rota.manage') or exists(select 1 from public.employees e where e.id=employee_id and e.company_id=availability_exceptions.company_id and e.user_id=auth.uid()))) with check (public.is_active_member(company_id));
create policy visits_select on public.visits for select using (public.is_active_member(company_id) and ((public.current_role_key(company_id) in ('company_admin','manager','coordinator') and public.has_company_capability(company_id,'visits.view')) or exists(select 1 from public.employees e where e.id=employee_id and e.company_id=visits.company_id and e.user_id=auth.uid())));
create policy visits_schedule on public.visits for insert with check (public.has_company_capability(company_id,'visits.schedule'));
create policy visits_update on public.visits for update using (public.is_active_member(company_id) and (public.has_company_capability(company_id,'visits.schedule') or (public.has_company_capability(company_id,'visits.complete') and exists(select 1 from public.employees e where e.id=employee_id and e.company_id=visits.company_id and e.user_id=auth.uid())))) with check (public.is_active_member(company_id));
create policy visit_tasks_select on public.visit_tasks for select using (exists(select 1 from public.visits v where v.id=visit_id));
create policy visit_tasks_write on public.visit_tasks for all using (public.has_company_capability(company_id,'visits.schedule') or public.has_company_capability(company_id,'visits.complete')) with check (public.is_active_member(company_id));
create policy care_records_select on public.care_records for select using (public.can_access_service_user(company_id,service_user_id) and public.has_company_capability(company_id,'visits.view'));
create policy care_records_insert on public.care_records for insert with check (public.has_company_capability(company_id,'visits.complete'));
create policy care_records_update on public.care_records for update using (completed_by=auth.uid() or public.has_company_capability(company_id,'visits.schedule')) with check (public.is_active_member(company_id));

-- Medication policies.
create policy medications_select on public.medications for select using (public.can_access_service_user(company_id,service_user_id) and public.has_company_capability(company_id,'medication.view'));
create policy medications_write on public.medications for all using (public.has_company_capability(company_id,'medication.manage')) with check (public.has_company_capability(company_id,'medication.manage'));
create policy medication_schedules_select on public.medication_schedules for select using (public.has_company_capability(company_id,'medication.view') and exists(select 1 from public.medications m where m.id=medication_id and public.can_access_service_user(company_id,m.service_user_id)));
create policy medication_schedules_write on public.medication_schedules for all using (public.has_company_capability(company_id,'medication.manage')) with check (public.has_company_capability(company_id,'medication.manage'));
create policy mar_select on public.mar_entries for select using (public.can_access_service_user(company_id,service_user_id) and public.has_company_capability(company_id,'medication.view'));
create policy mar_insert on public.mar_entries for insert with check (public.can_access_service_user(company_id,service_user_id) and public.has_company_capability(company_id,'medication.administer'));

-- Incident and safeguarding policies.
create policy incidents_select on public.incidents for select using (public.is_active_member(company_id) and public.has_company_capability(company_id,'incidents.view'));
create policy incidents_insert on public.incidents for insert with check (public.has_company_capability(company_id,'incidents.create'));
create policy incidents_update on public.incidents for update using (public.has_company_capability(company_id,'incidents.manage')) with check (public.has_company_capability(company_id,'incidents.manage'));
create policy incident_actions_select on public.incident_actions for select using (public.has_company_capability(company_id,'incidents.view'));
create policy incident_actions_write on public.incident_actions for all using (public.has_company_capability(company_id,'incidents.manage')) with check (public.has_company_capability(company_id,'incidents.manage'));
create policy safeguarding_select on public.safeguarding_records for select using (public.has_company_capability(company_id,'safeguarding.view'));
create policy safeguarding_insert on public.safeguarding_records for insert with check (public.has_company_capability(company_id,'safeguarding.create'));
create policy safeguarding_update on public.safeguarding_records for update using (public.has_company_capability(company_id,'safeguarding.manage')) with check (public.has_company_capability(company_id,'safeguarding.manage'));

-- Workforce, finance, documents, notifications and exports.
create policy timesheets_select on public.timesheets for select using (public.is_active_member(company_id) and (public.has_company_capability(company_id,'timesheets.view') or exists(select 1 from public.employees e where e.id=employee_id and e.company_id=timesheets.company_id and e.user_id=auth.uid())));
create policy timesheets_write on public.timesheets for all using (public.is_active_member(company_id) and (public.has_company_capability(company_id,'timesheets.approve') or exists(select 1 from public.employees e where e.id=employee_id and e.company_id=timesheets.company_id and e.user_id=auth.uid()))) with check (public.is_active_member(company_id));
create policy expenses_policy on public.expenses for all using (public.is_active_member(company_id) and (public.has_company_capability(company_id,'timesheets.approve') or exists(select 1 from public.employees e where e.id=employee_id and e.company_id=expenses.company_id and e.user_id=auth.uid()))) with check (public.is_active_member(company_id));
create policy mileage_policy on public.mileage_claims for all using (public.is_active_member(company_id) and (public.has_company_capability(company_id,'timesheets.approve') or exists(select 1 from public.employees e where e.id=employee_id and e.company_id=mileage_claims.company_id and e.user_id=auth.uid()))) with check (public.is_active_member(company_id));
create policy pay_rates_policy on public.pay_rates for all using (public.has_company_capability(company_id,'payroll.view')) with check (public.has_company_capability(company_id,'payroll.manage'));
create policy charge_rates_policy on public.charge_rates for all using (public.has_company_capability(company_id,'invoices.view')) with check (public.has_company_capability(company_id,'invoices.manage'));
create policy invoices_policy on public.invoices for all using (public.has_company_capability(company_id,'invoices.view')) with check (public.has_company_capability(company_id,'invoices.manage'));
create policy invoice_items_policy on public.invoice_items for all using (public.has_company_capability(company_id,'invoices.view')) with check (public.has_company_capability(company_id,'invoices.manage'));
create policy documents_select on public.documents for select using (public.has_company_capability(company_id,'documents.view') and (service_user_id is null or public.can_access_service_user(company_id,service_user_id)));
create policy documents_write on public.documents for all using (public.has_company_capability(company_id,'documents.manage')) with check (public.has_company_capability(company_id,'documents.manage'));
create policy notifications_select on public.notifications for select using (public.is_active_member(company_id) and user_id=auth.uid());
create policy notifications_update on public.notifications for update using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy exports_policy on public.export_jobs for all using (public.has_company_capability(company_id,'exports.create') and requested_by=auth.uid()) with check (public.has_company_capability(company_id,'exports.create') and requested_by=auth.uid());

-- Generic metadata-only audit trigger: clinical text is deliberately excluded.
create or replace function public.audit_tenant_change() returns trigger language plpgsql security definer
set search_path = pg_catalog, public as $$
declare row_id uuid; tenant_id uuid; verb text;
begin
  if tg_op='DELETE' then row_id:=old.id; tenant_id:=old.company_id; else row_id:=new.id; tenant_id:=new.company_id; end if;
  verb:=lower(tg_op); perform public.insert_audit_event(tenant_id,auth.uid(),verb,tg_table_name,row_id,null,null,null,null);
  return coalesce(new,old);
end; $$;
revoke execute on function public.audit_tenant_change() from public, anon, authenticated;
do $$ declare t text; begin foreach t in array array[
  'care_plans','risk_assessments','visits','care_records','medications','mar_entries','incidents','safeguarding_records','timesheets','expenses','mileage_claims','pay_rates','invoices','documents'
] loop execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.audit_tenant_change()', t || '_audit', t); end loop; end $$;

-- Dashboard RPC avoids exposing cross-module aggregation logic to the client.
create or replace function public.get_dashboard_metrics(target_company_id uuid)
returns jsonb language plpgsql security definer stable set search_path=pg_catalog,public as $$
begin
  if not public.is_active_member(target_company_id) then raise exception 'not authorised'; end if;
  return jsonb_build_object(
    'service_users',(select count(*) from public.service_users where company_id=target_company_id and status='active'),
    'employees',(select count(*) from public.employees where company_id=target_company_id and status='active'),
    'visits_today',(select count(*) from public.visits where company_id=target_company_id and starts_at::date=current_date),
    'completed_today',(select count(*) from public.visits where company_id=target_company_id and starts_at::date=current_date and status='completed'),
    'open_incidents',(select count(*) from public.incidents where company_id=target_company_id and status<>'closed'),
    'medication_exceptions',(select count(*) from public.mar_entries where company_id=target_company_id and scheduled_for::date=current_date and outcome<>'given')
  );
end; $$;
revoke execute on function public.get_dashboard_metrics(uuid) from public;
grant execute on function public.get_dashboard_metrics(uuid) to authenticated;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('careflow-private','careflow-private',false,10485760,array['application/pdf','image/jpeg','image/png','text/csv']) on conflict (id) do nothing;
create policy careflow_storage_select on storage.objects for select to authenticated using (
  bucket_id='careflow-private' and public.is_active_member((storage.foldername(name))[1]::uuid)
);
create policy careflow_storage_insert on storage.objects for insert to authenticated with check (
  bucket_id='careflow-private' and public.has_company_capability((storage.foldername(name))[1]::uuid,'documents.manage')
);

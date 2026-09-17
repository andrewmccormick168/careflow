-- UK workforce compliance, service catalogue and governance registers.

insert into public.roles(key,label) values
  ('compliance_officer','Compliance Officer'),
  ('client_representative','Client / Representative')
on conflict (key) do nothing;

insert into public.role_capabilities(role_id,capability_id)
select r.id,c.id from public.roles r cross join public.capabilities c
where r.key='compliance_officer' and c.key in (
  'employees.view','employees.manage','service_users.view','care_plans.view','risks.view',
  'incidents.view','incidents.manage','safeguarding.view','safeguarding.manage',
  'documents.view','documents.manage','reports.view','exports.create','audit.view'
) on conflict do nothing;

alter table public.employees
  add column if not exists employee_number text,
  add column if not exists contracted_minutes_weekly integer check (contracted_minutes_weekly is null or contracted_minutes_weekly>=0),
  add column if not exists max_daily_visits integer check (max_daily_visits is null or max_daily_visits>0),
  add column if not exists has_driving_licence boolean not null default false,
  add column if not exists has_business_insurance boolean not null default false,
  add column if not exists transport_mode text check (transport_mode is null or transport_mode in ('car','bicycle','public_transport','walk','other')),
  add column if not exists primary_language text,
  add column if not exists additional_languages text[],
  add column if not exists probation_end_date date,
  add column if not exists employment_type text check (employment_type is null or employment_type in ('permanent','fixed_term','bank','agency','self_employed')),
  add column if not exists employment_status text not null default 'active' check (employment_status in ('pre_employment','active','suspended','leave','leaver'));

create unique index if not exists employees_number_unique on public.employees(company_id,employee_number) where employee_number is not null;

create table public.employee_compliance (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), employee_id uuid not null,
  right_to_work_status text not null default 'not_checked' check (right_to_work_status in ('not_checked','verified','time_limited','failed')),
  right_to_work_checked_at date, right_to_work_expiry date, right_to_work_reference text,
  disclosure_scheme text check (disclosure_scheme is null or disclosure_scheme in ('pvg','dbs','accessni')),
  disclosure_level text, disclosure_number text, disclosure_issue_date date, disclosure_review_date date,
  barred_list_checked boolean not null default false,
  registration_body text check (registration_body is null or registration_body in ('sssc','social_care_wales','niscc','nmc','hcpc','other')),
  registration_number text, registration_expiry date, registration_status text not null default 'not_required' check (registration_status in ('not_required','pending','active','expired','suspended')),
  two_references_received boolean not null default false, identity_verified boolean not null default false,
  health_declaration_completed boolean not null default false, recruitment_complete boolean not null default false,
  notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(employee_id), unique(id,company_id),
  foreign key(employee_id,company_id) references public.employees(id,company_id) on delete cascade
);

create table public.training_courses (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
  name text not null, category text not null, mandatory boolean not null default true,
  validity_months integer check (validity_months is null or validity_months>0), description text,
  status text not null default 'active' check(status in ('active','retired')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(id,company_id), unique(company_id,name)
);

create table public.employee_training (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), employee_id uuid not null, course_id uuid not null,
  completed_at date, expires_at date, provider text, certificate_number text, certificate_path text,
  status text not null default 'required' check(status in ('required','booked','complete','expired','waived')),
  evidence_verified_by uuid references auth.users(id), evidence_verified_at timestamptz, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(employee_id,course_id),
  foreign key(employee_id,company_id) references public.employees(id,company_id) on delete cascade,
  foreign key(course_id,company_id) references public.training_courses(id,company_id) on delete cascade
);

create table public.service_types (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
  name text not null, category text not null, description text, default_duration_minutes integer not null check(default_duration_minutes>0),
  default_travel_minutes integer not null default 15 check(default_travel_minutes>=0), minimum_staff integer not null default 1 check(minimum_staff between 1 and 4),
  medication_support boolean not null default false, regulated_activity boolean not null default true,
  task_template jsonb not null default '[]'::jsonb check(jsonb_typeof(task_template)='array'),
  status text not null default 'active' check(status in ('active','inactive')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(id,company_id),unique(company_id,name)
);

create table public.service_type_training_requirements (
  company_id uuid not null references public.companies(id), service_type_id uuid not null, course_id uuid not null,
  primary key(service_type_id,course_id),
  foreign key(service_type_id,company_id) references public.service_types(id,company_id) on delete cascade,
  foreign key(course_id,company_id) references public.training_courses(id,company_id) on delete cascade
);

create table public.service_user_staff_preferences (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid not null, employee_id uuid not null,
  preference text not null check(preference in ('preferred','excluded')), reason text, created_at timestamptz not null default now(),
  unique(service_user_id,employee_id),
  foreign key(service_user_id,company_id) references public.service_users(id,company_id) on delete cascade,
  foreign key(employee_id,company_id) references public.employees(id,company_id) on delete cascade
);

create table public.complaints (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid,
  reference text not null, received_at timestamptz not null default now(), complainant_name text, relationship text,
  category text not null, details text not null, desired_outcome text, acknowledgement_due date, response_due date,
  status text not null default 'open' check(status in ('open','acknowledged','investigating','response_issued','closed')),
  assigned_to uuid references auth.users(id), outcome text, lessons_learned text, closed_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(id,company_id),unique(company_id,reference),
  foreign key(service_user_id,company_id) references public.service_users(id,company_id)
);

create table public.data_rights_requests (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), service_user_id uuid,
  request_type text not null check(request_type in ('access','rectification','erasure','restriction','portability','objection')),
  received_at date not null default current_date, identity_verified_at timestamptz, due_at date not null,
  status text not null default 'open' check(status in ('open','identity_check','processing','extended','completed','refused')),
  decision text, completed_at timestamptz, created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now(),
  foreign key(service_user_id,company_id) references public.service_users(id,company_id)
);

create table public.data_breaches (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
  detected_at timestamptz not null, summary text not null, data_categories text[], people_affected integer,
  risk_level text not null check(risk_level in ('low','medium','high')), containment_action text,
  ico_notification_required boolean, ico_notified_at timestamptz, individuals_notified_at timestamptz,
  status text not null default 'investigating' check(status in ('investigating','contained','reported','closed')),
  created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

insert into public.training_courses(company_id,name,category,mandatory,validity_months)
select c.id,x.name,x.category,true,x.months from public.companies c cross join (values
 ('Moving and handling','Care delivery',12),('Medication administration','Medication',12),('Adult safeguarding','Safeguarding',12),
 ('Infection prevention and control','Safety',12),('Emergency first aid','Safety',36),('Food hygiene','Safety',36),
 ('Health and safety','Safety',12),('Data protection and confidentiality','Governance',12)
) as x(name,category,months) on conflict(company_id,name) do nothing;

insert into public.service_types(company_id,name,category,default_duration_minutes,default_travel_minutes,minimum_staff,medication_support)
select c.id,x.name,x.category,x.duration,15,x.staff,x.medication from public.companies c cross join (values
 ('Personal care','Personal care',30,1,false),('Medication support','Medication',15,1,true),('Meal preparation','Nutrition',30,1,false),
 ('Domestic support','Domestic',60,1,false),('Companionship','Social support',60,1,false),('Night sit','Night care',480,1,false),
 ('Respite care','Respite',240,1,false),('Palliative care','Complex care',60,2,true),('Complex care','Complex care',60,2,true)
) as x(name,category,duration,staff,medication) on conflict(company_id,name) do nothing;

alter table public.employee_compliance enable row level security;
alter table public.training_courses enable row level security;
alter table public.employee_training enable row level security;
alter table public.service_types enable row level security;
alter table public.service_type_training_requirements enable row level security;
alter table public.service_user_staff_preferences enable row level security;
alter table public.complaints enable row level security;
alter table public.data_rights_requests enable row level security;
alter table public.data_breaches enable row level security;

create policy employee_compliance_access on public.employee_compliance for all using(public.has_company_capability(company_id,'employees.view')) with check(public.has_company_capability(company_id,'employees.manage'));
create policy training_courses_access on public.training_courses for all using(public.is_active_member(company_id)) with check(public.has_company_capability(company_id,'employees.manage'));
create policy employee_training_access on public.employee_training for all using(public.has_company_capability(company_id,'employees.view')) with check(public.has_company_capability(company_id,'employees.manage'));
create policy service_types_access on public.service_types for all using(public.is_active_member(company_id)) with check(public.has_company_capability(company_id,'settings.manage'));
create policy service_training_access on public.service_type_training_requirements for all using(public.is_active_member(company_id)) with check(public.has_company_capability(company_id,'settings.manage'));
create policy staff_preferences_access on public.service_user_staff_preferences for all using(public.can_access_service_user(company_id,service_user_id)) with check(public.has_company_capability(company_id,'service_users.manage'));
create policy complaints_access on public.complaints for all using(public.has_company_capability(company_id,'incidents.view')) with check(public.has_company_capability(company_id,'incidents.manage'));
create policy data_rights_access on public.data_rights_requests for all using(public.has_company_capability(company_id,'audit.view')) with check(public.has_company_capability(company_id,'settings.manage'));
create policy data_breaches_access on public.data_breaches for all using(public.has_company_capability(company_id,'audit.view')) with check(public.has_company_capability(company_id,'settings.manage'));

grant select,insert,update on public.employee_compliance,public.training_courses,public.employee_training,public.service_types,public.service_type_training_requirements,public.service_user_staff_preferences,public.complaints,public.data_rights_requests,public.data_breaches to authenticated;
grant update(employee_number,contracted_minutes_weekly,max_daily_visits,has_driving_licence,has_business_insurance,transport_mode,primary_language,additional_languages,probation_end_date,employment_type,employment_status) on public.employees to authenticated;

create trigger employee_compliance_updated_at before update on public.employee_compliance for each row execute function public.set_updated_at();
create trigger training_courses_updated_at before update on public.training_courses for each row execute function public.set_updated_at();
create trigger employee_training_updated_at before update on public.employee_training for each row execute function public.set_updated_at();
create trigger service_types_updated_at before update on public.service_types for each row execute function public.set_updated_at();
create trigger complaints_updated_at before update on public.complaints for each row execute function public.set_updated_at();
create trigger data_breaches_updated_at before update on public.data_breaches for each row execute function public.set_updated_at();

-- Reliable operational-area writes and the first controlled-record layer for
-- complete service-user profiles, general concerns and reusable care forms.

alter table public.service_users
  add column if not exists date_of_birth date,
  add column if not exists nhs_chi_number text,
  add column if not exists postcode text,
  add column if not exists pronouns text,
  add column if not exists primary_language text,
  add column if not exists religion_faith text,
  add column if not exists ethnicity text,
  add column if not exists gp_name text,
  add column if not exists gp_practice text,
  add column if not exists gp_phone text,
  add column if not exists diagnoses text,
  add column if not exists allergies text,
  add column if not exists dietary_requirements text,
  add column if not exists mobility_requirements text,
  add column if not exists visit_constraints text,
  add column if not exists authorised_weekly_minutes integer check (authorised_weekly_minutes is null or authorised_weekly_minutes >= 0),
  add column if not exists personal_budget numeric(12,2) check (personal_budget is null or personal_budget >= 0),
  add column if not exists consent_to_care boolean,
  add column if not exists consent_to_share_information boolean,
  add column if not exists consent_recorded_at timestamptz,
  add column if not exists consent_review_due date,
  add column if not exists capacity_status text check (capacity_status is null or capacity_status in ('not_assessed','has_capacity','lacks_capacity','fluctuating')),
  add column if not exists capacity_details text,
  add column if not exists advance_care_plan boolean not null default false,
  add column if not exists dnacpr_in_place boolean not null default false,
  add column if not exists dnacpr_location text,
  add column if not exists lpa_in_place boolean not null default false,
  add column if not exists lpa_details text,
  add column if not exists data_objection_preferences text,
  add column if not exists retention_review_date date;

create table public.care_concerns (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  service_user_id uuid not null,
  concern_type text not null,
  severity text not null default 'medium' check (severity in ('low','medium','high','immediate')),
  occurred_at timestamptz not null default now(),
  details text not null,
  immediate_action text,
  escalation_required boolean not null default false,
  escalated_to text,
  status text not null default 'open' check (status in ('open','reviewing','action_required','closed')),
  outcome text,
  reported_by uuid not null default auth.uid() references auth.users(id),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, company_id),
  foreign key (service_user_id, company_id) references public.service_users(id, company_id)
);

create table public.form_templates (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  name text not null,
  category text not null,
  description text,
  instructions text,
  fields jsonb not null default '[]'::jsonb check (jsonb_typeof(fields)='array'),
  version integer not null default 1 check (version > 0),
  review_frequency_days integer check (review_frequency_days is null or review_frequency_days > 0),
  status text not null default 'active' check (status in ('draft','active','retired')),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, company_id),
  unique (company_id, name, version)
);

create table public.form_submissions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  template_id uuid not null,
  service_user_id uuid,
  visit_id uuid,
  title text not null,
  responses jsonb not null default '{}'::jsonb check (jsonb_typeof(responses)='object'),
  status text not null default 'draft' check (status in ('draft','completed','review_required','approved','superseded')),
  completed_by uuid references auth.users(id),
  completed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_notes text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, company_id),
  foreign key (template_id, company_id) references public.form_templates(id, company_id),
  foreign key (service_user_id, company_id) references public.service_users(id, company_id),
  foreign key (visit_id, company_id) references public.visits(id, company_id)
);

create index care_concerns_person_idx on public.care_concerns(company_id, service_user_id, occurred_at desc);
create index form_templates_status_idx on public.form_templates(company_id, status, category);
create index form_submissions_person_idx on public.form_submissions(company_id, service_user_id, created_at desc);

alter table public.care_concerns enable row level security;
alter table public.form_templates enable row level security;
alter table public.form_submissions enable row level security;

create policy care_concerns_select on public.care_concerns for select using (
  public.can_access_service_user(company_id,service_user_id)
  and (public.has_company_capability(company_id,'incidents.view') or public.has_company_capability(company_id,'care_plans.view'))
);
create policy care_concerns_insert on public.care_concerns for insert with check (
  public.can_access_service_user(company_id,service_user_id)
  and (public.has_company_capability(company_id,'incidents.create') or public.has_company_capability(company_id,'care_plans.manage'))
);
create policy care_concerns_update on public.care_concerns for update using (
  public.can_access_service_user(company_id,service_user_id) and public.has_company_capability(company_id,'incidents.manage')
) with check (
  public.can_access_service_user(company_id,service_user_id) and public.has_company_capability(company_id,'incidents.manage')
);
create policy form_templates_select on public.form_templates for select using (
  public.is_active_member(company_id) and (public.has_company_capability(company_id,'documents.view') or public.has_company_capability(company_id,'care_plans.view'))
);
create policy form_templates_write on public.form_templates for all using (
  public.has_company_capability(company_id,'documents.manage')
) with check (public.has_company_capability(company_id,'documents.manage'));
create policy form_submissions_select on public.form_submissions for select using (
  public.is_active_member(company_id)
  and (service_user_id is null or public.can_access_service_user(company_id,service_user_id))
  and (public.has_company_capability(company_id,'documents.view') or public.has_company_capability(company_id,'care_plans.view'))
);
create policy form_submissions_write on public.form_submissions for all using (
  public.has_company_capability(company_id,'documents.manage')
  and (service_user_id is null or public.can_access_service_user(company_id,service_user_id))
) with check (
  public.has_company_capability(company_id,'documents.manage')
  and (service_user_id is null or public.can_access_service_user(company_id,service_user_id))
);

grant select,insert,update on public.care_concerns to authenticated;
grant select,insert,update on public.form_templates to authenticated;
grant select,insert,update on public.form_submissions to authenticated;
grant update (
  date_of_birth,nhs_chi_number,postcode,pronouns,primary_language,religion_faith,ethnicity,
  gp_name,gp_practice,gp_phone,diagnoses,allergies,dietary_requirements,mobility_requirements,
  visit_constraints,authorised_weekly_minutes,personal_budget,consent_to_care,
  consent_to_share_information,consent_recorded_at,consent_review_due,capacity_status,
  capacity_details,advance_care_plan,dnacpr_in_place,dnacpr_location,lpa_in_place,lpa_details,
  data_objection_preferences,retention_review_date
) on public.service_users to authenticated;

create trigger care_concerns_updated_at before update on public.care_concerns for each row execute function public.set_updated_at();
create trigger form_templates_updated_at before update on public.form_templates for each row execute function public.set_updated_at();
create trigger form_submissions_updated_at before update on public.form_submissions for each row execute function public.set_updated_at();

create or replace function public.save_operational_area(
  target_company_id uuid,
  target_area_id uuid,
  p_name text,
  p_code text,
  p_office_name text default null,
  p_address text default null,
  p_contact_phone text default null,
  p_contact_email text default null,
  p_manager_id uuid default null,
  p_status text default 'active'
) returns public.operational_areas
language plpgsql security definer set search_path=pg_catalog,public as $$
declare saved public.operational_areas; before_row jsonb;
begin
  if not public.has_company_capability(target_company_id,'settings.manage') then raise exception 'Not authorised to manage operational areas'; end if;
  if nullif(btrim(p_name),'') is null or nullif(btrim(p_code),'') is null then raise exception 'Area name and code are required'; end if;
  if p_status not in ('active','inactive') then raise exception 'Invalid area status'; end if;
  if p_manager_id is not null and not exists(select 1 from public.employees where id=p_manager_id and company_id=target_company_id) then raise exception 'Area manager does not belong to this organisation'; end if;
  if target_area_id is null then
    insert into public.operational_areas(company_id,name,code,office_name,address,contact_phone,contact_email,manager_id,status)
    values(target_company_id,btrim(p_name),upper(btrim(p_code)),nullif(btrim(p_office_name),''),nullif(btrim(p_address),''),nullif(btrim(p_contact_phone),''),nullif(lower(btrim(p_contact_email)),''),p_manager_id,p_status)
    returning * into saved;
    perform public.insert_audit_event(target_company_id,auth.uid(),'operational_area_created','operational_area',saved.id,null,to_jsonb(saved),null,null);
  else
    select to_jsonb(a) into before_row from public.operational_areas a where a.id=target_area_id and a.company_id=target_company_id for update;
    if before_row is null then raise exception 'Operational area not found'; end if;
    update public.operational_areas set name=btrim(p_name),code=upper(btrim(p_code)),office_name=nullif(btrim(p_office_name),''),address=nullif(btrim(p_address),''),contact_phone=nullif(btrim(p_contact_phone),''),contact_email=nullif(lower(btrim(p_contact_email)),''),manager_id=p_manager_id,status=p_status
    where id=target_area_id and company_id=target_company_id returning * into saved;
    perform public.insert_audit_event(target_company_id,auth.uid(),'operational_area_updated','operational_area',saved.id,before_row,to_jsonb(saved),null,null);
  end if;
  return saved;
exception when unique_violation then raise exception 'An area with code % already exists',upper(btrim(p_code));
end;
$$;
revoke all on function public.save_operational_area(uuid,uuid,text,text,text,text,text,text,uuid,text) from public,anon;
grant execute on function public.save_operational_area(uuid,uuid,text,text,text,text,text,text,uuid,text) to authenticated;

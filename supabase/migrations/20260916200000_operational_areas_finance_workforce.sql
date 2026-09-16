-- Operational areas, debtor payments, visit-derived workforce reporting and
-- richer care-plan review records.

create table public.operational_areas (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  name text not null,
  code text not null,
  office_name text,
  address text,
  contact_phone text,
  contact_email text,
  manager_id uuid,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, company_id),
  unique (company_id, code),
  foreign key (manager_id, company_id) references public.employees(id, company_id)
);

alter table public.company_memberships
  add column all_areas boolean not null default true;

create table public.membership_area_access (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  membership_id uuid not null references public.company_memberships(id) on delete cascade,
  area_id uuid not null,
  created_at timestamptz not null default now(),
  unique (membership_id, area_id),
  foreign key (area_id, company_id) references public.operational_areas(id, company_id)
);

alter table public.employees add column area_id uuid;
alter table public.service_users add column area_id uuid;
alter table public.visits add column area_id uuid;
alter table public.care_visit_requirements add column area_id uuid;
alter table public.invoices add column area_id uuid;
alter table public.timesheets add column area_id uuid;

alter table public.employees add foreign key (area_id, company_id) references public.operational_areas(id, company_id);
alter table public.service_users add foreign key (area_id, company_id) references public.operational_areas(id, company_id);
alter table public.visits add foreign key (area_id, company_id) references public.operational_areas(id, company_id);
alter table public.care_visit_requirements add foreign key (area_id, company_id) references public.operational_areas(id, company_id);
alter table public.invoices add foreign key (area_id, company_id) references public.operational_areas(id, company_id);
alter table public.timesheets add foreign key (area_id, company_id) references public.operational_areas(id, company_id);

insert into public.operational_areas (company_id, name, code, office_name, address, contact_phone, contact_email)
select id, 'Main area', 'MAIN', trading_name, address, contact_phone, contact_email
from public.companies
on conflict (company_id, code) do nothing;

update public.employees e set area_id = a.id
from public.operational_areas a where a.company_id=e.company_id and a.code='MAIN' and e.area_id is null;
update public.service_users s set area_id = a.id
from public.operational_areas a where a.company_id=s.company_id and a.code='MAIN' and s.area_id is null;
update public.visits v set area_id = s.area_id
from public.service_users s where s.id=v.service_user_id and s.company_id=v.company_id and v.area_id is null;
update public.care_visit_requirements r set area_id = s.area_id
from public.service_users s where s.id=r.service_user_id and s.company_id=r.company_id and r.area_id is null;
update public.invoices i set area_id = s.area_id
from public.service_users s where s.id=i.service_user_id and s.company_id=i.company_id and i.area_id is null;
update public.timesheets t set area_id = e.area_id
from public.employees e where e.id=t.employee_id and e.company_id=t.company_id and t.area_id is null;

alter table public.service_users
  add column funding_type text not null default 'private' check (funding_type in ('private','local_authority','nhs','mixed','other')),
  add column payer_name text,
  add column payer_reference text,
  add column payment_terms_days integer not null default 30 check (payment_terms_days between 0 and 180);

create table public.invoice_payments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  invoice_id uuid not null,
  amount numeric(12,2) not null check (amount > 0),
  received_at date not null default current_date,
  method text not null default 'bank_transfer' check (method in ('bank_transfer','direct_debit','card','cash','cheque','credit_note','other')),
  reference text,
  notes text,
  received_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  foreign key (invoice_id, company_id) references public.invoices(id, company_id) on delete cascade
);

alter table public.care_plan_sections
  add column desired_outcome text,
  add column support_guidance text,
  add column review_date date,
  add column status text not null default 'active' check (status in ('draft','active','review_due','superseded'));

create table public.care_plan_reviews (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  care_plan_id uuid not null,
  review_date date not null default current_date,
  outcome text not null check (outcome in ('no_change','updated','new_version','closed')),
  summary text not null,
  next_review_date date,
  reviewed_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  foreign key (care_plan_id, company_id) references public.care_plans(id, company_id) on delete cascade
);

create index employees_area_idx on public.employees(company_id, area_id);
create index service_users_area_idx on public.service_users(company_id, area_id);
create index visits_area_starts_idx on public.visits(company_id, area_id, starts_at);
create index invoices_area_status_idx on public.invoices(company_id, area_id, status);
create index invoice_payments_invoice_idx on public.invoice_payments(company_id, invoice_id);
create index timesheets_area_period_idx on public.timesheets(company_id, area_id, period_start, period_end);

create or replace function public.can_access_area(target_company_id uuid, target_area_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public as $$
  select public.is_active_member(target_company_id) and (
    public.is_platform_admin()
    or public.current_role_key(target_company_id) = 'company_admin'
    or exists (
      select 1 from public.company_memberships cm
      where cm.company_id=target_company_id and cm.user_id=auth.uid()
        and cm.status='active' and cm.all_areas
    )
    or target_area_id is null
    or exists (
      select 1 from public.membership_area_access maa
      join public.company_memberships cm on cm.id=maa.membership_id and cm.company_id=maa.company_id
      where maa.company_id=target_company_id and maa.area_id=target_area_id
        and cm.user_id=auth.uid() and cm.status='active'
    )
  );
$$;
revoke all on function public.can_access_area(uuid,uuid) from public;
grant execute on function public.can_access_area(uuid,uuid) to authenticated;

create or replace function public.can_access_service_user(target_company_id uuid, target_service_user_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public as $$
  select public.is_active_member(target_company_id) and (
    exists (
      select 1 from public.service_users su
      where su.id=target_service_user_id and su.company_id=target_company_id
        and public.current_role_key(target_company_id) in ('company_admin','manager','coordinator','finance')
        and public.can_access_area(target_company_id,su.area_id)
    )
    or exists (
      select 1 from public.service_user_assignments a
      join public.employees e on e.id=a.employee_id and e.company_id=a.company_id
      where a.company_id=target_company_id and a.service_user_id=target_service_user_id
        and a.status='active' and e.user_id=auth.uid()
        and a.start_date<=current_date and (a.end_date is null or a.end_date>=current_date)
    )
  );
$$;
revoke all on function public.can_access_service_user(uuid,uuid) from public;
grant execute on function public.can_access_service_user(uuid,uuid) to authenticated;

create or replace function public.set_operational_area_from_parent()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
  if new.area_id is null then
    if tg_table_name in ('visits','care_visit_requirements','invoices') and new.service_user_id is not null then
      select area_id into new.area_id from public.service_users where id=new.service_user_id and company_id=new.company_id;
    elsif tg_table_name='timesheets' then
      select area_id into new.area_id from public.employees where id=new.employee_id and company_id=new.company_id;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.set_operational_area_from_parent() from public,anon,authenticated;

create trigger visits_set_area before insert on public.visits for each row execute function public.set_operational_area_from_parent();
create trigger requirements_set_area before insert on public.care_visit_requirements for each row execute function public.set_operational_area_from_parent();
create trigger invoices_set_area before insert on public.invoices for each row execute function public.set_operational_area_from_parent();
create trigger timesheets_set_area before insert on public.timesheets for each row execute function public.set_operational_area_from_parent();

create or replace function public.sync_invoice_payment_status()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
declare target_invoice uuid; target_company uuid; invoice_total numeric; paid_total numeric;
begin
  target_invoice:=coalesce(new.invoice_id,old.invoice_id);
  target_company:=coalesce(new.company_id,old.company_id);
  select total into invoice_total from public.invoices where id=target_invoice and company_id=target_company;
  select coalesce(sum(amount),0) into paid_total from public.invoice_payments where invoice_id=target_invoice and company_id=target_company;
  if paid_total>invoice_total then raise exception 'Payment total cannot exceed invoice total'; end if;
  update public.invoices set
    status=case when paid_total=0 then case when status='draft' then 'draft' else 'issued' end when paid_total>=invoice_total then 'paid' else 'part_paid' end,
    paid_at=case when paid_total>=invoice_total then now() else null end,
    updated_at=now()
  where id=target_invoice and company_id=target_company and status<>'void';
  return coalesce(new,old);
end;
$$;
revoke all on function public.sync_invoice_payment_status() from public,anon,authenticated;
create trigger invoice_payments_sync_status after insert or update or delete on public.invoice_payments for each row execute function public.sync_invoice_payment_status();

alter table public.operational_areas enable row level security;
alter table public.membership_area_access enable row level security;
alter table public.invoice_payments enable row level security;
alter table public.care_plan_reviews enable row level security;

create policy operational_areas_select on public.operational_areas for select using (public.can_access_area(company_id,id));
create policy operational_areas_write on public.operational_areas for all using (public.has_company_capability(company_id,'settings.manage')) with check (public.has_company_capability(company_id,'settings.manage'));
create policy membership_area_access_select on public.membership_area_access for select using (
  public.has_company_capability(company_id,'settings.manage') or exists(select 1 from public.company_memberships cm where cm.id=membership_id and cm.user_id=auth.uid())
);
create policy membership_area_access_write on public.membership_area_access for all using (public.has_company_capability(company_id,'settings.manage')) with check (public.has_company_capability(company_id,'settings.manage'));
create policy invoice_payments_select on public.invoice_payments for select using (
  public.has_company_capability(company_id,'invoices.view') and exists(select 1 from public.invoices i where i.id=invoice_id and public.can_access_area(company_id,i.area_id))
);
create policy invoice_payments_write on public.invoice_payments for all using (public.has_company_capability(company_id,'invoices.manage')) with check (public.has_company_capability(company_id,'invoices.manage'));
create policy care_plan_reviews_select on public.care_plan_reviews for select using (
  public.has_company_capability(company_id,'care_plans.view') and exists(select 1 from public.care_plans p where p.id=care_plan_id and public.can_access_service_user(company_id,p.service_user_id))
);
create policy care_plan_reviews_write on public.care_plan_reviews for all using (public.has_company_capability(company_id,'care_plans.manage')) with check (public.has_company_capability(company_id,'care_plans.manage'));

drop policy if exists employees_select on public.employees;
create policy employees_select on public.employees for select using (
  public.is_active_member(company_id) and ((public.has_company_capability(company_id,'employees.view') and public.can_access_area(company_id,area_id)) or user_id=auth.uid())
);
drop policy if exists service_users_select_by_capability on public.service_users;
create policy service_users_select_by_capability on public.service_users for select using (
  public.has_company_capability(company_id,'service_users.view') and public.can_access_area(company_id,area_id)
);
drop policy if exists visits_select on public.visits;
create policy visits_select on public.visits for select using (
  public.is_active_member(company_id) and (
    (public.current_role_key(company_id) in ('company_admin','manager','coordinator') and public.has_company_capability(company_id,'visits.view') and public.can_access_area(company_id,area_id))
    or exists(select 1 from public.employees e where e.id=employee_id and e.company_id=visits.company_id and e.user_id=auth.uid())
    or public.is_assigned_to_visit(id,company_id)
  )
);
drop policy if exists timesheets_select on public.timesheets;
create policy timesheets_select on public.timesheets for select using (
  public.is_active_member(company_id) and ((public.has_company_capability(company_id,'timesheets.view') and public.can_access_area(company_id,area_id)) or exists(select 1 from public.employees e where e.id=employee_id and e.company_id=timesheets.company_id and e.user_id=auth.uid()))
);
drop policy if exists invoices_policy on public.invoices;
create policy invoices_policy on public.invoices for all using (
  public.has_company_capability(company_id,'invoices.view') and public.can_access_area(company_id,area_id)
) with check (public.has_company_capability(company_id,'invoices.manage') and public.can_access_area(company_id,area_id));

grant select,insert,update on public.operational_areas to authenticated;
grant select,insert,delete on public.membership_area_access to authenticated;
grant select,insert,update,delete on public.invoice_payments to authenticated;
grant select,insert,update on public.care_plan_reviews to authenticated;
grant update (all_areas) on public.company_memberships to authenticated;
grant update (area_id) on public.employees,public.service_users to authenticated;
grant update (funding_type,payer_name,payer_reference,payment_terms_days) on public.service_users to authenticated;
grant update (desired_outcome,support_guidance,review_date,status) on public.care_plan_sections to authenticated;

create trigger operational_areas_updated_at before update on public.operational_areas for each row execute function public.set_updated_at();

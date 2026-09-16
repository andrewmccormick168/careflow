-- Recurring care requirements and multi-carer visit allocation.

alter table public.companies
  add column late_visit_threshold_minutes integer not null default 15
    check (late_visit_threshold_minutes between 0 and 120),
  add column early_visit_threshold_minutes integer not null default 15
    check (early_visit_threshold_minutes between 0 and 120);

grant update (late_visit_threshold_minutes, early_visit_threshold_minutes)
  on public.companies to authenticated;

create table public.care_visit_requirements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  service_user_id uuid not null,
  visit_type text not null default 'Care visit',
  weekday integer not null check (weekday between 0 and 6),
  starts_at time not null,
  duration_minutes integer not null check (duration_minutes between 5 and 1440),
  carers_required smallint not null default 1 check (carers_required between 1 and 2),
  effective_from date not null default current_date,
  effective_to date,
  instructions text,
  status text not null default 'active' check (status in ('active', 'paused', 'ended')),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, company_id),
  check (effective_to is null or effective_to >= effective_from),
  foreign key (service_user_id, company_id)
    references public.service_users(id, company_id)
);

alter table public.visits
  add column care_visit_requirement_id uuid,
  add column required_carers smallint not null default 1
    check (required_carers between 1 and 2),
  add foreign key (care_visit_requirement_id, company_id)
    references public.care_visit_requirements(id, company_id);

create unique index visits_requirement_occurrence_key
  on public.visits (care_visit_requirement_id, starts_at)
  where care_visit_requirement_id is not null;

create table public.visit_assignments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  visit_id uuid not null,
  employee_id uuid not null,
  assignment_slot smallint not null check (assignment_slot between 1 and 2),
  assigned_by uuid not null default auth.uid() references auth.users(id),
  assigned_at timestamptz not null default now(),
  unique (visit_id, employee_id),
  unique (visit_id, assignment_slot),
  foreign key (visit_id, company_id)
    references public.visits(id, company_id) on delete cascade,
  foreign key (employee_id, company_id)
    references public.employees(id, company_id)
);

insert into public.visit_assignments
  (company_id, visit_id, employee_id, assignment_slot, assigned_by)
select company_id, id, employee_id, 1, created_by
from public.visits
where employee_id is not null
on conflict do nothing;

alter table public.care_visit_requirements enable row level security;
alter table public.visit_assignments enable row level security;

create or replace function public.is_assigned_to_visit(
  target_visit_id uuid,
  target_company_id uuid
) returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.visit_assignments va
    join public.employees e
      on e.id = va.employee_id and e.company_id = va.company_id
    where va.visit_id = target_visit_id
      and va.company_id = target_company_id
      and e.user_id = auth.uid()
  );
$$;

revoke all on function public.is_assigned_to_visit(uuid, uuid) from public;
grant execute on function public.is_assigned_to_visit(uuid, uuid) to authenticated;

drop policy if exists visits_select on public.visits;
create policy visits_select on public.visits for select using (
  public.is_active_member(company_id)
  and (
    (public.current_role_key(company_id) in ('company_admin','manager','coordinator')
      and public.has_company_capability(company_id,'visits.view'))
    or exists (
      select 1 from public.employees e
      where e.id = employee_id
        and e.company_id = visits.company_id
        and e.user_id = auth.uid()
    )
    or public.is_assigned_to_visit(id, company_id)
  )
);

drop policy if exists visits_update on public.visits;
create policy visits_update on public.visits for update using (
  public.is_active_member(company_id)
  and (
    public.has_company_capability(company_id,'visits.schedule')
    or (
      public.has_company_capability(company_id,'visits.complete')
      and (
        exists (
          select 1 from public.employees e
          where e.id = employee_id
            and e.company_id = visits.company_id
            and e.user_id = auth.uid()
        )
        or public.is_assigned_to_visit(id, company_id)
      )
    )
  )
) with check (public.is_active_member(company_id));

create policy care_visit_requirements_select
  on public.care_visit_requirements for select using (
    public.is_active_member(company_id)
    and public.has_company_capability(company_id, 'visits.view')
  );

create policy care_visit_requirements_write
  on public.care_visit_requirements for all using (
    public.is_active_member(company_id)
    and public.has_company_capability(company_id, 'visits.schedule')
  ) with check (
    public.is_active_member(company_id)
    and public.has_company_capability(company_id, 'visits.schedule')
  );

create policy visit_assignments_select
  on public.visit_assignments for select using (
    public.is_active_member(company_id)
    and (
      public.has_company_capability(company_id, 'visits.view')
      or exists (
        select 1 from public.employees e
        where e.id = employee_id
          and e.company_id = visit_assignments.company_id
          and e.user_id = auth.uid()
      )
    )
  );

create policy visit_assignments_write
  on public.visit_assignments for all using (
    public.is_active_member(company_id)
    and public.has_company_capability(company_id, 'visits.schedule')
  ) with check (
    public.is_active_member(company_id)
    and public.has_company_capability(company_id, 'visits.schedule')
  );

grant select, insert, update on public.care_visit_requirements to authenticated;
grant select, insert, update, delete on public.visit_assignments to authenticated;
grant update (care_visit_requirement_id, required_carers) on public.visits to authenticated;

create or replace function public.set_visit_assignment(
  target_visit_id uuid,
  target_slot smallint,
  target_employee_id uuid
) returns void
language plpgsql security definer
set search_path = public
as $$
declare
  target_company_id uuid;
  carers_needed smallint;
begin
  select company_id, required_carers
    into target_company_id, carers_needed
  from public.visits
  where id = target_visit_id;

  if target_company_id is null
    or not public.has_company_capability(target_company_id, 'visits.schedule') then
    raise exception 'Not authorised to allocate this visit';
  end if;

  if target_slot < 1 or target_slot > carers_needed then
    raise exception 'Assignment slot is not required for this visit';
  end if;

  if target_employee_id is not null and not exists (
    select 1 from public.employees
    where id = target_employee_id
      and company_id = target_company_id
      and status = 'active'
  ) then
    raise exception 'Employee is not an active member of this organisation';
  end if;

  delete from public.visit_assignments
  where visit_id = target_visit_id
    and company_id = target_company_id
    and assignment_slot = target_slot;

  if target_employee_id is not null then
    insert into public.visit_assignments (
      company_id, visit_id, employee_id, assignment_slot
    ) values (
      target_company_id, target_visit_id, target_employee_id, target_slot
    );
  end if;

  if target_slot = 1 then
    update public.visits
    set employee_id = target_employee_id,
        updated_at = now()
    where id = target_visit_id and company_id = target_company_id;
  end if;
end;
$$;

revoke all on function public.set_visit_assignment(uuid, smallint, uuid) from public;
grant execute on function public.set_visit_assignment(uuid, smallint, uuid) to authenticated;

create or replace function public.generate_service_user_visits(
  target_service_user_id uuid,
  range_start date,
  range_end date
) returns integer
language plpgsql security definer
set search_path = public
as $$
declare
  target_company_id uuid;
  company_timezone text;
  requirement record;
  visit_date date;
  visit_start timestamptz;
  inserted_count integer := 0;
begin
  if range_end < range_start or range_end > range_start + 90 then
    raise exception 'Visit generation range must be between 1 and 91 days';
  end if;

  select su.company_id, coalesce(c.timezone, 'Europe/London')
    into target_company_id, company_timezone
  from public.service_users su
  join public.companies c on c.id = su.company_id
  where su.id = target_service_user_id;

  if target_company_id is null
    or not public.has_company_capability(target_company_id, 'visits.schedule') then
    raise exception 'Not authorised to generate visits';
  end if;

  for requirement in
    select * from public.care_visit_requirements r
    where r.service_user_id = target_service_user_id
      and r.company_id = target_company_id
      and r.status = 'active'
      and r.effective_from <= range_end
      and (r.effective_to is null or r.effective_to >= range_start)
  loop
    for visit_date in
      select d::date
      from generate_series(range_start, range_end, interval '1 day') d
      where extract(dow from d)::integer = requirement.weekday
        and d::date >= requirement.effective_from
        and (requirement.effective_to is null or d::date <= requirement.effective_to)
    loop
      visit_start := (visit_date + requirement.starts_at) at time zone company_timezone;

      insert into public.visits (
        company_id, service_user_id, visit_type, starts_at, ends_at,
        status, recurrence_group_id, care_visit_requirement_id,
        required_carers, notes
      ) values (
        target_company_id, target_service_user_id, requirement.visit_type,
        visit_start, visit_start + make_interval(mins => requirement.duration_minutes),
        'scheduled', requirement.id, requirement.id,
        requirement.carers_required, requirement.instructions
      ) on conflict (care_visit_requirement_id, starts_at)
        where care_visit_requirement_id is not null do nothing;

      if found then inserted_count := inserted_count + 1; end if;
    end loop;
  end loop;

  return inserted_count;
end;
$$;

revoke all on function public.generate_service_user_visits(uuid, date, date) from public;
grant execute on function public.generate_service_user_visits(uuid, date, date) to authenticated;

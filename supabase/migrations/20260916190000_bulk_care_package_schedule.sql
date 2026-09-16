-- Create a multi-day, multi-visit care package in one atomic operation.

create or replace function public.create_service_user_visit_schedule(
  target_service_user_id uuid,
  selected_weekdays integer[],
  visit_slots jsonb,
  range_start date,
  range_end date
) returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  target_company_id uuid;
  selected_day integer;
  slot jsonb;
  slot_time time;
  slot_duration integer;
  slot_carers smallint;
  requirement_count integer := 0;
  visit_count integer := 0;
begin
  select company_id into target_company_id
  from public.service_users
  where id = target_service_user_id and status = 'active';

  if target_company_id is null
    or not public.has_company_capability(target_company_id, 'visits.schedule') then
    raise exception 'Not authorised to create this care schedule';
  end if;

  if selected_weekdays is null
    or cardinality(selected_weekdays) < 1
    or cardinality(selected_weekdays) > 7
    or exists (select 1 from unnest(selected_weekdays) d where d < 0 or d > 6) then
    raise exception 'Select between one and seven valid weekdays';
  end if;

  if visit_slots is null
    or jsonb_typeof(visit_slots) <> 'array'
    or jsonb_array_length(visit_slots) < 1
    or jsonb_array_length(visit_slots) > 12 then
    raise exception 'Add between one and twelve daily visit slots';
  end if;

  if range_end < range_start or range_end > range_start + 90 then
    raise exception 'Visit generation range must be between 1 and 91 days';
  end if;

  foreach selected_day in array selected_weekdays loop
    for slot in select value from jsonb_array_elements(visit_slots)
    loop
      if coalesce(trim(slot->>'visit_type'), '') = ''
        or coalesce(trim(slot->>'starts_at'), '') = '' then
        raise exception 'Every visit slot requires a visit type and start time';
      end if;

      slot_time := (slot->>'starts_at')::time;
      slot_duration := (slot->>'duration_minutes')::integer;
      slot_carers := (slot->>'carers_required')::smallint;

      if slot_duration < 5 or slot_duration > 1440 then
        raise exception 'Visit duration must be between 5 and 1440 minutes';
      end if;
      if slot_carers < 1 or slot_carers > 2 then
        raise exception 'A visit must require one or two carers';
      end if;
      if exists (
        select 1 from public.care_visit_requirements r
        where r.company_id = target_company_id
          and r.service_user_id = target_service_user_id
          and r.weekday = selected_day
          and r.starts_at = slot_time
          and r.status = 'active'
      ) then
        raise exception 'An active visit already exists for day % at %', selected_day, slot_time;
      end if;

      insert into public.care_visit_requirements (
        company_id, service_user_id, visit_type, weekday, starts_at,
        duration_minutes, carers_required, effective_from, effective_to,
        instructions, status
      ) values (
        target_company_id,
        target_service_user_id,
        trim(slot->>'visit_type'),
        selected_day,
        slot_time,
        slot_duration,
        slot_carers,
        coalesce(nullif(slot->>'effective_from','')::date, range_start),
        nullif(slot->>'effective_to','')::date,
        nullif(trim(slot->>'instructions'),''),
        'active'
      );
      requirement_count := requirement_count + 1;
    end loop;
  end loop;

  visit_count := public.generate_service_user_visits(
    target_service_user_id,
    range_start,
    range_end
  );

  return jsonb_build_object(
    'requirements_created', requirement_count,
    'visits_created', visit_count
  );
end;
$$;

revoke all on function public.create_service_user_visit_schedule(
  uuid, integer[], jsonb, date, date
) from public;
grant execute on function public.create_service_user_visit_schedule(
  uuid, integer[], jsonb, date, date
) to authenticated;

-- Fix the first-company bootstrap workflow. Codes are made unique by the
-- database and an area can be created before any employees exist.

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
declare
  saved public.operational_areas;
  before_row jsonb;
  base_code text;
  candidate_code text;
  suffix integer := 1;
begin
  if not public.has_company_capability(target_company_id,'settings.manage') then
    raise exception 'Not authorised to manage operational areas';
  end if;
  if nullif(btrim(p_name),'') is null then raise exception 'Area name is required'; end if;
  if p_status not in ('active','inactive') then raise exception 'Invalid area status'; end if;
  if p_manager_id is not null and not exists(
    select 1 from public.employees where id=p_manager_id and company_id=target_company_id
  ) then raise exception 'Area manager does not belong to this organisation'; end if;

  base_code := upper(regexp_replace(coalesce(nullif(btrim(p_code),''),btrim(p_name)),'[^A-Za-z0-9]+','','g'));
  base_code := left(coalesce(nullif(base_code,''),'AREA'),16);
  candidate_code := base_code;
  while exists(
    select 1 from public.operational_areas
    where company_id=target_company_id and code=candidate_code
      and (target_area_id is null or id<>target_area_id)
  ) loop
    suffix := suffix + 1;
    candidate_code := left(base_code,16-length(suffix::text)) || suffix::text;
  end loop;

  if target_area_id is null then
    insert into public.operational_areas(company_id,name,code,office_name,address,contact_phone,contact_email,manager_id,status)
    values(target_company_id,btrim(p_name),candidate_code,nullif(btrim(p_office_name),''),nullif(btrim(p_address),''),nullif(btrim(p_contact_phone),''),nullif(lower(btrim(p_contact_email)),''),p_manager_id,p_status)
    returning * into saved;
    perform public.insert_audit_event(target_company_id,auth.uid(),'operational_area_created','operational_area',saved.id,null,to_jsonb(saved),null,null);
  else
    select to_jsonb(a) into before_row from public.operational_areas a
    where a.id=target_area_id and a.company_id=target_company_id for update;
    if before_row is null then raise exception 'Operational area not found'; end if;
    update public.operational_areas set
      name=btrim(p_name),code=candidate_code,office_name=nullif(btrim(p_office_name),''),
      address=nullif(btrim(p_address),''),contact_phone=nullif(btrim(p_contact_phone),''),
      contact_email=nullif(lower(btrim(p_contact_email)),''),manager_id=p_manager_id,status=p_status
    where id=target_area_id and company_id=target_company_id returning * into saved;
    perform public.insert_audit_event(target_company_id,auth.uid(),'operational_area_updated','operational_area',saved.id,before_row,to_jsonb(saved),null,null);
  end if;
  return saved;
end;
$$;

revoke all on function public.save_operational_area(uuid,uuid,text,text,text,text,text,text,uuid,text) from public,anon;
grant execute on function public.save_operational_area(uuid,uuid,text,text,text,text,text,text,uuid,text) to authenticated;

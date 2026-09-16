-- Applied to careflow (alsgbnbzzdsfixgsaiak) 2026-09-16.
-- See docs/architecture.md §11 for the design this implements.

create table public.audit_events (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid references public.companies(id),
  user_id        uuid references auth.users(id),
  action         text not null,
  entity_type    text not null,
  entity_id      uuid,
  before_data    jsonb,
  after_data     jsonb,
  correlation_id uuid,
  ip_address     inet,
  user_agent     text,
  reason         text,
  created_at     timestamptz not null default now()
);
revoke insert, update, delete on public.audit_events from public, anon, authenticated;
alter table public.audit_events enable row level security;

create policy audit_events_select on public.audit_events for select
using (
  public.is_platform_admin()
  or (company_id is not null and public.has_company_capability(company_id, 'audit.view'))
);
-- No insert/update/delete policies for any application role: audit_events
-- is written exclusively by insert_audit_event(), below, called from
-- other SECURITY DEFINER functions (which run as the function owner and
-- so are unaffected by the revoke above).

create or replace function public.insert_audit_event(
  p_company_id     uuid,
  p_user_id        uuid,
  p_action         text,
  p_entity_type    text,
  p_entity_id      uuid,
  p_before         jsonb default null,
  p_after          jsonb default null,
  p_reason         text default null,
  p_correlation_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.audit_events
    (company_id, user_id, action, entity_type, entity_id, before_data, after_data, reason, correlation_id)
  values
    (p_company_id, p_user_id, p_action, p_entity_type, p_entity_id, p_before, p_after, p_reason, p_correlation_id);
end;
$$;
-- Internal-only: never exposed to the browser directly, per
-- "never expose audit insertion directly to the browser."
revoke execute on function public.insert_audit_event(uuid,uuid,text,text,uuid,jsonb,jsonb,text,uuid) from public, anon, authenticated;

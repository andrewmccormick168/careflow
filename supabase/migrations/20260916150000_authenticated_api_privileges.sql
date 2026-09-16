-- Browser-role privileges for tables protected by Row Level Security.
-- RLS remains the authoritative row-level security boundary.

grant usage on schema public to authenticated;

grant select on table
  public.companies, public.profiles, public.roles, public.capabilities,
  public.role_capabilities, public.company_memberships, public.invitations,
  public.audit_events, public.employees, public.employee_sensitive,
  public.service_users, public.service_user_contacts,
  public.service_user_assignments, public.care_plans,
  public.care_plan_sections, public.risk_assessments,
  public.working_patterns, public.availability_exceptions, public.visits,
  public.visit_tasks, public.care_records, public.medications,
  public.medication_schedules, public.mar_entries, public.incidents,
  public.incident_actions, public.safeguarding_records, public.timesheets,
  public.expenses, public.mileage_claims, public.pay_rates,
  public.charge_rates, public.invoices, public.invoice_items,
  public.documents, public.notifications, public.export_jobs
to authenticated;

grant update (full_name, avatar_url, last_seen_at, updated_at)
on public.profiles to authenticated;

grant insert on public.companies to authenticated;
grant update (name, trading_name, registered_number, contact_email,
  contact_phone, address, logo_url, timezone, session_timeout_minutes,
  retention_years) on public.companies to authenticated;

do $$
declare v_table text; v_columns text;
begin
  foreach v_table in array array[
    'employees','employee_sensitive','service_users','service_user_contacts',
    'service_user_assignments','care_plans','care_plan_sections',
    'risk_assessments','working_patterns','availability_exceptions','visits',
    'visit_tasks','care_records','medications','incidents','incident_actions',
    'safeguarding_records','timesheets','expenses','mileage_claims',
    'pay_rates','charge_rates','invoices','invoice_items','documents','export_jobs'
  ] loop
    execute format('grant insert on table public.%I to authenticated',v_table);
    select string_agg(format('%I',column_name),', ' order by ordinal_position)
      into v_columns from information_schema.columns
      where table_schema='public' and table_name=v_table
        and is_generated='NEVER'
        and column_name <> all(array['id','company_id','created_at','created_by',
          'reported_by','administered_by','uploaded_by','requested_by']);
    if v_columns is not null then
      execute format('grant update (%s) on table public.%I to authenticated',v_columns,v_table);
    end if;
  end loop;
end;
$$;

grant update (user_id) on public.employees to authenticated;
grant insert on public.mar_entries to authenticated;
grant update (read_at) on public.notifications to authenticated;

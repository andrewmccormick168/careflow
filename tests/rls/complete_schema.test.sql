begin;
select plan(45);

select ok(c.relrowsecurity, c.relname || ' has RLS enabled')
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname = any(array[
 'companies','company_memberships','employees','employee_sensitive','service_users','service_user_contacts','service_user_assignments',
 'care_plans','care_plan_sections','risk_assessments','working_patterns','availability_exceptions','visits','visit_tasks','care_records',
 'medications','medication_schedules','mar_entries','incidents','incident_actions','safeguarding_records','timesheets','expenses','mileage_claims',
 'pay_rates','charge_rates','invoices','invoice_items','documents','notifications','export_jobs'
]);

select has_function('public','is_active_member',array['uuid'],'membership helper exists');
select has_function('public','has_company_capability',array['uuid','text'],'capability helper exists');
select has_function('public','can_access_service_user',array['uuid','uuid'],'assignment scope helper exists');
select has_function('public','is_platform_admin',array[]::text[],'platform helper exists');
select has_function('public','accept_invitation',array['text'],'invitation acceptance exists');
select has_function('public','get_dashboard_metrics',array['uuid'],'dashboard RPC exists');
select is((select prosecdef from pg_proc where oid='public.is_active_member(uuid)'::regprocedure),true,'membership helper is security definer');
select is((select prosecdef from pg_proc where oid='public.has_company_capability(uuid,text)'::regprocedure),true,'capability helper is security definer');
select is((select prosecdef from pg_proc where oid='public.accept_invitation(text)'::regprocedure),true,'invitation acceptance is security definer');
select ok(not has_table_privilege('authenticated','public.audit_events','INSERT'),'clients cannot insert audit events');
select ok(not has_table_privilege('authenticated','public.audit_events','UPDATE'),'clients cannot update audit events');
select ok(not has_table_privilege('authenticated','public.audit_events','DELETE'),'clients cannot delete audit events');
select ok(not has_table_privilege('authenticated','public.invitations','INSERT'),'clients cannot insert invitations directly');
select ok(not has_table_privilege('authenticated','public.invitations','UPDATE'),'clients cannot update invitations directly');

select * from finish();
rollback;

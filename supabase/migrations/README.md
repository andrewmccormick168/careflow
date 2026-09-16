# Migrations

The first seven migrations below were marked as applied to the original
CareFlow Supabase project and are mirrored here verbatim. The final two are
forward-only migrations supplied by this build and must be reviewed/applied:

1. `platform_admin_and_suspension` — `platform_administrators`, `user_account_status`, `is_platform_admin()`
2. `companies_roles_capabilities_memberships` — `companies`, `roles`, `capabilities`, `role_capabilities`, `company_memberships`, `is_active_member()`, `has_company_capability()`
3. `audit_events` — append-only `audit_events`, internal `insert_audit_event()`
4. `invitations` — `invitations`, `create_invitation()`, `accept_invitation()`
5. `employees_service_users_assignments` — `employees`, `employee_sensitive`, `service_users`, `service_user_contacts`, `service_user_assignments` (composite-FK tenant consistency, overlap exclusion constraint)
6. `fix_btree_gist_schema` — advisor-flagged fix, extension moved out of `public`
7. `membership_management_functions` — `deactivate_membership()`, `reactivate_membership()`, `change_membership_role()`, each blocking self-service changes to the caller's own membership
8. `profiles_and_security_hardening` — profiles/auth provisioning, suspension-safe assignment paths and service-user access helper
9. `complete_care_operations` — care plans, risks, rota, visits, eMAR, incidents, safeguarding, workforce, finance, documents, notifications, reports, audit and private storage policies

Always run `supabase db push --dry-run` against staging before applying the new
migrations to an existing project. A fresh project applies all files in order.

## Naming convention

`YYYYMMDDHHMMSS_short_description.sql`, one logical change per file, applied in timestamp order. Supabase CLI (`supabase migration new <description>`) generates the timestamp prefix automatically once the local toolchain is available.

## Review checklist for every migration

See `docs/db-conventions.md`. In short: `company_id` immutability, four explicit RLS policies per tenant table, composite FKs for cross-table tenant consistency, `SECURITY DEFINER` conventions for any new function, and a corresponding test file under `tests/rls/`.

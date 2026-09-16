# CareFlow — Database Conventions

Every migration is reviewed against this checklist before merge. This is the enforcement mechanism referenced by `docs/architecture.md` and `docs/threat-model.md`.

## Every tenant-owned table

- [ ] `company_id uuid not null references companies(id)`, indexed.
- [ ] `company_id` immutable after insert (trigger or revoked column-level UPDATE privilege — see below).
- [ ] Four explicit RLS policies documented in the migration's comment header: `SELECT USING`, `INSERT WITH CHECK`, `UPDATE USING` / `UPDATE WITH CHECK`, `DELETE` (or an explicit note that no delete policy exists).
- [ ] No `CHECK` constraint attempts cross-table authorisation.
- [ ] Any composite relationship to another tenant table uses a composite FK (`(id, company_id)`) or a documented constraint trigger — never a bare `id` FK alone.

## Immutable security-column enforcement

RLS policies do not expose `OLD`; do not attempt `company_id = (select company_id from t where t.id = t.id)` inside a `WITH CHECK` — this is unreliable and can cause recursive policy evaluation. Use instead:

```sql
create or replace function forbid_protected_column_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if NEW.company_id is distinct from OLD.company_id then
    raise exception 'company_id is immutable';
  end if;
  return NEW;
end;
$$;

create trigger t_protect_company_id
  before update on t
  for each row execute function forbid_protected_column_change();
```

Or revoke `UPDATE` on the specific column from the roles that would otherwise have it:

```sql
revoke update (company_id) on t from authenticated;
```

## Every SECURITY DEFINER function

- [ ] `set search_path = pg_catalog, public` (or equivalently fixed, minimal).
- [ ] All object references schema-qualified.
- [ ] Checks `user_account_status` (not globally suspended) first.
- [ ] Validates `auth.uid()` is present.
- [ ] Re-checks active membership/capability itself — never trusts caller context alone.
- [ ] Any caller-supplied user/company ID is validated against the caller's own `auth.uid()`-derived membership, never trusted directly. `is_platform_admin()` in particular takes **no** user-ID parameter.
- [ ] `revoke execute on function ... from public;` then explicit `grant execute ... to authenticated;` (or narrower).
- [ ] Owned by a minimum-privilege role, not an unnecessarily powerful one.
- [ ] Has a dedicated negative-test file under `tests/rls/`.

## Helper-function test matrix (required for `is_active_member`, `has_company_capability`, `is_platform_admin`)

Anonymous caller · active member · deactivated membership · globally suspended user · suspended company · wrong company · revoked platform administrator · caller belonging to multiple companies · forged company/user ID parameter · confirm no recursive RLS evaluation against `company_memberships` / `user_account_status` / `platform_administrators`.

## Invitation token handling

- Raw token: POST body only, never a URL/query string.
- Redacted from application logs, audit JSON, and error-monitoring payloads.
- Only the hash is persisted.
- Invitation tokens currently use a 256-bit random value with a SHA-256 digest
  stored in Postgres. No pepper is used, avoiding an undocumented rotation
  dependency. If one is introduced, store it as an Edge Function secret and
  version it so rotation does not invalidate pending invitations.

## Audit JSON

Built from an explicit per-table column allow-list — never a blind `row_to_json(NEW)`. Never includes secrets, raw invitation tokens, or more medical/safeguarding detail than the specific audited action requires. IP address and user agent are nullable, best-effort fields populated only when a genuine server boundary (Edge Function) captured them — never treated as authoritative from a direct browser-to-Postgres call.

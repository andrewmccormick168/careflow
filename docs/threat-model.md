# CareFlow — Threat Model

Scope: foundation/auth/tenancy layer only. Revisited each phase as new data domains are added.

## Trust boundaries

1. Browser (untrusted) ↔ Supabase Postgres via RLS-governed PostgREST/RPC calls.
2. Browser (untrusted) ↔ Edge Functions (server-side, but still receiving untrusted input).
3. Edge Functions ↔ Postgres, either as the calling user (preferred, preserves `auth.uid()`) or, rarely, with the service-role key (must independently authenticate/authorise first).
4. Postgres internal: `SECURITY DEFINER` functions crossing from a caller's restricted context into elevated access against a small, named set of tables.

## Risks and controls

| Risk | Control |
|---|---|
| Client sends/forges `company_id` on insert or tries to move a row between companies it has access to | `company_id` immutable after insert (trigger or revoked column privilege); `WITH CHECK` validates on write; no UPDATE path can change it |
| Deactivated or globally suspended user retains access | `is_active_member`/`has_company_capability`/`is_platform_admin` all check `user_account_status` and `company_memberships.status` live, every call — no cached permission token |
| Sensitive fields exposed via broad `select *` | Sensitive domains isolated into separate tables with their own RLS, built only when their full schema/RLS/retention is ready — never a broad table with hidden-in-UI columns |
| Audit tampering | No UPDATE/DELETE grants on `audit_events`; inserts only via `SECURITY DEFINER` triggers/functions; service-role key never reaches the browser |
| Self-escalation (role, membership, platform admin) | Users cannot write their own `company_memberships` or `platform_administrators` rows; all changes go through capability-gated or platform-admin-gated functions |
| Leaked service-role key | Server-side Edge Function env only; never `VITE_`-prefixed; never logged |
| Cross-tenant leakage via joins | Every join target has its own `company_id` + RLS; composite FKs additionally guarantee referenced rows share the same company |
| Invitation token replay/guessing/leak via logs | High-entropy token, stored only as a hash, POST-body only, redacted from logs/audit/error-monitoring, single-purpose validation inside one atomic function |
| Edge Function silently losing caller identity | Documented requirement: Edge Function must use the caller's JWT (Authorization header) when calling `accept_invitation`, not an unrestricted service-role context |
| Platform admin becoming a general bypass | No blanket "admin bypasses RLS" rule; only narrow, named, audited, reason-capable functions for specific support operations |
| Recursive RLS evaluation in helper functions | Helpers are `SECURITY DEFINER`, scoped to only the narrow tables they need (`company_memberships`, `user_account_status`, `platform_administrators`), not general RLS-disabling |
| Signed URL treated as more secure than it is | Documented explicitly as short-lived, one-object-scoped, freshly authorised, logged — **not** guaranteed single-use |
| IP/user-agent trusted as authoritative from direct client calls | Documented as best-effort/nullable unless captured at a genuine server boundary |

## SECURITY DEFINER function conventions

Every such function: fixed `search_path`, schema-qualified references, validates `auth.uid()` (and suspension status) first, re-checks membership/capability itself rather than trusting the caller's context, treats caller-supplied IDs as untrusted input to be validated, `REVOKE EXECUTE FROM PUBLIC` + explicit `GRANT`, minimum-privilege ownership, and a dedicated negative-test suite (see architecture.md §15).

## Open items requiring specialist review before production

- Formal penetration test (scheduled Phase 7).
- Legal/DPO review of retention periods and subject-access-request tooling (Phase 7).
- Care-sector regulatory review (Care Inspectorate / equivalent) of recordkeeping evidence — CareFlow provides the controls; a care professional or regulator confirms sufficiency. Not claimed as compliant by this document.

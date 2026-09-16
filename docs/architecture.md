# CareFlow — Architecture

Status: full operational baseline. This document is the authoritative security
architecture; the forward migrations implement the people, care, scheduling,
medication, compliance, workforce, finance and reporting modules.

## 1. System shape

- **Frontend**: React + TypeScript + Vite, deployed as a static bundle (Cloudflare Pages). No privileged logic in the browser.
- **Backend**: Supabase Postgres (RLS as the real security boundary), Supabase Auth, Supabase Storage (private buckets only), Supabase Edge Functions (thin, for operations that genuinely need a server boundary).
- **Identity**: `auth.users` → `profiles` (1:1) → `company_memberships` (N:M user↔company, carries `role_id`) → `role_capabilities`. `employees.user_id` separately links an HR/employment record to an auth identity; it is never used for permission decisions.

## 2. Platform administration

`platform_administrators` is fully independent of company membership.

```sql
create table platform_administrators (
  user_id     uuid primary key references auth.users(id),
  status      text not null default 'active' check (status in ('active','revoked')),
  granted_by  uuid not null references auth.users(id),
  granted_at  timestamptz not null default now(),
  revoked_at  timestamptz
);
```

- Written only via `SECURITY DEFINER` functions `grant_platform_admin` / `revoke_platform_admin`, callable only by an existing active, non-suspended platform administrator.
- `is_platform_admin() returns boolean` takes **no parameter** and derives identity exclusively from `auth.uid()`. A parameterised variant that accepts an arbitrary user ID is never created for general use; if support staff genuinely need to inspect another user's platform status, that is a separate, explicitly named, separately authorised function (e.g. `admin_lookup_platform_status(target_user_id uuid)`), itself gated by `is_platform_admin()` and audited — not a default-argument convenience on the primary check.
- Platform admin does **not** create a blanket "bypass every RLS policy" rule. Cross-tenant support access is implemented as narrow, purpose-specific `SECURITY DEFINER` functions (e.g. `admin_view_company_settings(target_company_id uuid, reason text)`), each requiring an active platform admin, each audited, each optionally requiring a reason, and each never returning more than the specific data the function is designed to expose. There is no general-purpose "admin query" escape hatch.
- The first platform administrator is bootstrapped out-of-band — see `docs/bootstrap-platform-admin.md`.

## 3. Global suspension (Phase 1, not deferred)

Global account suspension is part of the authentication/authorisation boundary and is built in Phase 1.

```sql
create table user_account_status (
  user_id      uuid primary key references auth.users(id),
  status       text not null default 'active' check (status in ('active','suspended')),
  reason       text,
  set_by       uuid references auth.users(id),
  set_at       timestamptz not null default now()
);
```

- `is_active_member(company_id)`, `has_company_capability(company_id, capability_key)`, and `is_platform_admin()` **all** check `user_account_status` first and fail immediately if the caller is suspended — a suspended user is denied everywhere, in every tenant, and even platform-admin status is inert while suspended.
- Only a `SECURITY DEFINER` function restricted to platform administrators can write to this table; no ordinary user or company admin can suspend/unsuspend anyone, including themselves.

## 4. Employee/user linking

```sql
employees.user_id uuid null references auth.users(id)
-- partial unique index
create unique index employees_company_user_unique on employees(company_id, user_id) where user_id is not null;
```

`employees.job_title`/`position` is HR data only. System access is derived exclusively from `company_memberships.role_id`. Changing a job title must never change what a user can do in the app — this is a dedicated negative test, not just a convention.

## 5. Active-company context

- Selected client-side for UX (auto-selected if the user has exactly one active membership; otherwise a picker), held only in memory.
- Never trusted as authorisation. Every RLS policy and every privileged function re-derives membership from `company_memberships` using `auth.uid()` and the row's own `company_id` (or an explicit `target_company_id` parameter that is itself re-validated).
- No function returns "all companies I belong to" merged business data; only the list of companies themselves, for the picker.
- Switching companies: re-validate membership server-side → `queryClient.clear()` → unsubscribe all realtime channels for the old company → reset top-level component state (e.g. remount via `key={activeCompanyId}`).
- TanStack Query keys are namespaced `['company', activeCompanyId, ...]` throughout.

## 6. Capability checking

```sql
has_company_capability(target_company_id uuid, capability_key text) returns boolean
```

Order of checks inside the function: caller not suspended (§3) → `auth.uid()` present → target company `status = 'active'` → active `company_memberships` row for `(auth.uid(), target_company_id)` → role has the capability via `role_capabilities`. A role held in one company can never authorise an action in another, because step 4 fails for the wrong company.

## 7. RLS pattern, and immutable-column enforcement (corrected)

RLS `USING` authorises which existing rows are visible/targetable; RLS `WITH CHECK` authorises the shape of the resulting row. **Postgres RLS policies do not expose `OLD`**, and a policy must not query the same protected table to "look up the old row" — that is unreliable and can cause recursive policy evaluation. Comparing old vs. new values for immutable security columns is instead done by one of:

- A `BEFORE UPDATE` trigger that compares `OLD.company_id`, `OLD.user_id`, assignment ownership, etc. against `NEW.*` and raises if a protected column changed outside an authorised path.
- Revoking column-level `UPDATE` privilege on the protected column from ordinary roles entirely, so it can only ever be set at `INSERT` time.
- A narrow transactional function for the rare legitimate reassignment case (e.g. moving an assignment from one employee to another **within the same company**), which performs its own explicit checks rather than relying on a generic `UPDATE`.

Default rule: **`company_id` is immutable after insert** on every tenant table. A user who is a valid member of both Company A and Company B must not be able to move a record between them just because they hold valid permissions in both — this is enforced structurally (trigger/no column privilege), not by hoping RLS catches it.

Each table's policy set is documented individually with four explicit entries — `SELECT USING`, `INSERT WITH CHECK`, `UPDATE USING` / `UPDATE WITH CHECK`, and `DELETE` (or an explicit statement that no delete policy exists, meaning delete is prohibited by default). `CHECK` constraints are never used for cross-table authorisation.

## 8. Cross-table tenant consistency

Composite foreign keys tie dependent rows to the exact same `company_id` as what they reference:

```sql
alter table employees add constraint employees_id_company_unique unique (id, company_id);
alter table service_users add constraint service_users_id_company_unique unique (id, company_id);

alter table service_user_assignments
  add constraint sua_employee_company_fk foreign key (employee_id, company_id) references employees(id, company_id),
  add constraint sua_service_user_company_fk foreign key (service_user_id, company_id) references service_users(id, company_id);
```

Where a composite FK can't express the relationship (e.g. a polymorphic document owner), a `BEFORE INSERT OR UPDATE` constraint trigger validates the referenced row's `company_id` matches.

## 9. Invitations

Single `SECURITY DEFINER` transactional function `accept_invitation(token text)` performs, atomically: caller authenticated and email-verified → normalised email match → token hash match (raw token never stored/logged) → invitation pending, not expired, not revoked/accepted → target company active → role exactly matches the invitation → no existing active membership already → insert membership, mark invitation accepted, insert audit row. All-or-nothing.

**Edge Function auth context (corrected):** the invitation-acceptance Edge Function must preserve the caller's identity. It constructs its Supabase client using the caller's `Authorization` header (the user's own JWT) so that `auth.uid()` inside `accept_invitation` correctly identifies them — it does **not** call the database using an unrestricted service-role context and assume `auth.uid()` will still resolve. If a server-side JWT verification step is used instead, the verified user ID is passed explicitly into a function designed to accept and re-validate it in that server context, never taken on trust.

The raw token travels only in a POST body, never a URL or query string, and is redacted from application logs, audit JSON, and error-monitoring payloads. Only its cryptographic hash is stored. If a pepper is used, its storage location and rotation procedure (which must not invalidate already-issued, still-valid invitations) is documented in `docs/db-conventions.md` before Phase 1 sign-off.

## 10. Status modelling

Kept strictly separate: global suspension (`user_account_status`), company membership activation (`company_memberships.status`), employment status/leaving date (`employees.status`), company active/suspended (`companies.status`), invitation lifecycle (`invitations.status`), service-user lifecycle (`service_users.status`). None of these are merged into a shared generic enum.

A suspended company denies normal member access entirely. Limited, purpose-specific, fully audited platform-support functions may still operate against a suspended company's data for legitimate investigation/administration — never as a general bypass, always through named functions requiring an active platform admin and, where appropriate, a stated reason.

## 11. Audit

Authoritative fields (actor, company, action, entity type/id, timestamp, before/after) are derived inside the trigger/transactional function performing the write, from the same transaction — never taken from client input. Client-supplied reason/notes are stored as explicitly-labelled untrusted supplementary text.

**IP address and user agent (corrected):** these are captured on a best-effort basis only where a trusted server boundary (an Edge Function that reads its own request context) is involved, and are never treated as authoritative when a browser talks to Supabase directly — direct client-to-Postgres calls have no trustworthy IP/user-agent source, so those fields are nullable and documented as best-effort, not guaranteed.

`audit_events` is insert-only for all application roles; `SECURITY DEFINER` triggers/functions are the only writers. Reading audit history requires its own `audit.view` capability, distinct from any capability that causes an audited action. Audit JSON is built from an explicit column allow-list per audited table — never secrets, raw tokens, or unnecessary medical detail.

## 12. Service-role usage

Priority: RLS first, restricted transactional functions second, triggers for audit, Edge Functions last (and only for things Postgres genuinely can't do — e.g. sending an email, issuing a signed Storage URL). Any Edge Function using the service-role key independently authenticates and authorises the caller/operation before any service-role query executes. The key lives only in server-side Edge Function environment variables, never in a `VITE_`-prefixed variable, never bundled or logged.

## 13. Private documents / signed URLs (corrected wording)

Signed URLs are: one-object scoped, short-lived, issued only after a fresh server-side authorisation check (membership → capability → assignment where applicable → record/company ownership → document status), and logged when issued. They are **not** assumed to be single-use — Supabase signed URLs are time-limited bearer URLs, not guaranteed single-redemption tokens, unless a separate redemption-tracking mechanism is added later. They are never written to persistent frontend storage or exposed in logs.

## 14. Roles (final)

Fixed global catalogue for Phase 1, `unique(key)`, no speculative `company_scope` column:

```sql
create table roles (
  id    uuid primary key default gen_random_uuid(),
  key   text not null unique,
  label text not null
);
-- seeded rows: company_admin, manager, coordinator, carer, finance
```

Custom per-company roles are an explicitly separate, later design — the seeded system roles are never edited in place by application code.

## 15. Testing requirements for helper functions

Each RLS helper (`is_active_member`, `has_company_capability`, `is_platform_admin`) requires dedicated tests for: anonymous caller, active member, deactivated membership, globally suspended user, suspended company, wrong company, revoked platform administrator, a caller belonging to multiple companies, and a forged company/user ID parameter. Migrations must also demonstrate the helpers do not cause recursive RLS evaluation when querying `company_memberships`, `user_account_status`, or `platform_administrators` (achieved by marking helpers `SECURITY DEFINER` so they run with elevated, RLS-bypassing rights against exactly the narrow tables they need — never by disabling RLS on those tables generally).

## 16. Production assurance and external integrations

- The complete module schemas now exist with RLS and metadata-only audit.
- MFA and session-timeout fields are reserved; enforcement must be validated
  against the selected Supabase Auth plan before real-data production use.
- Custom per-company roles — later, separate design.
- Email/SMS delivery, payment collection and accounting exports require an
  approved external provider and server-side secrets.
- Signed-URL single-use redemption tracking remains optional future hardening.

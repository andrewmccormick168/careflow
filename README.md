# CareFlow

Secure, multi-tenant care-management platform for UK domiciliary care providers.

**Status: functional operational MVP; production assurance remains required.**
The repository includes connected create/view/update workflows across people,
care planning, risks, rota, visits, eMAR, incidents, safeguarding, workforce,
finance, reports, documents, notifications and audit. Service-user care packages
support recurring visits, duration and one/two-carer requirements; the rota
provides a drag-and-drop half-hour employee timeline plus a service-user
delivery table; recurring schedules support several daily visits across selected days
in one save; inspection reporting uses explicit
timestamp-based definitions and drill-down evidence. Do not use real care data
until the RLS role matrix, backup/restore, accessibility and clinical workflows
have been independently acceptance-tested in the target deployment.

## Run it

```bash
npm ci
cp .env.example .env.local
npm run dev
```

Without Supabase environment values, CareFlow opens in interactive demo mode.
With `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`, it uses Supabase Auth and
live tenant-scoped data. See `docs/DEPLOYMENT.md` for the full GitHub, Supabase
and Cloudflare Pages process.

## Repository layout

```
apps/web/            React + TypeScript + Vite frontend
supabase/migrations/  Ordered, reproducible SQL migrations
supabase/functions/   Edge Functions (thin; see docs/architecture.md §12)
supabase/seed/        Fictional test fixtures only — never real data
packages/shared-types/ Shared TypeScript types / generated Supabase types
tests/rls/            SQL/pgTAP-style RLS and helper-function tests
tests/integration/    JS integration tests
docs/                 Architecture, threat model, db conventions, roadmap
```

## Core security rules (see docs/ for full detail)

- Supabase Row Level Security is the real tenant boundary — never a frontend filter.
- `company_id` is immutable after insert on every tenant table.
- Sensitive domains (medical, medication, safeguarding, payroll) live in separate, strictly-scoped tables, built only when their full schema/RLS/retention design is ready.
- Platform administration is independent of company membership and never a blanket RLS bypass.
- The Supabase service-role key never reaches the browser.
- Audit history is append-only and derived server-side, never from client input.

## Quality checks

```bash
npm run typecheck
npm run lint
npm test
npm run build
```

Database tests run with the Supabase CLI against a disposable local stack. The
GitHub Actions workflow runs both application and database-security jobs.

## Documentation

- `docs/architecture.md` — corrected, approved architecture.
- `docs/threat-model.md` — risks and controls.
- `docs/db-conventions.md` — migration review checklist.
- `docs/bootstrap-platform-admin.md` — one-time manual bootstrap runbook.
- `docs/roadmap.md` — phase-by-phase delivery plan and explicitly deferred items.
- `docs/DEPLOYMENT.md` — exact GitHub, Supabase and frontend deployment steps.

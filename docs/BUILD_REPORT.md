# CareFlow build report

Build date: 16 September 2026

## Connected workflows delivered

- React 18 + TypeScript + Vite responsive web application
- Supabase Auth session handling, invitation-only access and password reset
- Multi-company selection with tenant-keyed cache clearing
- Fixed roles and capability-driven navigation
- Interactive demo mode when deployment variables are absent
- Companies, profiles, memberships, invitations and global suspension
- Employees, PVG/DBS checks, working patterns, availability and pay rates
- Service users, contacts, employee assignments and private documents
- Versioned care plans, editable sections and risk assessments
- Recurring care-package visit requirements with day, time, duration and one/two-carer staffing
- Bulk care-package builder for multiple daily visits across daily, weekday,
  weekend or custom-day patterns in a single atomic save
- Six-week visit generation and atomic primary/second-carer allocation
- Daily dispatch workspace with separate employee-run and service-user delivery
  tables, staffing gaps, planned hours and overlap warnings
- Drag-and-drop half-hour dispatch timeline with sticky employee lanes,
  unassigned work, duration-sized visit blocks and empty-slot creation
- Weekly planning board with delivery-status colours
- Visit drill-down with allocations, actual times, tasks and completed care records
- Medication profiles, schedules, due-today calculation and MAR outcomes
- Incident workflow/actions and restricted safeguarding records
- Timesheets, expenses, mileage and payroll CSV
- Charge rates, invoices, line items and database-derived invoice totals
- Live database-derived dashboard metrics, notifications, reports and exports
- Inspector performance dashboard with explicit, configurable visit tolerances,
  exception evidence, delivery hours, incidents, safeguarding and CSV export
- Append-only audit events and dashboard metrics RPC
- Responsive desktop/mobile UI for every operational module
- Supabase Edge Function for identity-preserving invitation acceptance
- GitHub Actions, Vitest and pgTAP structural security tests
- GitHub/Supabase/Cloudflare deployment guide

## Verification completed in this build environment

- `npm run typecheck` — passed
- `npm run lint` — passed with zero warnings
- `npm test` — 6/6 passed
- `npm run build` — passed; production output chunked successfully
- Static secret scan — no service-role key used by browser code

## Verification still required against the linked Supabase project

This build environment is not logged into the user's Supabase account. Apply the
new forward migration (`20260916190000`) in the linked
CareFlow Codespace, run database lint, then perform the documented live workflow
test with fictional data. Source compilation proves type/build integrity; it
does not by itself prove every remote RLS role combination.

Do not place real care data into the system until live workflow/RLS tests are
green and the production assurance steps in `docs/DEPLOYMENT.md` are complete.

## Intentionally environment-dependent

- Automatic email/SMS delivery requires a selected provider and server secret.
- Online payment collection/accounting sync requires a selected provider.
- MFA policy enforcement depends on the chosen Supabase Auth plan/configuration.
- Formal UK GDPR/Care Inspectorate assurance requires organisational DPIA,
  retention, training, access reviews and independent security testing.

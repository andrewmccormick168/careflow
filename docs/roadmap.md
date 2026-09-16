# CareFlow — Roadmap

## Delivery status — full operational baseline complete

The repository now contains the database and application baseline for Phases
1–7. The remaining work is production onboarding, organisation-specific
configuration, third-party provider selection and formal assurance.

## Phase 0 — architecture and foundation (complete)
Repo structure, docs, conventions, empty migrations/tests/CI plumbing, design system, login/invitation screen designs (UI shell only, no live data). No business tables created.

## Phase 1 — secure company and people foundation (complete)
Auth, `companies`, `profiles`, `company_memberships`, fixed `roles` catalogue, `capabilities`, `role_capabilities`, `invitations` (+ transactional acceptance), `platform_administrators`, `user_account_status` (global suspension — moved into Phase 1 per approved corrections), `employees` (+ `employee_sensitive`, built with full schema/RLS at this point, not a placeholder), `service_users`, `service_user_contacts`, `service_user_assignments`, initial `audit_events`, company settings, capability-driven navigation. Full RLS + helper-function test matrix per table.

## Phase 2 — care planning and risks (complete baseline)
Care-plan templates, versioned care-plan records/sections, review/approval workflow, risk assessments, review reminders, associated documents. Full RLS/audit.

## Phase 3 — scheduling and visits (complete baseline)
Availability, working patterns, rotas, visit scheduling (recurring + one-off), carer allocations, carer mobile dashboard, arrival/departure, visit tasks, care records, missed/late escalation, correction history. Full RLS/audit.

## Phase 4 — medication (complete baseline)
Medication profiles, schedules, MAR, exceptions/escalation, manager review, reporting. Full RLS + detailed audit.

## Phase 5 — incidents and safeguarding (complete baseline)
Incident workflow, accident records, safeguarding records (restricted access, escalation, controlled workflow), investigation/actions, notifications, reporting. Full RLS + access auditing.

## Phase 6 — workforce and finance (complete baseline)
Timesheets, mileage, expenses, approval, payroll preparation/export, charge rates, pay rates (restricted), invoices, credit notes, payment tracking. Full RLS/audit.

## Phase 7 — reports, exports and operational readiness (application baseline)
Management dashboards, operational reports, regulatory evidence exports, subject-access/export tooling, retention/archive workflows, **MFA enforcement**, **session-timeout enforcement**, backup/recovery docs, penetration-testing checklist, accessibility review, production-readiness checklist.

## Explicitly deferred items (not silently dropped)

- MFA enforcement and session-timeout enforcement — designed now (fields/flow reserved), enforced in Phase 7.
- Custom per-company roles beyond the fixed catalogue — separate future design.
- Signed-URL single-use redemption tracking — later, if required.
- Automatic invitation email/SMS delivery awaits the chosen provider; secure
  invitation creation and acceptance are included.
- Payment collection and accounting-provider synchronisation await provider
  selection; invoice and payment-status records are included.

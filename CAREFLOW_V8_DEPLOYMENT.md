# CareFlow v8 — operational management upgrade

## What this release adds

### Operational areas and offices

- Create multiple operational areas under one company.
- Store each area's office, manager and contact details.
- Assign service users and employees to their area.
- Filter the rota, care plans, finance and workforce reports by area.
- Database-level area access foundations using Supabase Row Level Security.
- Existing companies receive a `Main area`; existing staff and service users are assigned to it automatically.

### Finance and debtors

- Debtor ledger grouped by service user and payer.
- Private, local-authority, NHS, mixed and other funding types.
- Payer name, payer reference and payment terms.
- Total invoiced, received, outstanding and overdue figures.
- Invoice payment recording with method, date and reference.
- Automatic invoice status updates to issued, part-paid or paid.
- Overpayments are rejected by the database.

### Staff hours and payroll evidence

- Scheduled hours calculated from allocated visits.
- Delivered hours calculated from actual arrival and departure timestamps.
- Submitted timesheet hours shown separately.
- Per-employee variance between delivered care and timesheet hours.
- Area and period filters.
- Payroll evidence CSV export.

### Full care-plan workspace

- Near-full-screen care-plan editing.
- Twelve standard person-centred plan sections.
- Assessed needs/current situation.
- Desired personal outcomes.
- Exact staff support guidance.
- Section status and review date.
- Formal plan review history and next-review date.

### Larger editing dialogs

All editing dialogs now use most of the available browser window. The care-plan editor uses an almost complete full-screen workspace.

## Supabase migration

This release contains the operational-areas migration and its compliance-record follow-up:

`supabase/migrations/20260916200000_operational_areas_finance_workforce.sql`

`supabase/migrations/20260916210000_compliance_records_and_area_save.sql`

`supabase/migrations/20260917090000_fix_area_bootstrap_workflow.sql`

The second migration fixes Area saving through a validated audited database operation and adds the expanded service-user profile, controlled forms and concerns register.

From `/workspaces/careflow`, first confirm the correct linked project:

```bash
npx supabase@latest projects list
npx supabase@latest migration list --linked
```

The CareFlow project reference must be:

`alsgbnbzzdsfixgsaiak`

Preview the migration:

```bash
npx supabase@latest db push --linked --dry-run
```

The dry run should list any unapplied CareFlow migrations, including these two when neither has yet been deployed:

```text
20260916200000_operational_areas_finance_workforce.sql
20260916210000_compliance_records_and_area_save.sql
20260917090000_fix_area_bootstrap_workflow.sql
```

Then apply it:

```bash
npx supabase@latest db push --linked
```

Validate it:

```bash
npx supabase@latest migration list --linked
npx supabase@latest db lint --linked --level warning
```

## Application validation

```bash
npm ci
npm run typecheck
npm run lint
npm test
npm run build
```

Restart the development server and hard-refresh the browser.

## First configuration after deployment

1. Open **Settings → Areas & offices**. Every company already has a `Main area`; rename it or create additional areas. Area codes are generated and made unique automatically.
2. Add employees. During initial setup an employee can remain unassigned to an area.
3. Edit each employee and assign their operational area.
4. Return to **Settings → Areas & offices** and appoint each area manager after the employees exist.
5. Add or edit each service user and assign their area, funding type, payer and payer reference.
6. Open **Finance → Debtors** to review balances.
7. Open **Staff hours & payroll** to compare delivered care against timesheets.
8. Open **Care plans & risks** and complete each person's structured care plan.
9. Open **Forms & concerns**, configure the agency's controlled form templates and test the concern escalation workflow.

## Reporting rule

Delivered staff hours are only counted when a visit has both `actual_arrival_at` and `actual_departure_at`. This is intentional: scheduled duration is not reported as completed work.

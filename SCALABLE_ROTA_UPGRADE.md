# CareFlow scalable rota upgrade

This frontend-only upgrade replaces the duplicate service-user delivery table with one operational dispatch workspace.

## What changed

- Switch the daily timeline between **Employees** and **Service users**.
- Search by service user, employee or visit type.
- Filter by scheduled, in-progress, completed or exception visits.
- Show only visits with staffing gaps.
- Service-user mode shows all daily visits on a horizontal time grid, including allocated carers and status.
- The employee timeline retains drag-and-drop allocation and time changes.
- Visit cards still open the full visit details and care-record workflow.

No Supabase migration is included or required.

## Install over the current project

From `/workspaces/careflow`, extract the ZIP over the repository root, then run:

```bash
npm ci
npm run typecheck
npm run lint
npm test
npm run build
```

Restart the development server if it is running, then hard-refresh the browser.

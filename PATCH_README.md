# CareFlow timeline dispatch v5

Frontend-only overlay for `/workspaces/careflow` after bulk scheduling v4.
There is no new database migration.

## Included

- horizontal 05:00–23:00 dispatch timeline in half-hour increments;
- sticky employee column and one row per employee;
- unassigned / under-allocated lane;
- visit position based on start time and width based on duration;
- automatic extra lanes for overlapping visits;
- drag visits between employees and times;
- drag allocated visits back to the unassigned lane;
- double-click empty timeline space to create a visit at that time;
- status and staffing-gap colours;
- full visit/care-record details on click;
- service-user daily delivery table retained below the timeline;
- weekly planning board retained.

## Install and verify

```bash
cd /workspaces/careflow
unzip -o careflow-timeline-dispatch-v5.zip -d .
npm run typecheck
npm run lint
npm test
npm run build
```

All checks passed in the build environment, including 6/6 tests. Restart the
development server and hard-refresh the browser after installing.

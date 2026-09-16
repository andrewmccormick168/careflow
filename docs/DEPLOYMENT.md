# CareFlow deployment

This repository is ready for GitHub, Supabase and any static Vite host such as
Cloudflare Pages. Use a new Supabase project or a verified staging project first.

## 1. GitHub

```bash
git init
git add .
git commit -m "Initial CareFlow release"
git branch -M main
git remote add origin https://github.com/YOUR-ACCOUNT/YOUR-REPOSITORY.git
git push -u origin main
```

The included workflow runs lint, TypeScript, Vitest, the production build and a
disposable local Supabase migration/RLS job on every pull request.

## 2. Supabase

Install the Supabase CLI, sign in, then run from the repository root:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push --dry-run
supabase db push
supabase functions deploy accept-invitation --use-api
```

Review the dry run before applying anything to an existing project. The early
migrations in this repository were marked as applied to the original CareFlow
project. On a different project they are applied in timestamp order.

For the existing CareFlow project (`alsgbnbzzdsfixgsaiak`), migrations through
`20260916180000` have already been applied. A dry run of this build should
therefore list only `20260916190000_bulk_care_package_schedule.sql`.
Stop if it proposes replaying any earlier migration.

In Supabase Dashboard → Authentication → URL Configuration, set the production
site URL and permitted redirect URLs. Keep public sign-up disabled. Create the
first authenticated user, then follow `docs/bootstrap-platform-admin.md` to add
the first platform administrator and first company/membership.

Copy the Project URL and anon/publishable key. These are the only two values the
browser needs. Never expose the service-role key.

## 3. Frontend hosting

For Cloudflare Pages connect the GitHub repository and set:

- Build command: `npm run build`
- Build output directory: `apps/web/dist`
- Node version: `20`
- `VITE_SUPABASE_URL`: Supabase project URL
- `VITE_SUPABASE_ANON_KEY`: Supabase anon/publishable key

The included `_redirects` file makes hash/deep navigation return the app shell.

## 4. Verify before real care data

```bash
npm ci
npm run typecheck
npm run lint
npm test
npm run build
supabase db reset
supabase test db tests/rls/complete_schema.test.sql
```

Complete DPIA, retention decisions, access review, backup/restore rehearsal,
penetration testing, accessibility testing and staff training before production
use with personal or special-category data. Software alone does not establish
UK GDPR or Care Inspectorate compliance.

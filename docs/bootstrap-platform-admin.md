# Bootstrapping the first Platform Administrator

This is a one-time, manual, out-of-band procedure. It is **never** exposed as an application endpoint, and this file must never contain a real production user ID.

## Procedure

1. The person who owns the Supabase project creates their own normal Supabase Auth account through the app's ordinary sign-in flow first (so a real `auth.users` row exists for them).
2. That person retrieves their own `auth.users.id` via the Supabase Studio SQL editor (a trusted, project-owner-only surface — not the application).
3. Using the Supabase Studio SQL editor (again, project-owner-only, not the app), run:

   ```sql
   insert into platform_administrators (user_id, granted_by, status)
   values ('<the-owner-own-user-id>', '<the-owner-own-user-id>', 'active');

   insert into audit_events (company_id, user_id, action, entity_type, entity_id, after_data, reason)
   values (
     null,
     '<the-owner-own-user-id>',
     'platform_admin_bootstrap',
     'platform_administrators',
     '<the-owner-own-user-id>',
     jsonb_build_object('status', 'active'),
     'Manual one-time bootstrap of first platform administrator'
   );
   ```

4. This is the **only** place a `platform_administrators` row is ever created outside the `grant_platform_admin` function. It is recorded as a distinct `platform_admin_bootstrap` audit action so it is clearly distinguishable from every subsequent, function-mediated grant.
5. Every platform administrator added after this point is granted exclusively through `grant_platform_admin`, callable only by an existing active platform admin — never through this manual procedure again.

## Why this is not a repeatable/application-level process

- It requires direct Supabase Studio SQL access, which only the project owner/operator has — not something reachable from the deployed application or any API surface.
- No migration or seed file in source control contains a real user ID; this document is a runbook, not a script committed with actual data.
- The distinct `platform_admin_bootstrap` audit action makes any future, unexpected use of this path immediately visible in audit review.

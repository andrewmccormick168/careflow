# RLS tests

`complete_schema.test.sql` validates that every tenant table has RLS enabled,
that trusted helper functions exist with the correct security boundary, and
that audit/invitation tables cannot be written directly by browser roles.

Run it against a disposable local database after `supabase db reset`:

```bash
supabase test db tests/rls/complete_schema.test.sql
```

Never run destructive reset commands against a linked production project.

# Migration ledger pre-deployment checklist

Before applying or deploying a database change:

- [ ] Confirm the target Supabase project ref is `ghnrsysvrlgkjmdlwdmp` (OPENPLAYNEW).
- [ ] Review the SQL and confirm the change is safe to apply to the current schema.
- [ ] Check the remote migration list for the proposed migration name before applying; apply it only once.
- [ ] Use a short snake_case name without a timestamp when applying through the migration tool.
- [ ] Record the exact version and name returned by Supabase.
- [ ] Save the SQL as `supabase/migrations/<version>_<name>.sql`.
- [ ] Update `supabase/migration-ledger.json` from the remote migration list.
- [ ] Run the migration-ledger tests, domain tests, TypeScript check and production build.
- [ ] Verify the remote and local migration counts and version/name pairs match.
- [ ] Do not manually delete or rewrite rows in Supabase's internal migration-history table.

Known historical exception: `admin_fixture_management` appears twice in the remote ledger under versions `20261107224311` and `20261107224351`. Both local SQL files must remain byte-for-byte identical unless the remote history is formally repaired through a supported migration-repair procedure.

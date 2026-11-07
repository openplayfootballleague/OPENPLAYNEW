# Supabase migration ledger reconciliation

**Project:** OPENPLAYNEW (`ghnrsysvrlgkjmdlwdmp`)  
**Snapshot date:** 7 November 2026  
**Applied migrations:** 29

## Finding

The Supabase project had 29 applied migration records and the repository had the same number of SQL files, but the local filename prefixes did not match the versions recorded by Supabase. Three local timestamp prefixes were each reused by two different migrations.

That mismatch can make a future Supabase CLI migration push treat already-applied migrations as pending or order them incorrectly.

## Resolution in this change

- Renames all 29 existing SQL files to match the exact remote `version_name.sql` pairs.
- Preserves each remote migration name exactly as recorded. The first four historical names already contain their original local timestamp; those are retained as part of the name.
- Reuses the existing SQL blobs without changing migration contents.
- Adds `supabase/migration-ledger.json` as a dated snapshot of the 29 applied remote version/name pairs.
- Adds a Vitest guard that fails if local filenames drift from the snapshot or contain duplicate versions.

**No SQL was edited or reapplied, and no database changes were made by this reconciliation.**

## Future migration procedure

1. Apply the reviewed SQL migration to the intended Supabase project.
2. Pass a short snake_case migration name to the migration tool; do not include a timestamp in the name argument.
3. Record the version and name returned by Supabase.
4. Save the exact SQL as `supabase/migrations/<version>_<name>.sql`.
5. Add the returned version/name pair to `supabase/migration-ledger.json`.
6. Run the full test/build workflow and compare the snapshot with the remote migration list before deployment.

Do not manually edit Supabase's internal migration-history table. If the remote history changes, refresh the snapshot from the connected project and review the diff.

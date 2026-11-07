# Supabase migration ledger reconciliation

**Project:** OPENPLAYNEW (`ghnrsysvrlgkjmdlwdmp`)  
**Snapshot date:** 7 November 2026  
**Applied migration records:** 34

## Finding

The Supabase project has 34 applied migration records and the repository had 33 SQL files. Local filename prefixes did not match the remote versions, and seven local timestamp prefixes were reused by different migrations.

The `admin_fixture_management` SQL was applied twice during concurrent development and is recorded under versions `20261107224311` and `20261107224351`. Both records are preserved as separate local files with identical SQL content; the remote migration-history table is not manually edited.

## Resolution in this change

- Renames the existing SQL files to match the exact remote `version_name.sql` pairs.
- Represents both recorded `admin_fixture_management` versions with separate local files containing the same SQL blob.
- Preserves each remote migration name exactly as recorded. The first four historical names already contain their original local timestamp; those are retained as part of the name.
- Includes the recorded `admin_player_register_status_filter` migration under its exact remote version/name.
- Adds `supabase/migration-ledger.json` as a dated snapshot of the 34 applied remote version/name pairs.
- Adds Vitest guards that fail if local filenames drift from the snapshot, versions collide, or the two duplicate fixture migration files diverge.

**This repository reconciliation does not edit SQL or change the database.** It only makes the repository accurately represent the remote migration history.

## Future migration procedure

1. Apply the reviewed SQL migration to the intended Supabase project.
2. Pass a short snake_case migration name to the migration tool; do not include a timestamp in the name argument.
3. Record the version and name returned by Supabase.
4. Save the exact SQL as `supabase/migrations/<version>_<name>.sql`.
5. Add the returned version/name pair to `supabase/migration-ledger.json`.
6. Run the full test/build workflow and compare the snapshot with the remote migration list before deployment.

Do not manually edit Supabase's internal migration-history table. If the remote history changes, refresh the snapshot from the connected project and review the diff.

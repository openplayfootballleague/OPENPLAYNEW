# Supabase migration ledger reconciliation

**Project:** OPENPLAYNEW (`ghnrsysvrlgkjmdlwdmp`)  
**Snapshot date:** 7 November 2026  
**Applied migration records:** 32

## Finding

The Supabase project had 32 applied migration records, while the repository had 31 SQL files. Local filename prefixes did not match remote versions, and five local timestamp prefixes were reused by different migrations.

The fixture-management SQL was also present in the repository and its functions were already present in the database, but it was absent from the migration history. During concurrent development it was recorded twice under the same name, with versions `20261107224311` and `20261107224351`. The SQL uses idempotent function replacements and permission grants; both remote records are preserved rather than manually deleting migration history.

## Resolution in this change

- Renames the existing SQL files to match the exact remote `version_name.sql` pairs.
- Represents both recorded `admin_fixture_management` versions with separate local files containing the same SQL blob.
- Preserves each remote migration name exactly as recorded. The first four historical names already contain their original local timestamp; those are retained as part of the name.
- Adds `supabase/migration-ledger.json` as a dated snapshot of the 32 applied remote version/name pairs.
- Adds a Vitest guard that fails if local filenames drift from the snapshot or contain duplicate versions.

**This repository reconciliation does not edit SQL or change the database.** The two fixture-management history records were already created in Supabase; this change makes the repository accurately represent them.

## Future migration procedure

1. Apply the reviewed SQL migration to the intended Supabase project.
2. Pass a short snake_case migration name to the migration tool; do not include a timestamp in the name argument.
3. Record the version and name returned by Supabase.
4. Save the exact SQL as `supabase/migrations/<version>_<name>.sql`.
5. Add the returned version/name pair to `supabase/migration-ledger.json`.
6. Run the full test/build workflow and compare the snapshot with the remote migration list before deployment.

Do not manually edit Supabase's internal migration-history table. If the remote history changes, refresh the snapshot from the connected project and review the diff.

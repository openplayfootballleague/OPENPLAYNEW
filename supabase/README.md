# Supabase migration and policy notes

## Project and migration state

The dedicated **Open Play New** Supabase project is the only Supabase project intended for this application. Never run destructive reset commands against a hosted/linked project, and never use the older Open Play production project for this repository.

As of 8 November 2026, the connected Open Play New database reports 98 applied migration-ledger entries. The migration source manifest in `docs/supabase-migration-source-manifest-2026-11-08.md` maps all 98 applied versions to canonical source files and Git blob SHAs.

The repository contains two additional forward-only migrations that are not in the 98-entry applied ledger: `20261108014200_finance_balance_semantics.sql` (finance balance semantics) and `20261108030000_scope_rls_to_global_admins.sql` (separates global-admin RLS access from location-scoped `league_admin` access). Both must be reviewed and validated through isolated local replay and role-matrix tests before any decision is made about applying them to a hosted environment. Location administrators must use the location-scoped admin RPCs; direct table RLS access does not grant them global visibility.

## Local development and clean replay

The committed `supabase/config.toml` configures local development against PostgreSQL 17. From the repository root:

```sh
supabase start -x studio,edge-runtime,logflare,vector
supabase db reset --local --no-seed
supabase stop --no-backup
```

These commands start and reset only the local Docker-backed Supabase stack. The `--local` flag is intentional. Do not substitute `--linked`, `--remote`, or a hosted database URL for clean replay or routine tests.

CI runs the full migration replay on an isolated local database, then executes catalog-level security assertions. A successful replay proves the committed migration set can construct a fresh local schema; it does not by itself prove production equivalence, authenticated multi-user behaviour, backup recovery, or release readiness.

## Applying migrations

Hosted migration deployment is a separate, deliberate release operation. It requires a reviewed migration plan, confirmation of the exact target project, backup/rollback planning, and explicit release approval. Never use `supabase db reset --linked` against a hosted project.

## Important implementation constraints

- Profile contact and emergency-contact fields are private by default.
- User role grants cannot be written by ordinary authenticated clients.
- Team membership and captain approval changes are not direct client writes.
- Fixture result confirmation and payment state transitions are privileged operations.
- Stripe webhook handling must verify signatures and be idempotent.
- Team sheet validation must enforce the competition format: six-a-side is 6 starters + up to 3 substitutes; seven-a-side is 7 starters + up to 4 substitutes.
- Squad numbers remain optional.
- Fee changes are effective from a specific gameweek. Existing payment records retain their own `fee_snapshot`.
- Audit history is read-only to application clients.

## Security validation limits

The SQL assertions check database catalogue state, grants, RLS and selected function definitions. They are not a substitute for authenticated Data API tests using separate player, captain, location-admin and global-admin accounts. Those positive and negative role-matrix tests remain a release gate.

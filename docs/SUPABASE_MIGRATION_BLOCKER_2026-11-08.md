# Supabase migration blocker — corrected status

**Checked:** 8 November 2026  
**Repository:** `openplayfootballleague/OPENPLAYNEW`  
**Target project:** `OPENPLAYNEW` — `ghnrsysvrlgkjmdlwdmp`  
**Status:** migration deployment blocked; live database left unchanged.

## Correct interpretation

The earlier 62-file versus 98-record comparison used the repository's `main` branch and overstated the source gap. The advanced development branch is `feat/stripe-test-checkout-lifecycle`, with 94 SQL migration files. A cross-branch source inventory found 92 ledger records with candidate SQL files and six applied migration sources that could not be recovered from any inspected branch/path history.

The live database reports 98 applied version/name records. Two records have the same migration name (`admin_fixture_management`) but distinct applied versions and must remain distinct.

The 94-file branch is not a safe migration baseline:
- Only 2 files have a leading version prefix that exactly matches the corresponding live ledger version.
- 9 duplicate local version prefixes exist.
- 96 live ledger versions have no exact leading-prefix match.
- A normalized migration-name match is only a candidate mapping; it does not prove exact SQL content or execution order.

## Six missing original applied SQL sources

| Applied version | Applied name |
|---|---|
| `20261107230305` | `fixture_player_appearance_tracking` |
| `20261107231632` | `finance_options_for_finance_roles` |
| `20261107231646` | `finance_summary_team_balance_rollup` |
| `20261107232144` | `audit_log_explicit_deny_policy` |
| `20261107233311` | `fixture_goal_records_explicit_deny_policy` |
| `20261108011216` | `20261108190000_location_admin_assignments` |

The inspected branches and expected GitHub path history did not contain these exact source files. A live schema/catalog snapshot can show current effects but cannot reconstruct the complete original SQL, including grants, comments, indexes, intermediate definitions or objects later changed.

## Three unmatched local SQL files

The current advanced branch also contains these files without an exact matching migration name in the live ledger:

- `20261108014200_finance_balance_semantics.sql`
- `20261108014600_audit_log_deny_all_policy.sql`
- `20261108014800_fixture_goal_records_deny_all.sql`

The two policy files resemble deny-all policies visible in the live catalog. That is not proof that they are byte-for-byte originals. The finance file also needs an exact version/source mapping. Do not run these files just to force counts to match.

## Remediation sequence

1. Obtain the six original SQL files from an authoritative archive: the original migration author/workspace, CI artifacts, a deployment archive or backup. Preserve original bytes and record SHA-256 hashes.
2. Compare each recovered file with the applied version/name record and live catalog. Mark each source as exact original, later revision, reconstruction or unresolved. Never label a reconstruction as the original.
3. Establish an explicit version-to-file manifest for all 98 applied records. Resolve the two distinct `admin_fixture_management` entries without collapsing them.
4. Resolve the three unmatched local files by provenance and exact content review.
5. Correct migration filename prefixes only after the exact version/source mapping is proven. Keep SQL contents unchanged.
6. Add automated checks for exact version/name coverage, duplicate versions, duplicate names, source hashes and deterministic ordering.
7. Replay the complete baseline in a disposable Supabase project/branch and verify schema, functions, triggers, policies and grants.
8. Only then use the supported Supabase migration workflow to reconcile the dedicated project. Never manually edit Supabase's internal `schema_migrations` table, and never rerun historical SQL against the live database to make the ledger appear consistent.

## Safety state and dependent work

The checks performed for this report were read-only. No live schema, migration history, user data, roles, payment data, secrets or location activation was changed. The live application database is not reported as broken; the blocker is the ability to reproduce and safely deploy future schema changes.

Team Instagram schema work and initial team/squad registration migrations remain blocked from deployment until the baseline is verified. Do not bypass the blocker with ad-hoc SQL or weaker RLS policies.

Tracking: [Issue #19 — Recover and reconcile Supabase migration sources and version history](https://github.com/openplayfootballleague/OPENPLAYNEW/issues/19).

Related evidence: `docs/supabase-migration-source-recovery-2026-11-08.md` and `docs/supabase-migration-source-reconciliation-2026-11-08.md`.

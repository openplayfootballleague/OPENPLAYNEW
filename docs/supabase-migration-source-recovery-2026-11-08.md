# Supabase migration source recovery — 8 November 2026

Project: OPENPLAYNEW (`ghnrsysvrlgkjmdlwdmp`)  
Repository: `openplayfootballleague/OPENPLAYNEW`  
Baseline checked: `feat/stripe-test-checkout-lifecycle` at `3f57ac869531984bab977a2ec6f67639dc8e41e2`

## Current reconciliation

A fresh read of the live Supabase migration ledger returned **98 applied version/name records**.

The current development branch contains **94 SQL migration files**. Matching by the exact migration name (ignoring the local filename timestamp prefix) gives:

- **92 ledger records matched** to a repository source file.
- **6 ledger records have no matching source file** in the current branch or any of the other inspected repository branches.
- **3 repository files do not match a ledger migration name** and must not be silently treated as the missing originals.
- The two ledger records named `admin_fixture_management` are distinct applied versions and must remain represented separately.

The arithmetic is not a one-file-per-record mapping because the duplicate `admin_fixture_management` ledger entries share the same migration name but have two separate local source files.

## Six missing source files

| Applied version | Applied migration name |
|---|---|
| `20261107230305` | `fixture_player_appearance_tracking` |
| `20261107231632` | `finance_options_for_finance_roles` |
| `20261107231646` | `finance_summary_team_balance_rollup` |
| `20261107232144` | `audit_log_explicit_deny_policy` |
| `20261107233311` | `fixture_goal_records_explicit_deny_policy` |
| `20261108011216` | `20261108190000_location_admin_assignments` |

The exact source paths were checked across `main`, the migration-reconciliation branch, the player-appearance feature branch, the Bideford-location branch, the PWA-branding branch, the Bideford-policy restoration branch and the current Stripe checkout branch. GitHub path history for the expected source filenames did not return prior file revisions.

## Three unmatched repository files

These exist in the current development branch but have no exact matching name in the live migration ledger:

- `20261108014200_finance_balance_semantics.sql`
- `20261108014600_audit_log_deny_all_policy.sql`
- `20261108014800_fixture_goal_records_deny_all.sql`

The two policy files create the same policy names and deny-all predicates currently visible in the live catalog (`audit_log_no_direct_client_access` and `fixture_goal_records_no_direct_client_access`). This is evidence of semantic alignment, **not proof that they are byte-for-byte the original applied SQL**.

The finance balance file defines `get_finance_summary` and `get_finance_ledger` among other functions. The live catalog also contains `get_finance_options` and `get_finance_summary`, but the missing `finance_options_for_finance_roles` source is not recovered by merely observing the current function definition. The finance file must be mapped to the exact applied history before it can be considered reconciled.

## Catalog evidence recovered (read-only)

The live database catalog currently confirms:

- `get_finance_options()` exists and checks `auth.uid()` plus `has_finance_access()`.
- `get_finance_summary(uuid)` exists and checks `auth.uid()` plus `has_finance_access()`.
- `audit_log` has a deny-all policy named `audit_log_no_direct_client_access`.
- `fixture_goal_records` has a deny-all policy named `fixture_goal_records_no_direct_client_access`.
- `fixture_team_sheet_players` has two trigger entries named `fixture_team_sheet_players_appearance_default`, both invoking `set_fixture_team_sheet_player_appearance_default()`.
- `location_admin_assignments` exists with columns `id`, `user_id`, `location_id`, `assigned_by`, and `created_at`.
- `admin_search_location_admin_candidates(text)` exists and requires a global `admin` or `super_admin` role.

Catalog state is useful for reconstructing the *current effects* of missing migrations, but cannot establish the complete original SQL, including grants, comments, indexes, intermediate definitions or objects later changed/dropped.

## Historical source branch

The branch `chore/reconcile-supabase-migration-ledger-2026-11-07` contains 35 initial migration source files and a 35-entry ledger snapshot. Its documentation records the historical duplicate `admin_fixture_management` application. That snapshot is a useful recovery source for the first 35 records, but is stale relative to the current 98-record production ledger and must not replace a fresh ledger snapshot.

## Safe next steps

1. Recover the six missing SQL sources from an original developer workspace, CI artifact, backup or other authoritative source. Do not synthesize them and label them as original.
2. For each source, compare its full SQL and effects with the live catalog and later migrations. Record whether it is original, reconstructed, superseded or still unknown.
3. Resolve the three unmatched local filenames by proving their relationship to the exact applied version/name pairs. Preserve duplicate applied records.
4. Refresh `supabase/migration-ledger.json` from the live ledger and add tests for the exact 98 version/name pairs, duplicate records and source coverage.
5. Only after this reconciliation, create separate forward-only migrations for permission defects #9–#11 and test them against a disposable branch/database.

**Safety:** This recovery session used read-only Supabase catalog and migration-list queries. No production schema, migration history, user data, roles, payments or location activation was changed. Do not manually edit Supabase's internal migration-history table.

## Follow-up branch integration audit — 8 November 2026, 10:xx UTC

A later read-only check found that the 94-file baseline above is the Stripe checkout feature branch, not the current visual-refresh development branch. Current branch counts are:

| Ref | SQL migration files |
|---|---:|
| Production ledger | 98 applied records |
| `feat/stripe-test-checkout-lifecycle` | 94 |
| `main` | 62 |
| `feat/visual-system-refresh-2026-11-08` | 63 |

The visual-refresh branch has 63 migration SQL files (62 from its main ancestry plus the new team Instagram migration). It does not contain the 31 additional migration files present on the Stripe branch; the only migration file unique to the visual-refresh branch compared with the Stripe branch is `20261108015000_team_instagram_profile.sql`. This is a branch divergence/integration issue, not evidence that 31 production migrations are unapplied.

Related pull requests remain open and unmerged at this check:
- PR #2 migration-ledger reconciliation: `chore/reconcile-supabase-migration-ledger-2026-11-07`
- PR #6 Stripe test-mode checkout: `feat/stripe-test-checkout-lifecycle`
- PR #8 audit/migration/Stripe documentation: `docs/continuous-development-audit-2026-11-08`
- PR #13 visual refresh and current feature work: `feat/visual-system-refresh-2026-11-08`

PR #13 is based on `main`, not the Stripe feature branch. No pull request was merged and no production changes were made. Before any integration/merge, compare the full ancestry and migration file sets, preserve all reviewed forward migrations, and re-run CI on the final combined branch. Do not resolve the discrepancy by copying filenames alone or fabricating missing migration source.

The 98-row live ledger remains the authoritative applied-history inventory. The six missing originals and three unmatched files listed above remain unresolved; the 63-file visual-refresh count is an additional current-branch limitation.

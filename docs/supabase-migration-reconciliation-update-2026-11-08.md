# Supabase migration reconciliation update — 8 November 2026

## Scope

This update follows the recovery of the applied migration source files. It distinguishes source recovery from canonical version reconciliation and from validating a fresh database replay.

## Verified recovery

Seven SQL source files have been restored on `fix/recover-six-applied-migration-sources-2026-11-08`:

- `20261107224311_admin_fixture_management.sql`
- `20261107230305_fixture_player_appearance_tracking.sql`
- `20261107231632_finance_options_for_finance_roles.sql`
- `20261107231646_finance_summary_team_balance_rollup.sql`
- `20261107232144_audit_log_explicit_deny_policy.sql`
- `20261107233311_fixture_goal_records_explicit_deny_policy.sql`
- `20261108011216_20261108190000_location_admin_assignments.sql`

For each file, the complete contents were fetched back from GitHub and compared byte-for-byte with the corresponding live `supabase_migrations.schema_migrations.statements` array. All seven comparisons passed.

The existing `20261107233000_admin_fixture_management.sql` was also compared with the second distinct `admin_fixture_management` ledger record (`20261107224351`); it is an exact match. Both applied records are therefore represented by separate files.

## Three unmatched local files

These files exist in `feat/stripe-test-checkout-lifecycle` but do not have matching version/name records in the live migration ledger:

1. `20261108014200_finance_balance_semantics.sql`
2. `20261108014600_audit_log_deny_all_policy.sql`
3. `20261108014800_fixture_goal_records_deny_all.sql`

Findings:

- The two policy files define the same deny-all policies already recorded by applied migrations `20261107232144` and `20261107233311`. They are redundant policy-source candidates, not migrations to run again. Their presence in the branch should be reconciled without replaying duplicate `CREATE POLICY` statements.
- The finance file defines `get_finance_ledger`, `get_finance_summary` and `admin_create_finance_entry`. All three functions exist in the live database. The live function definitions reflect the balance semantics in this file, but the exact complete file is not present as a matching ledger statement. The earlier applied finance migrations (`20261107231600` and `20261107231622`) contain earlier definitions/versions. This is evidence of a later live function definition whose exact deployment/version source remains unmapped. Do not discard the file or treat its source mapping as proven.

## PR state

PR #21 restores the seven recovered files. It targets `feat/stripe-test-checkout-lifecycle`, not `main`, because that is the branch whose migration inventory was used for the source reconciliation. It remains separate from the main integration path pending canonical migration reconciliation and replay validation. GitHub currently reports it as mergeable; no CI workflow run was returned for its head commit at the time of this update.

## Outstanding blockers

1. Map all 98 applied version/name pairs to exact canonical source files, not merely similar filenames.
2. Resolve duplicate local version prefixes and the three unmatched local files without replaying duplicate SQL.
3. Reconcile the main, Stripe, visual-system and admin-workspace feature branches into a single reviewed integration sequence.
4. Run a full clean database replay in a disposable Supabase project/branch, including security/privilege assertions.
5. Run application tests, typecheck, production build and Cloudflare dry-run against the resulting integration branch.
6. Verify live Auth email delivery, player registration, captain/team workflows, fixture sheets/results, finance permissions, Stripe test-mode checkout/webhooks, PostHog consent gating, PWA install and mobile/iPad layouts.
7. Deploy only after the above checks pass and verify the deployed production app.

## Safety

No production schema, application data, roles, payments, secrets, location activation or migration ledger rows were changed during this reconciliation. No migration was rerun. Source restoration only changes Git history on the recovery branch.

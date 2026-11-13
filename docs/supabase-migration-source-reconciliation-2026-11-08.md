# Open Play — Supabase migration source reconciliation

**Date:** 8 November 2026
**Repository:** `openplayfootballleague/OPENPLAYNEW`
**Supabase project:** `ghnrsysvrlgkjmdlwdmp`

This is a source inventory, not an instruction to apply migrations. The Supabase ledger was read-only. Each row below is matched by normalized migration name against SQL filenames found in `main` and the named open PR branches. Exact SQL-content/hash equivalence and migration execution order still require verification.

Live ledger records: **97**. Distinct normalized migration names: **96**. Candidate SQL files across inspected refs: **228** (including repeated copies across refs).

| Live version | Live ledger name | Candidate local source | Status |
|---|---|---|---|
| `20261107214404` | `20261107220000_initial_platform_schema` | main: `20261107220000_initial_platform_schema.sql` | Name match only |
| `20261107214406` | `20261107221000_initial_rls_policies` | main: `20261107221000_initial_rls_policies.sql` | Name match only |
| `20261107214409` | `20261107222000_player_registration_workflows` | main: `20261107222000_player_registration_workflows.sql` | Name match only |
| `20261107214624` | `20261107223000_rpc_security_hardening` | main: `20261107223000_rpc_security_hardening.sql` | Name match only |
| `20261107215659` | `integrity_and_foreign_key_indexes` | PR #2: `20261107215659_integrity_and_foreign_key_indexes.sql`<br>main: `20261107224000_integrity_and_foreign_key_indexes.sql` | Name match only |
| `20261107215723` | `team_registration_and_membership_hardening` | PR #2: `20261107215723_team_registration_and_membership_hardening.sql`<br>main: `20261107225000_team_registration_and_membership_hardening.sql` | Name match only |
| `20261107215956` | `profile_avatar_storage` | PR #2: `20261107215956_profile_avatar_storage.sql`<br>main: `20261107226000_profile_avatar_storage.sql` | Name match only |
| `20261107220045` | `captain_dashboard_projection` | PR #2: `20261107220045_captain_dashboard_projection.sql`<br>main: `20261107227000_captain_dashboard_projection.sql` | Name match only |
| `20261107220139` | `admin_dashboard_projection` | PR #2: `20261107220139_admin_dashboard_projection.sql`<br>main: `20261107228000_admin_dashboard_projection.sql` | Name match only |
| `20261107220520` | `team_approval_consistency` | PR #2: `20261107220520_team_approval_consistency.sql`<br>main: `20261107229000_team_approval_consistency.sql` | Name match only |
| `20261107220548` | `admin_queue_consistency` | PR #2: `20261107220548_admin_queue_consistency.sql`<br>main: `20261107229100_admin_queue_consistency.sql` | Name match only |
| `20261107220639` | `captain_team_sheet_submission` | PR #2: `20261107220639_captain_team_sheet_submission.sql`<br>main: `20261107229200_captain_team_sheet_submission.sql` | Name match only |
| `20261107220725` | `team_sheet_membership_identifiers` | PR #2: `20261107220725_team_sheet_membership_identifiers.sql`<br>main: `20261107229300_team_sheet_membership_identifiers.sql` | Name match only |
| `20261107220739` | `captain_fixture_list` | PR #2: `20261107220739_captain_fixture_list.sql`<br>main: `20261107229400_captain_fixture_list.sql` | Name match only |
| `20261107220838` | `unique_active_squad_numbers` | PR #2: `20261107220838_unique_active_squad_numbers.sql`<br>main: `20261107229500_unique_active_squad_numbers.sql` | Name match only |
| `20261107221445` | `public_registration_scope` | PR #2: `20261107221445_public_registration_scope.sql`<br>main: `20261107230000_public_registration_scope.sql` | Name match only |
| `20261107221644` | `captain_availability_privacy` | PR #2: `20261107221644_captain_availability_privacy.sql`<br>main: `20261107231000_captain_availability_privacy.sql` | Name match only |
| `20261107221658` | `captain_availability_dashboard` | PR #2: `20261107221658_captain_availability_dashboard.sql`<br>main: `20261107232000_captain_availability_dashboard.sql` | Name match only |
| `20261107221843` | `captain_squad_number_management` | PR #2: `20261107221843_captain_squad_number_management.sql`<br>main: `20261107233000_captain_squad_number_management.sql` | Name match only |
| `20261107222710` | `client_table_privileges` | PR #2: `20261107222710_client_table_privileges.sql`<br>main: `20261107234000_client_table_privileges.sql` | Name match only |
| `20261107222810` | `lock_submitted_team_sheets` | PR #2: `20261107222810_lock_submitted_team_sheets.sql`<br>main: `20261107235000_lock_submitted_team_sheets.sql` | Name match only |
| `20261107222901` | `team_sheet_goalkeeper_confirmation` | PR #2: `20261107222901_team_sheet_goalkeeper_confirmation.sql`<br>main: `20261107235500_team_sheet_goalkeeper_confirmation.sql` | Name match only |
| `20261107223135` | `team_sheet_drafts` | PR #2: `20261107223135_team_sheet_drafts.sql`<br>main: `20261107240000_team_sheet_drafts.sql` | Name match only |
| `20261107223312` | `admin_team_sheet_amendments` | PR #2: `20261107223312_admin_team_sheet_amendments.sql`<br>main: `20261107241000_admin_team_sheet_amendments.sql` | Name match only |
| `20261107223535` | `restrict_anonymous_auth_helpers` | PR #2: `20261107223535_restrict_anonymous_auth_helpers.sql`<br>main: `20261107242000_restrict_anonymous_auth_helpers.sql` | Name match only |
| `20261107223608` | `admin_team_sheet_active_memberships` | PR #2: `20261107223608_admin_team_sheet_active_memberships.sql`<br>main: `20261107224500_admin_team_sheet_active_memberships.sql` | Name match only |
| `20261107223733` | `admin_competition_setup` | PR #2: `20261107223733_admin_competition_setup.sql`<br>main: `20261107225000_admin_competition_setup.sql` | Name match only |
| `20261107223909` | `admin_team_roster_setup` | PR #2: `20261107223909_admin_team_roster_setup.sql`<br>main: `20261107230000_admin_team_roster_setup.sql` | Name match only |
| `20261107224104` | `admin_publication_lifecycle` | PR #2: `20261107224104_admin_publication_lifecycle.sql`<br>main: `20261107231000_admin_publication_lifecycle.sql` | Name match only |
| `20261107224149` | `admin_roster_lifecycle_guard` | PR #2: `20261107224149_admin_roster_lifecycle_guard.sql`<br>main: `20261107232000_admin_roster_lifecycle_guard.sql` | Name match only |
| `20261107224311` | `admin_fixture_management` | PR #2: `20261107224311_admin_fixture_management.sql`<br>PR #2: `20261107224351_admin_fixture_management.sql` | Name match only |
| `20261107224351` | `admin_fixture_management` | PR #2: `20261107224311_admin_fixture_management.sql`<br>PR #2: `20261107224351_admin_fixture_management.sql` | Name match only |
| `20261107224711` | `admin_player_register` | PR #2: `20261107224711_admin_player_register.sql`<br>main: `20261107235000_admin_player_register.sql` | Name match only |
| `20261107224829` | `admin_player_register_status_filter` | PR #2: `20261107224829_admin_player_register_status_filter.sql`<br>main: `20261107235500_admin_player_register_status_filter.sql` | Name match only |
| `20261107224926` | `fixture_goal_scorer_validation` | PR #2: `20261107224926_fixture_goal_scorer_validation.sql`<br>main: `20261107235900_fixture_goal_scorer_validation.sql` | Name match only |
| `20261107225102` | `goal_audit_actor_restrict` | main: `20261108000500_goal_audit_actor_restrict.sql` | Name match only |
| `20261107225233` | `admin_season_statistics` | main: `20261108001500_admin_season_statistics.sql` | Name match only |
| `20261107225256` | `admin_player_register_acl` | main: `20261108002000_admin_player_register_acl.sql` | Name match only |
| `20261107225453` | `first_release_bideford_location_policy` | PR #3: `20261107225453_first_release_bideford_location_policy.sql` | Name match only |
| `20261107225645` | `notification_outbox_preferences` | main: `20261108003000_notification_outbox_preferences.sql` | Name match only |
| `20261107225819` | `notification_channel_claim` | main: `20261108003500_notification_channel_claim.sql` | Name match only |
| `20261107225844` | `notification_uncertain_completion` | main: `20261108004000_notification_uncertain_completion.sql` | Name match only |
| `20261107230137` | `fixture_reminder_scheduler` | main: `20261108005000_fixture_reminder_scheduler.sql` | Name match only |
| `20261107230231` | `sms_consent_audit` | main: `20261108006000_sms_consent_audit.sql` | Name match only |
| `20261107230302` | `suppress_duplicate_captain_notices` | main: `20261108006500_suppress_duplicate_captain_notices.sql` | Name match only |
| `20261107230305` | `fixture_player_appearance_tracking` | — | <escape>UNRECOVERED</escape> |
| `20261107230322` | `revoke_notification_trigger_exec` | main: `20261108007000_revoke_notification_trigger_exec.sql` | Name match only |
| `20261107230404` | `admin_player_detail_corrections` | main: `20261108008000_admin_player_detail_corrections.sql` | Name match only |
| `20261107230643` | `player_ban_notifications` | main: `20261108009000_player_ban_notifications.sql` | Name match only |
| `20261107230713` | `permanent_notification_failure` | main: `20261108009500_permanent_notification_failure.sql` | Name match only |
| `20261107230921` | `player_transfer_workflow` | main: `20261108010000_player_transfer_workflow.sql` | Name match only |
| `20261107230942` | `transfer_destinations_empty_for_ineligible` | main: `20261108010500_transfer_destinations_empty_for_ineligible.sql` | Name match only |
| `20261107231222` | `admin_remove_player_from_team` | main: `20261108011000_admin_remove_player_from_team.sql` | Name match only |
| `20261107231311` | `admin_remove_membership_status_cast` | main: `20261108012000_admin_remove_membership_status_cast.sql` | Name match only |
| `20261107231424` | `retire_legacy_transfer_requests` | main: `20261108013000_retire_legacy_transfer_requests.sql` | Name match only |
| `20261107231600` | `finance_v1_manual_ledger` | main: `20261108014000_finance_v1_manual_ledger.sql` | Name match only |
| `20261107231622` | `finance_ledger_balance_and_method_guard` | main: `20261108014100_finance_ledger_balance_and_method_guard.sql` | Name match only |
| `20261107231632` | `finance_options_for_finance_roles` | — | <escape>UNRECOVERED</escape> |
| `20261107231646` | `finance_summary_team_balance_rollup` | — | <escape>UNRECOVERED</escape> |
| `20261107231809` | `finance_deny_direct_client_access` | main: `20261108014300_finance_deny_direct_client_access.sql` | Name match only |
| `20261107232025` | `admin_audit_history_reader` | main: `20261108014400_admin_audit_history_reader.sql` | Name match only |
| `20261107232124` | `audit_log_metadata_rpc_only` | main: `20261108014500_audit_log_metadata_rpc_only.sql` | Name match only |
| `20261107232144` | `audit_log_explicit_deny_policy` | — | <escape>UNRECOVERED</escape> |
| `20261107233105` | `guarded_notification_dispatch_scheduler` | main: `20261108014700_guarded_notification_dispatch_scheduler.sql` | Name match only |
| `20261107233311` | `fixture_goal_records_explicit_deny_policy` | — | <escape>UNRECOVERED</escape> |
| `20261107233439` | `index_uncovered_foreign_keys` | main: `20261108014900_index_uncovered_foreign_keys.sql` | Name match only |
| `20261107235914` | `payment_partial_refund_status` | PR #6: `20261108014900_payment_partial_refund_status.sql` | Name match only |
| `20261107235924` | `stripe_player_fixture_checkout` | PR #6: `20261108015000_stripe_player_fixture_checkout.sql` | Name match only |
| `20261107235943` | `payment_service_role_privileges` | PR #6: `20261108015100_payment_service_role_privileges.sql` | Name match only |
| `20261108001150` | `stripe_webhook_processing_lease` | PR #6: `20261108015100_stripe_webhook_processing_lease.sql` | Name match only |
| `20261108003052` | `20261108040000_restrict_notification_internal_function_execution` | PR #6: `20261108040000_restrict_notification_internal_function_execution.sql` | Name match only |
| `20261108003244` | `20261108043000_revoke_client_table_bypass_privileges` | PR #6: `20261108043000_revoke_client_table_bypass_privileges.sql` | Name match only |
| `20261108003629` | `20261108050000_serialize_player_fixture_payment_creation` | PR #6: `20261108050000_serialize_player_fixture_payment_creation.sql` | Name match only |
| `20261108004146` | `20261108060000_limit_self_service_profile_update_columns` | PR #6: `20261108060000_limit_self_service_profile_update_columns.sql` | Name match only |
| `20261108004430` | `20261108070000_require_captain_for_fixture_payment_actions` | PR #6: `20261108070000_require_captain_for_fixture_payment_actions.sql` | Name match only |
| `20261108004633` | `20261108080000_validate_team_membership_approval` | PR #6: `20261108080000_validate_team_membership_approval.sql` | Name match only |
| `20261108004703` | `20261108090000_serialize_admin_player_team_assignment` | PR #6: `20261108090000_serialize_admin_player_team_assignment.sql` | Name match only |
| `20261108004741` | `20261108100000_serialize_transfer_approval` | PR #6: `20261108100000_serialize_transfer_approval.sql` | Name match only |
| `20261108004806` | `20261108110000_validate_team_registration_captain_approval` | PR #6: `20261108110000_validate_team_registration_captain_approval.sql` | Name match only |
| `20261108005016` | `20261108120000_add_secure_captain_handover` | PR #6: `20261108120000_add_secure_captain_handover.sql` | Name match only |
| `20261108005024` | `20261108121000_restrict_captain_handover_execute` | PR #6: `20261108121000_restrict_captain_handover_execute.sql` | Name match only |
| `20261108010133` | `20261108130000_admin_context_preferences` | PR #6: `20261108130000_admin_context_preferences.sql` | Name match only |
| `20261108010425` | `20261108140000_context_scoped_admin_dashboard` | PR #6: `20261108140000_context_scoped_admin_dashboard.sql` | Name match only |
| `20261108010502` | `20261108150000_context_scoped_admin_player_register` | PR #6: `20261108150000_context_scoped_admin_player_register.sql` | Name match only |
| `20261108010634` | `20261108160000_context_scoped_admin_team_sheets` | PR #6: `20261108160000_context_scoped_admin_team_sheets.sql` | Name match only |
| `20261108010707` | `20261108170000_context_scoped_admin_transfers` | PR #6: `20261108170000_context_scoped_admin_transfers.sql` | Name match only |
| `20261108010816` | `20261108180000_context_scoped_admin_fixtures` | PR #6: `20261108180000_context_scoped_admin_fixtures.sql` | Name match only |
| `20261108011216` | `20261108190000_location_admin_assignments` | — | <escape>UNRECOVERED</escape> |
| `20261108011320` | `20261108200000_enforce_location_admin_scope` | PR #6: `20261108200000_enforce_location_admin_scope.sql` | Name match only |
| `20261108011333` | `20261108210000_scope_admin_setup_and_preferences` | PR #6: `20261108210000_scope_admin_setup_and_preferences.sql` | Name match only |
| `20261108011423` | `20261108220000_expose_admin_scope_type` | PR #6: `20261108220000_expose_admin_scope_type.sql` | Name match only |
| `20261108011516` | `20261108230000_restrict_global_player_identity_reviews` | PR #6: `20261108230000_restrict_global_player_identity_reviews.sql` | Name match only |
| `20261108011640` | `20261108240000_admin_location_assignment_search` | PR #6: `20261108240000_admin_location_assignment_search.sql` | Name match only |
| `20261108011751` | `20261108250000_enforce_location_admin_mutation_scope` | PR #6: `20261108250000_enforce_location_admin_mutation_scope.sql` | Name match only |
| `20261108011838` | `20261108260000_scope_admin_audit_notifications_and_stats` | PR #6: `20261108260000_scope_admin_audit_notifications_and_stats.sql` | Name match only |
| `20261108012459` | `20261108270000_location_scoped_admin_gallery` | PR #6: `20261108270000_location_scoped_admin_gallery.sql` | Name match only |
| `20261108012537` | `20261108280000_keep_unpublished_gallery_images_private` | PR #6: `20261108280000_keep_unpublished_gallery_images_private.sql` | Name match only |

## Unrecovered migration SQL
The following six live ledger records have no same-named local SQL file in any inspected source tree (`main`, PR #2, PR #3 or PR #6):
- `20261107230305` — `fixture_player_appearance_tracking`
- `20261107231632` — `finance_options_for_finance_roles`
- `20261107231646` — `finance_summary_team_balance_rollup`
- `20261107232144` — `audit_log_explicit_deny_policy`
- `20261107233311` — `fixture_goal_records_explicit_deny_policy`
- `20261108011216` — `20261108190000_location_admin_assignments`

Do not reconstruct these SQL files from the current database schema or infer their contents from later migrations. Recover their original committed SQL from Git history or an authoritative backup/export, then compare exact content and version ordering.

## Important caveats
- Two separate applied records named `admin_fixture_management` exist. PR #2 preserves two separately versioned files; they must remain separate even if the SQL text is identical.
- Three local names on `main` (`finance_balance_semantics`, `audit_log_deny_all_policy`, `fixture_goal_records_deny_all`) have no exact same-named ledger record. Their relationship to differently named applied records has not been established.
- PR #2 is based on an older `main`; PR #3 is 133 commits behind and divergent; PR #6 is currently not mergeable. None is approved for merge by this inventory.
- No database writes, migrations, branch merges, or deployments were performed.

## Expanded all-branch recovery search — 8 November 2026
The inventory was rechecked against every currently visible branch in `OPENPLAYNEW` (nine branches, 128 distinct SQL filenames). The six original applied migration sources remain absent from all inspected branch trees, and the GitHub commit history API returned no historical path entries for those exact filenames. This makes the original SQL unrecoverable from the repository's current branch/path history through the available GitHub evidence.

Three later files are semantically related but **are not substitutes for the original applied SQL**:
- `20261108014200_finance_balance_semantics.sql` revises `get_finance_ledger`, `get_finance_summary`, and finance entry creation. It may overlap with the missing finance migration records, but it is a later corrective migration and does not prove what the original `finance_options_for_finance_roles` or `finance_summary_team_balance_rollup` migrations contained.
- `20261108014600_audit_log_deny_all_policy.sql` adds a deny-all client policy to `audit_log`, conceptually related to the missing `audit_log_explicit_deny_policy` record.
- `20261108014800_fixture_goal_records_deny_all.sql` adds a deny-all client policy to `fixture_goal_records`, conceptually related to the missing `fixture_goal_records_explicit_deny_policy` record.

The missing `fixture_player_appearance_tracking` migration has historical feature context in the Stage 1 report, but that report is not the migration SQL. The missing `20261108190000_location_admin_assignments` source also remains unrecovered; later location-admin scoping migrations do not replace its original source.

### Safe next recovery route
Request an authoritative migration archive/export from the original migration author or CI artifact storage, or a backup of the source tree at the time those migrations were applied. If the exact SQL cannot be recovered, retain this gap explicitly and produce a new, separately versioned reconciliation migration only after a full schema/privilege/function diff and owner review. Do not fabricate or backdate files and do not edit the hosted migration ledger to make filenames appear reconciled.


## Follow-up: Bideford policy source restored to a clean PR branch
The `20261107225453_first_release_bideford_location_policy.sql` file was restored byte-for-byte from the original feature branch onto a clean branch based on `main`, avoiding the stale PR #3 branch. The restored file's blob SHA matches the original source (`0f039bc23f94cebf0d5cd9094fd67d13d65f0195`). It is included in PR #7 with the current admin activation UI. This restores one known applied migration source to the `main`-based candidate tree; it does not resolve the six remaining missing source records listed above. PR #7 remains draft/unmerged and no migration was rerun.


## Critical version-prefix alignment addendum — 8 November 2026 (later live snapshot)
A fresh `list_migrations` read now returns **98 live ledger rows** (the earlier 97-row count is superseded). Rechecked against all 10 visible repository branches (129 distinct migration filenames):
- **92/98** ledger rows have a source candidate by normalized migration name or exact version prefix.
- **6 applied source SQL files remain unrecovered**: `fixture_player_appearance_tracking`, `finance_options_for_finance_roles`, `finance_summary_team_balance_rollup`, `audit_log_explicit_deny_policy`, `fixture_goal_records_explicit_deny_policy`, and `location_admin_assignments` (ledger name `20261108190000_location_admin_assignments`).
- Of the 92 candidate rows, **36 have a local filename whose leading version matches the live ledger version**; **56 candidates have a different leading filename version** even though their normalized migration name matches. This is not proof that their SQL contents are identical to the applied source.
- The current PR #6 branch `feat/stripe-test-checkout-lifecycle` contains 93 migration files, but **zero leading filename versions match the 98-row live ledger**, and it has **nine duplicate filename version prefixes**. Examples include `20261107225000` (two files), `20261107230000` (two), `20261107231000` (two), `20261107232000` (two), `20261107233000` (two), `20261107235000` (two), `20261107235500` (two), `20261108014900` (two), and `20261108015100` (two).
- Concrete applied/local mismatches include the gallery migrations: live ledger versions `20261108012459` and `20261108012537` have names `20261108270000_location_scoped_admin_gallery` and `20261108280000_keep_unpublished_gallery_images_private`, while local filenames begin `20261108270000_` and `20261108280000_`. The live `player_team_request_status_rpc` version is `20261108020706`, while the local file begins `20261108021000_`.

**Deployment blocker:** do not run `supabase db push` or merge the current migration tree as a deployable baseline. The duplicate filename versions and version-prefix drift could cause migrations to be treated as pending or collide. Do not bulk-rename files solely from name matches. First obtain authoritative source history/archives, map every ledger row to the exact original SQL and applied version, resolve the duplicate `admin_fixture_management` history, and compare content hashes where source archives permit. Then produce a clean migration directory with unique prefixes matching the actual ledger versions and explicit treatment of the six missing SQL files. No migration files were renamed, no migration was rerun, and the live database was not modified during this check.


### Follow-up correction
The `player_team_request_status_rpc` source was restored in the current PR #6 branch as `20261108020706_player_team_request_status_rpc.sql`, matching the live ledger version `20261108020706`. This corrects the prior local filename `20261108021000_player_team_request_status_rpc.sql`. The current PR #6 branch therefore has one exact version-prefix match rather than zero; the other version-prefix mismatches and nine duplicate prefixes remain unresolved.

## 98-row applied migration source map (supersedes earlier 97-row snapshot)

Snapshot taken 8 November 2026 from all 10 visible branches (129 distinct migration filenames) and the live Supabase ledger (98 rows). A candidate path is not proof of SQL-content identity; the live ledger stores version/name metadata, not the original SQL hash.

| Ledger version | Ledger name | Candidate source (branch; blob SHA) | Match status |
|---|---|---|---|
| 20261107214404 | 20261107220000_initial_platform_schema | supabase/migrations/20261107214404_20261107220000_initial_platform_schema.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; d406a59878e2f06ed9a8d8029e8d6b09ee3fd160) | Exact version + name |
| 20261107214406 | 20261107221000_initial_rls_policies | supabase/migrations/20261107214406_20261107221000_initial_rls_policies.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; f918a659d51525b0b02b89ed90ee66866ac50aa4) | Exact version + name |
| 20261107214409 | 20261107222000_player_registration_workflows | supabase/migrations/20261107214409_20261107222000_player_registration_workflows.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 0bc7eda639514d093bb300bf42008d8c2e44a18a) | Exact version + name |
| 20261107214624 | 20261107223000_rpc_security_hardening | supabase/migrations/20261107214624_20261107223000_rpc_security_hardening.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 57e0e5b90dbf6d273af8152ac283aada4a6e0108) | Exact version + name |
| 20261107215659 | integrity_and_foreign_key_indexes | supabase/migrations/20261107215659_integrity_and_foreign_key_indexes.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; e148896fdbf5d1d3ec50b982f3355d9d12353f3f) | Exact version + name |
| 20261107215723 | team_registration_and_membership_hardening | supabase/migrations/20261107215723_team_registration_and_membership_hardening.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; f802a3b804b66f666b14703bf9c7683581cef63a) | Exact version + name |
| 20261107215956 | profile_avatar_storage | supabase/migrations/20261107215956_profile_avatar_storage.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 64eaf0aaca23c19bdb2f25bfc6a90e8daa7a7882) | Exact version + name |
| 20261107220045 | captain_dashboard_projection | supabase/migrations/20261107220045_captain_dashboard_projection.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 238a54919eb6ab4b4d7440698b7de45f36fab92c) | Exact version + name |
| 20261107220139 | admin_dashboard_projection | supabase/migrations/20261107220139_admin_dashboard_projection.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 625b7baeafd37d5c89f9b31cf35d0b052cd2aa5c) | Exact version + name |
| 20261107220520 | team_approval_consistency | supabase/migrations/20261107220520_team_approval_consistency.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 6372fc080e2500eb36152e10511914a75c26b421) | Exact version + name |
| 20261107220548 | admin_queue_consistency | supabase/migrations/20261107220548_admin_queue_consistency.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; f939a20c3e07d73f2d1134cd42935310a70a1705) | Exact version + name |
| 20261107220639 | captain_team_sheet_submission | supabase/migrations/20261107220639_captain_team_sheet_submission.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 02b00caf52552ea2915a9653b19ebb7ca61bcb38) | Exact version + name |
| 20261107220725 | team_sheet_membership_identifiers | supabase/migrations/20261107220725_team_sheet_membership_identifiers.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; e20913a2660b3ffb05ff956ea4cc6a47e4ff4ea9) | Exact version + name |
| 20261107220739 | captain_fixture_list | supabase/migrations/20261107220739_captain_fixture_list.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 0eadded78d8e5e9da1038bbb5fa6e80c1b249c69) | Exact version + name |
| 20261107220838 | unique_active_squad_numbers | supabase/migrations/20261107220838_unique_active_squad_numbers.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; e931b5b788f6a1654c741736d4c81f32e4b020a3) | Exact version + name |
| 20261107221445 | public_registration_scope | supabase/migrations/20261107221445_public_registration_scope.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 0f806d6cdf902577c6f4a421c76796435645db6a) | Exact version + name |
| 20261107221644 | captain_availability_privacy | supabase/migrations/20261107221644_captain_availability_privacy.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; cc690d43c88e5021ac06389b67e2c55e6b4f6b3d) | Exact version + name |
| 20261107221658 | captain_availability_dashboard | supabase/migrations/20261107221658_captain_availability_dashboard.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 92f4201cfa9af47793217ac342fef1e6caf1f82d) | Exact version + name |
| 20261107221843 | captain_squad_number_management | supabase/migrations/20261107221843_captain_squad_number_management.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; c0b6d36e758a7699197bc25621157c1437506ff7) | Exact version + name |
| 20261107222710 | client_table_privileges | supabase/migrations/20261107222710_client_table_privileges.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 2643ce183a3f863a6e7d52948ba53388275b9d0a) | Exact version + name |
| 20261107222810 | lock_submitted_team_sheets | supabase/migrations/20261107222810_lock_submitted_team_sheets.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; f8247844a6fb4e69902b1af87c337abefa42ca54) | Exact version + name |
| 20261107222901 | team_sheet_goalkeeper_confirmation | supabase/migrations/20261107222901_team_sheet_goalkeeper_confirmation.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 0f47622b423ef9fe81f1a1112a4e32271c1c96a2) | Exact version + name |
| 20261107223135 | team_sheet_drafts | supabase/migrations/20261107223135_team_sheet_drafts.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; e2c45b4664f0e58bba00375fe507b4eaccf92a8f) | Exact version + name |
| 20261107223312 | admin_team_sheet_amendments | supabase/migrations/20261107223312_admin_team_sheet_amendments.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 1280a5d363459a85275156ec8b1fa02ba2d2bbc5) | Exact version + name |
| 20261107223535 | restrict_anonymous_auth_helpers | supabase/migrations/20261107223535_restrict_anonymous_auth_helpers.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 33f9e4cfef7bc279248b89d0a49801617db8d634) | Exact version + name |
| 20261107223608 | admin_team_sheet_active_memberships | supabase/migrations/20261107223608_admin_team_sheet_active_memberships.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 104e3953a980b566c6f1410826a95135cc0408f1) | Exact version + name |
| 20261107223733 | admin_competition_setup | supabase/migrations/20261107223733_admin_competition_setup.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 010f32d648726db0e4a8022fe474b92363829c2f) | Exact version + name |
| 20261107223909 | admin_team_roster_setup | supabase/migrations/20261107223909_admin_team_roster_setup.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; a9ae5cf1458612c5004595f08583d2f852b81b4f) | Exact version + name |
| 20261107224104 | admin_publication_lifecycle | supabase/migrations/20261107224104_admin_publication_lifecycle.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; c80a189ef1cb0172a946e70856f1198575b589f6) | Exact version + name |
| 20261107224149 | admin_roster_lifecycle_guard | supabase/migrations/20261107224149_admin_roster_lifecycle_guard.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 7184a747e8b0d46e5159a6d132a789fa853520d2) | Exact version + name |
| 20261107224311 | admin_fixture_management | supabase/migrations/20261107224311_admin_fixture_management.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; f586326ec408dbebadbf458ae317f1e7252ce1bf) | Exact version + name |
| 20261107224351 | admin_fixture_management | supabase/migrations/20261107224351_admin_fixture_management.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; f586326ec408dbebadbf458ae317f1e7252ce1bf) | Exact version + name |
| 20261107224711 | admin_player_register | supabase/migrations/20261107224711_admin_player_register.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; ed2b7faef6841f11e4e1453ff1beec1efa5dfbcf) | Exact version + name |
| 20261107224829 | admin_player_register_status_filter | supabase/migrations/20261107224829_admin_player_register_status_filter.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; 521d12b9168ab03085b11ac8670e1d3f798d1105) | Exact version + name |
| 20261107224926 | fixture_goal_scorer_validation | supabase/migrations/20261107224926_fixture_goal_scorer_validation.sql (chore/reconcile-supabase-migration-ledger-2026-11-07; babba5e77247bb66d45ccc8af00028eb13cbfaa2) | Exact version + name |
| 20261107225102 | goal_audit_actor_restrict | supabase/migrations/20261108000500_goal_audit_actor_restrict.sql (main; 233a7e6b2f7040fd2f2a10b0dbd6d69e1a23468f) | Name match; version prefix differs |
| 20261107225233 | admin_season_statistics | supabase/migrations/20261108001500_admin_season_statistics.sql (main; 271252781b06ad5748d39dbe22f82aa8abf8c0d0) | Name match; version prefix differs |
| 20261107225256 | admin_player_register_acl | supabase/migrations/20261108002000_admin_player_register_acl.sql (main; 4781169f3672fca481c5ce34734dc944b90859dd) | Name match; version prefix differs |
| 20261107225453 | first_release_bideford_location_policy | supabase/migrations/20261107225453_first_release_bideford_location_policy.sql (feat/bideford-only-location-activation-2026-11-07; 0f039bc23f94cebf0d5cd9094fd67d13d65f0195) | Exact version + name |
| 20261107225645 | notification_outbox_preferences | supabase/migrations/20261108003000_notification_outbox_preferences.sql (main; 530fe6053acce6d4c512d379354a901851d08588) | Name match; version prefix differs |
| 20261107225819 | notification_channel_claim | supabase/migrations/20261108003500_notification_channel_claim.sql (main; 43a3df4a580aeb9cfc60a99e82b90d16296f6730) | Name match; version prefix differs |
| 20261107225844 | notification_uncertain_completion | supabase/migrations/20261108004000_notification_uncertain_completion.sql (main; ed862ba044ae635d446404b7bcfb9653dbfe4a5a) | Name match; version prefix differs |
| 20261107230137 | fixture_reminder_scheduler | supabase/migrations/20261108005000_fixture_reminder_scheduler.sql (main; ab6c18ce2a2da0d6e0785635d2e28e756974a9b6) | Name match; version prefix differs |
| 20261107230231 | sms_consent_audit | supabase/migrations/20261108006000_sms_consent_audit.sql (main; 190184d646c2cf0242ddb2c76c86b87d837437cc) | Name match; version prefix differs |
| 20261107230302 | suppress_duplicate_captain_notices | supabase/migrations/20261108006500_suppress_duplicate_captain_notices.sql (main; 593f45ce0d3196db851634bed8eb2f92b971d543) | Name match; version prefix differs |
| 20261107230305 | fixture_player_appearance_tracking | — | Missing source |
| 20261107230322 | revoke_notification_trigger_exec | supabase/migrations/20261108007000_revoke_notification_trigger_exec.sql (main; adc43e577055c111aaf6f1f5d387ee897ce3d491) | Name match; version prefix differs |
| 20261107230404 | admin_player_detail_corrections | supabase/migrations/20261108008000_admin_player_detail_corrections.sql (main; e28b5e6e3ac6e0086ed95d1ff09643eb62bbf423) | Name match; version prefix differs |
| 20261107230643 | player_ban_notifications | supabase/migrations/20261108009000_player_ban_notifications.sql (main; 3d41983b1b250a109a893f115fb5d397028a2362) | Name match; version prefix differs |
| 20261107230713 | permanent_notification_failure | supabase/migrations/20261108009500_permanent_notification_failure.sql (main; 4d99518bca2d39af8263e4d1702ba28a4cc2295a) | Name match; version prefix differs |
| 20261107230921 | player_transfer_workflow | supabase/migrations/20261108010000_player_transfer_workflow.sql (main; 9af61ca54ecaeb0d5a329b8e2dd59020556c1740) | Name match; version prefix differs |
| 20261107230942 | transfer_destinations_empty_for_ineligible | supabase/migrations/20261108010500_transfer_destinations_empty_for_ineligible.sql (main; d4c7fd4d3b1620116a9e8ccde3917b48fa8f7e30) | Name match; version prefix differs |
| 20261107231222 | admin_remove_player_from_team | supabase/migrations/20261108011000_admin_remove_player_from_team.sql (main; 678c0c0c652142b503c08a18a2fa7fcabb10f83d) | Name match; version prefix differs |
| 20261107231311 | admin_remove_membership_status_cast | supabase/migrations/20261108012000_admin_remove_membership_status_cast.sql (main; 59a096a3693215620a228fb5cf542878c4c3cbf4) | Name match; version prefix differs |
| 20261107231424 | retire_legacy_transfer_requests | supabase/migrations/20261108013000_retire_legacy_transfer_requests.sql (main; 76a08c0515ccbd0aa809baffa4f800f89ef557ab) | Name match; version prefix differs |
| 20261107231600 | finance_v1_manual_ledger | supabase/migrations/20261108014000_finance_v1_manual_ledger.sql (main; cb05079206c225198dc57469c7d1148a576a2000) | Name match; version prefix differs |
| 20261107231622 | finance_ledger_balance_and_method_guard | supabase/migrations/20261108014100_finance_ledger_balance_and_method_guard.sql (main; 57618b8a2c5d4ed7997ef92504e1f2de9b76f8c6) | Name match; version prefix differs |
| 20261107231632 | finance_options_for_finance_roles | — | Missing source |
| 20261107231646 | finance_summary_team_balance_rollup | — | Missing source |
| 20261107231809 | finance_deny_direct_client_access | supabase/migrations/20261108014300_finance_deny_direct_client_access.sql (main; feb8345c279df63687a75888bc5fb408908f7de7) | Name match; version prefix differs |
| 20261107232025 | admin_audit_history_reader | supabase/migrations/20261108014400_admin_audit_history_reader.sql (main; 59052e189a550d9250b555e40c8463a124de7aaa) | Name match; version prefix differs |
| 20261107232124 | audit_log_metadata_rpc_only | supabase/migrations/20261108014500_audit_log_metadata_rpc_only.sql (main; 7712d4c3d427c24b8da82e304a162b3ddd8e3922) | Name match; version prefix differs |
| 20261107232144 | audit_log_explicit_deny_policy | — | Missing source |
| 20261107233105 | guarded_notification_dispatch_scheduler | supabase/migrations/20261108014700_guarded_notification_dispatch_scheduler.sql (main; b5b290bfa3ade8a403dbbeaf8a66c385d25ab5e5) | Name match; version prefix differs |
| 20261107233311 | fixture_goal_records_explicit_deny_policy | — | Missing source |
| 20261107233439 | index_uncovered_foreign_keys | supabase/migrations/20261108014900_index_uncovered_foreign_keys.sql (main; dfcd6d17ac2aaa3f59bdbac79b2558fbb6921bb9) | Name match; version prefix differs |
| 20261107235914 | payment_partial_refund_status | supabase/migrations/20261108014900_payment_partial_refund_status.sql (feat/stripe-test-checkout-lifecycle; 9a15e3a21891328477360fdd908ffac5aaa5a2ac) | Name match; version prefix differs |
| 20261107235924 | stripe_player_fixture_checkout | supabase/migrations/20261108015000_stripe_player_fixture_checkout.sql (feat/stripe-test-checkout-lifecycle; 9f85d9b7902100b1bd84cc2f62e24429c0e70e00) | Name match; version prefix differs |
| 20261107235943 | payment_service_role_privileges | supabase/migrations/20261108015100_payment_service_role_privileges.sql (feat/stripe-test-checkout-lifecycle; c022cc0778d67f0145aed089a48a05a66325fb5b) | Name match; version prefix differs |
| 20261108001150 | stripe_webhook_processing_lease | supabase/migrations/20261108015100_stripe_webhook_processing_lease.sql (feat/stripe-test-checkout-lifecycle; 3d534bfe697974b1e799dc234377489b6c7cdd31) | Name match; version prefix differs |
| 20261108003052 | 20261108040000_restrict_notification_internal_function_execution | supabase/migrations/20261108040000_restrict_notification_internal_function_execution.sql (feat/stripe-test-checkout-lifecycle; fd2835a554dd0e3a0c07f07e40a841886605086c) | Name match; version prefix differs |
| 20261108003244 | 20261108043000_revoke_client_table_bypass_privileges | supabase/migrations/20261108043000_revoke_client_table_bypass_privileges.sql (feat/stripe-test-checkout-lifecycle; 9ad7d978953fa883033a17726e1ed2787db97730) | Name match; version prefix differs |
| 20261108003629 | 20261108050000_serialize_player_fixture_payment_creation | supabase/migrations/20261108050000_serialize_player_fixture_payment_creation.sql (feat/stripe-test-checkout-lifecycle; fe5a4ea38fd03e9065806fcfb40cad16a107dc0d) | Name match; version prefix differs |
| 20261108004146 | 20261108060000_limit_self_service_profile_update_columns | supabase/migrations/20261108060000_limit_self_service_profile_update_columns.sql (feat/stripe-test-checkout-lifecycle; 12224bcf877af11e05e367f8599197b266c8b2ac) | Name match; version prefix differs |
| 20261108004430 | 20261108070000_require_captain_for_fixture_payment_actions | supabase/migrations/20261108070000_require_captain_for_fixture_payment_actions.sql (feat/stripe-test-checkout-lifecycle; a39f516ab32aefbfe8c22fb6c6a15a9179d09c7b) | Name match; version prefix differs |
| 20261108004633 | 20261108080000_validate_team_membership_approval | supabase/migrations/20261108080000_validate_team_membership_approval.sql (feat/stripe-test-checkout-lifecycle; d5137eb4aaf44c9f8f16842181e314d438e00054) | Name match; version prefix differs |
| 20261108004703 | 20261108090000_serialize_admin_player_team_assignment | supabase/migrations/20261108090000_serialize_admin_player_team_assignment.sql (feat/stripe-test-checkout-lifecycle; 3eefbd13001d6091a86c7fa81af0c0e263594f16) | Name match; version prefix differs |
| 20261108004741 | 20261108100000_serialize_transfer_approval | supabase/migrations/20261108100000_serialize_transfer_approval.sql (feat/stripe-test-checkout-lifecycle; 8c86dcc73faa6e0f6c71d0b1c69ea67bf09febd3) | Name match; version prefix differs |
| 20261108004806 | 20261108110000_validate_team_registration_captain_approval | supabase/migrations/20261108110000_validate_team_registration_captain_approval.sql (feat/stripe-test-checkout-lifecycle; 47b4427c98c9a2d4ea155b8ce65cdec9a0b2be67) | Name match; version prefix differs |
| 20261108005016 | 20261108120000_add_secure_captain_handover | supabase/migrations/20261108120000_add_secure_captain_handover.sql (feat/stripe-test-checkout-lifecycle; d13b2fc2cfb99bd6c31468deee961f9d7a895357) | Name match; version prefix differs |
| 20261108005024 | 20261108121000_restrict_captain_handover_execute | supabase/migrations/20261108121000_restrict_captain_handover_execute.sql (feat/stripe-test-checkout-lifecycle; 274ca175329218fed73f1cfca87e148d561da192) | Name match; version prefix differs |
| 20261108010133 | 20261108130000_admin_context_preferences | supabase/migrations/20261108130000_admin_context_preferences.sql (feat/stripe-test-checkout-lifecycle; 35ee204626e3e0c423daf00a8e6c4668131b5025) | Name match; version prefix differs |
| 20261108010425 | 20261108140000_context_scoped_admin_dashboard | supabase/migrations/20261108140000_context_scoped_admin_dashboard.sql (feat/stripe-test-checkout-lifecycle; ef61b1fea79f612a406ebddd760371a24c84e3c8) | Name match; version prefix differs |
| 20261108010502 | 20261108150000_context_scoped_admin_player_register | supabase/migrations/20261108150000_context_scoped_admin_player_register.sql (feat/stripe-test-checkout-lifecycle; d63d669a36d6f192ab550149b4bc13e0e69cec55) | Name match; version prefix differs |
| 20261108010634 | 20261108160000_context_scoped_admin_team_sheets | supabase/migrations/20261108160000_context_scoped_admin_team_sheets.sql (feat/stripe-test-checkout-lifecycle; 5ef1c380a562cacd99f795cb90896cb3b57aa3d0) | Name match; version prefix differs |
| 20261108010707 | 20261108170000_context_scoped_admin_transfers | supabase/migrations/20261108170000_context_scoped_admin_transfers.sql (feat/stripe-test-checkout-lifecycle; 6019be1a006899f6f62e79a2c2b7eb83166c1e14) | Name match; version prefix differs |
| 20261108010816 | 20261108180000_context_scoped_admin_fixtures | supabase/migrations/20261108180000_context_scoped_admin_fixtures.sql (feat/stripe-test-checkout-lifecycle; 815ff4671c6fccddf7858b0c47110ef12b8721ca) | Name match; version prefix differs |
| 20261108011216 | 20261108190000_location_admin_assignments | — | Missing source |
| 20261108011320 | 20261108200000_enforce_location_admin_scope | supabase/migrations/20261108200000_enforce_location_admin_scope.sql (feat/stripe-test-checkout-lifecycle; 72ce356064bf0fea5e7522d371bcacfad1b262e7) | Name match; version prefix differs |
| 20261108011333 | 20261108210000_scope_admin_setup_and_preferences | supabase/migrations/20261108210000_scope_admin_setup_and_preferences.sql (feat/stripe-test-checkout-lifecycle; ed9333ae6400e12dfd8b141f9e1af126743ea6d5) | Name match; version prefix differs |
| 20261108011423 | 20261108220000_expose_admin_scope_type | supabase/migrations/20261108220000_expose_admin_scope_type.sql (feat/stripe-test-checkout-lifecycle; c4295a4b905b3b364c605e3cbfc0bc6e79744720) | Name match; version prefix differs |
| 20261108011516 | 20261108230000_restrict_global_player_identity_reviews | supabase/migrations/20261108230000_restrict_global_player_identity_reviews.sql (feat/stripe-test-checkout-lifecycle; 06938c73eca01a1526f3aaeb9cda22a6db7302d1) | Name match; version prefix differs |
| 20261108011640 | 20261108240000_admin_location_assignment_search | supabase/migrations/20261108240000_admin_location_assignment_search.sql (feat/stripe-test-checkout-lifecycle; cf69fb547abe831c0422b8af3022a52061a280b4) | Name match; version prefix differs |
| 20261108011751 | 20261108250000_enforce_location_admin_mutation_scope | supabase/migrations/20261108250000_enforce_location_admin_mutation_scope.sql (feat/stripe-test-checkout-lifecycle; 0fe58206994b2697ac3030769b7ed4a4cd4aa138) | Name match; version prefix differs |
| 20261108011838 | 20261108260000_scope_admin_audit_notifications_and_stats | supabase/migrations/20261108260000_scope_admin_audit_notifications_and_stats.sql (feat/stripe-test-checkout-lifecycle; 472bd07a28fcadb2b2f3756be17886b524fab3dd) | Name match; version prefix differs |
| 20261108012459 | 20261108270000_location_scoped_admin_gallery | supabase/migrations/20261108270000_location_scoped_admin_gallery.sql (feat/stripe-test-checkout-lifecycle; f8ba0fecfc2159a0dee462f4e36661a7fb0cbe01) | Name match; version prefix differs |
| 20261108012537 | 20261108280000_keep_unpublished_gallery_images_private | supabase/migrations/20261108280000_keep_unpublished_gallery_images_private.sql (feat/stripe-test-checkout-lifecycle; a642ee82dd71ba7882364a5d0caf9f236e40e039) | Name match; version prefix differs |
| 20261108020706 | player_team_request_status_rpc | supabase/migrations/20261108020706_player_team_request_status_rpc.sql (feat/stripe-test-checkout-lifecycle; 2cc6ad92429460ee1d23a9f406afe0ad875868bc) | Exact version + name |

Summary: 37 exact version+name candidates, 55 name-only candidates requiring version-prefix reconciliation, 6 missing original SQL sources. The two admin_fixture_management ledger rows (versions 20261107224311 and 20261107224351) map to byte-identical local source blobs (f586326ec408dbebadbf458ae317f1e7252ce1bf); this duplicate application should be reviewed, although the SQL uses CREATE OR REPLACE definitions and grants.


## Consolidation update — 8 November 2026, 02:23 UTC

The exact Bideford first-release migration source has now been copied byte-for-byte from the reviewed PR #7 source branch into the primary PR #6 feature branch:
- File: `supabase/migrations/20261107225453_first_release_bideford_location_policy.sql`
- Verified original blob SHA: `0f039bc23f94cebf0d5cd9094fd67d13d65f0195`
- The PR #6 copy has the same blob SHA. No SQL was executed and no live database rows/schema were changed.

A fresh comparison of the **98-row live migration ledger** with the current PR #6 branch tree reports:
- 94 local migration SQL files.
- Exactly **2** exact leading-version-prefix matches: `20261107225453` (Bideford first-release policy) and `20261108020706` (player team-request status RPC).
- **9 duplicate local version prefixes** remain.
- 96 live ledger versions still lack an exact leading-prefix match in the current branch.
- The six original applied SQL sources listed in this report remain unrecovered: `fixture_player_appearance_tracking`, `finance_options_for_finance_roles`, `finance_summary_team_balance_rollup`, `audit_log_explicit_deny_policy`, `fixture_goal_records_explicit_deny_policy`, and `location_admin_assignments`.

The PR #7 location activation controls and policy documentation have been ported into PR #6. The primary branch now has a platform-admin-gated Bideford activation/deactivation confirmation flow, reason and confirmation checkbox, and the exact source migration. The Needs Attention summary tiles now link to the correct PR #6 queue IDs with keyboard-focus styling. Admin workspace labels are sequentially numbered. This is source consolidation only; PR #6 remains draft and must not be deployed as a migration baseline.

CI on PR #6 head `a345997ed11e3c96aeacb6f6b242434cc64aece0` passed (7 test files / 78 tests, Edge Function type-check, TypeScript/Vite build and Cloudflare dry-run). A subsequent small copy update to the location-creation success/help text is on a newer head and awaits its own CI result.


## PR consolidation closeout — 8 November 2026, 02:25 UTC

PR #7 is now **closed unmerged** because all of its unique changes were ported to PR #6 and the consolidated branch passed workflow `42438352387` at head `8698acc3c6fa5700786a2e4deb1c86eb37b557d2` (7 test files / 78 tests; type-check, build and Cloudflare dry-run all passed). The exact Bideford source blob SHA remains `0f039bc23f94cebf0d5cd9094fd67d13d65f0195`.

The PR #6 migration directory currently has 94 SQL files, two exact leading-version-prefix matches to the 98-row live ledger, and nine duplicate prefixes. Six original applied SQL sources remain unrecovered. PR #6 is draft/unmerged. No migrations were executed.


## Live ledger refresh — 8 November 2026, 12:21 UTC

A fresh Supabase `list_migrations` read confirms the live ledger remains at **98 applied records**. The current PR #6 source inventory remains **94 local migration SQL files**, with only **2 exact leading-version-prefix matches**, **9 duplicate local version prefixes**, and **96 live ledger versions without an exact leading-prefix match**. The six unrecovered original applied SQL sources remain:
- `fixture_player_appearance_tracking`
- `finance_options_for_finance_roles`
- `finance_summary_team_balance_rollup`
- `audit_log_explicit_deny_policy`
- `fixture_goal_records_explicit_deny_policy`
- `location_admin_assignments`

The 98 live ledger records are not a deployable migration baseline in the current branch. Preserve the live migration history; do not use `db push`, re-run historical SQL, edit the migration ledger, or rename files merely to force filename parity. Exact source recovery and SQL-content/hash comparison remain required before any migration-tree consolidation is approved.

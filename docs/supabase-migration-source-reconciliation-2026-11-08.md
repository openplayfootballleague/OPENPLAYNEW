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

# Open Play New — applied Supabase migration source manifest

**Snapshot:** 8 November 2026, 13:55 UTC  
**Project:** `ghnrsysvrlgkjmdlwdmp`  
**Branch:** `chore/reconcile-remaining-applied-migrations-2026-11-08`  
**Applied ledger rows:** 98  
**Canonical source files:** 98/98 present, unique version prefixes  
**Forward-only local migrations:** `20261108014200_finance_balance_semantics.sql` (finance balance semantics; requires separate review), `20261108030000_scope_rls_to_global_admins.sql` (prevents location-scoped `league_admin` roles from receiving global direct-table RLS access), and `20261108031000_revoke_unscoped_admin_rpcs.sql` (revokes client execution of legacy cross-location admin RPCs); all require isolated replay and role-matrix verification.

This manifest maps every applied ledger version/name to its canonical source path and Git blob SHA. The 24 previously unmapped source statements were recovered from the live migration ledger. The other 74 source statements were reconciled from the verified PR #2, PR #6 and PR #21 source sets. The migration ledger's `name` field may retain an older embedded timestamp; the source path is mapped by the authoritative 14-digit applied version prefix.

| Ledger version | Ledger name | Canonical source path | Git blob SHA |
|---|---|---|---|
| 20261107214404 | 20261107220000_initial_platform_schema | `supabase/migrations/20261107214404_20261107220000_initial_platform_schema.sql` | `d406a59878e2f06ed9a8d8029e8d6b09ee3fd160` |
| 20261107214406 | 20261107221000_initial_rls_policies | `supabase/migrations/20261107214406_20261107221000_initial_rls_policies.sql` | `f918a659d51525b0b02b89ed90ee66866ac50aa4` |
| 20261107214409 | 20261107222000_player_registration_workflows | `supabase/migrations/20261107214409_20261107222000_player_registration_workflows.sql` | `0bc7eda639514d093bb300bf42008d8c2e44a18a` |
| 20261107214624 | 20261107223000_rpc_security_hardening | `supabase/migrations/20261107214624_20261107223000_rpc_security_hardening.sql` | `57e0e5b90dbf6d273af8152ac283aada4a6e0108` |
| 20261107215659 | integrity_and_foreign_key_indexes | `supabase/migrations/20261107215659_integrity_and_foreign_key_indexes.sql` | `e148896fdbf5d1d3ec50b982f3355d9d12353f3f` |
| 20261107215723 | team_registration_and_membership_hardening | `supabase/migrations/20261107215723_team_registration_and_membership_hardening.sql` | `f802a3b804b66f666b14703bf9c7683581cef63a` |
| 20261107215956 | profile_avatar_storage | `supabase/migrations/20261107215956_profile_avatar_storage.sql` | `64eaf0aaca23c19bdb2f25bfc6a90e8daa7a7882` |
| 20261107220045 | captain_dashboard_projection | `supabase/migrations/20261107220045_captain_dashboard_projection.sql` | `238a54919eb6ab4b4d7440698b7de45f36fab92c` |
| 20261107220139 | admin_dashboard_projection | `supabase/migrations/20261107220139_admin_dashboard_projection.sql` | `02c72ad02703be7832f996e811886cf10641a848` |
| 20261107220520 | team_approval_consistency | `supabase/migrations/20261107220520_team_approval_consistency.sql` | `6372fc080e2500eb36152e10511914a75c26b421` |
| 20261107220548 | admin_queue_consistency | `supabase/migrations/20261107220548_admin_queue_consistency.sql` | `f939a20c3e07d73f2d1134cd42935310a70a1705` |
| 20261107220639 | captain_team_sheet_submission | `supabase/migrations/20261107220639_captain_team_sheet_submission.sql` | `02b00caf52552ea2915a9653b19ebb7ca61bcb38` |
| 20261107220725 | team_sheet_membership_identifiers | `supabase/migrations/20261107220725_team_sheet_membership_identifiers.sql` | `e20913a2660b3ffb05ff956ea4cc6a47e4ff4ea9` |
| 20261107220739 | captain_fixture_list | `supabase/migrations/20261107220739_captain_fixture_list.sql` | `0eadded78d8e5e9da1038bbb5fa6e80c1b249c69` |
| 20261107220838 | unique_active_squad_numbers | `supabase/migrations/20261107220838_unique_active_squad_numbers.sql` | `e931b5b788f6a1654c741736d4c81f32e4b020a3` |
| 20261107221445 | public_registration_scope | `supabase/migrations/20261107221445_public_registration_scope.sql` | `0f806d6cdf902577c6f4a421c76796435645db6a` |
| 20261107221644 | captain_availability_privacy | `supabase/migrations/20261107221644_captain_availability_privacy.sql` | `cc690d43c88e5021ac06389b67e2c55e6b4f6b3d` |
| 20261107221658 | captain_availability_dashboard | `supabase/migrations/20261107221658_captain_availability_dashboard.sql` | `92f4201cfa9af47793217ac342fef1e6caf1f82d` |
| 20261107221843 | captain_squad_number_management | `supabase/migrations/20261107221843_captain_squad_number_management.sql` | `c0b6d36e758a7699197bc25621157c1437506ff7` |
| 20261107222710 | client_table_privileges | `supabase/migrations/20261107222710_client_table_privileges.sql` | `2d793caec11fed93151407be92350da13da135f7` |
| 20261107222810 | lock_submitted_team_sheets | `supabase/migrations/20261107222810_lock_submitted_team_sheets.sql` | `6fcf3b793bbcd91b93436921f7d502581d1d2620` |
| 20261107222901 | team_sheet_goalkeeper_confirmation | `supabase/migrations/20261107222901_team_sheet_goalkeeper_confirmation.sql` | `f06de4604bbe6c170bc36928606c6e0a21fb2b35` |
| 20261107223135 | team_sheet_drafts | `supabase/migrations/20261107223135_team_sheet_drafts.sql` | `2085ec4b4e2f0c912987845165e9128257b29c3d` |
| 20261107223312 | admin_team_sheet_amendments | `supabase/migrations/20261107223312_admin_team_sheet_amendments.sql` | `5c47f1f91943c67bcafedd7d0cc414951a964ab6` |
| 20261107223535 | restrict_anonymous_auth_helpers | `supabase/migrations/20261107223535_restrict_anonymous_auth_helpers.sql` | `7e73486ba5f20396a4790f2bd8351c568735633a` |
| 20261107223608 | admin_team_sheet_active_memberships | `supabase/migrations/20261107223608_admin_team_sheet_active_memberships.sql` | `7f67271cb098191aee19234aa0e0362caa6631b8` |
| 20261107223733 | admin_competition_setup | `supabase/migrations/20261107223733_admin_competition_setup.sql` | `e2d947129f8159ab1b00c7394fa9889110fa4691` |
| 20261107223909 | admin_team_roster_setup | `supabase/migrations/20261107223909_admin_team_roster_setup.sql` | `758e2323ace3bcf1990d422fe3e41df09ce6d209` |
| 20261107224104 | admin_publication_lifecycle | `supabase/migrations/20261107224104_admin_publication_lifecycle.sql` | `42a5d2168a5c9ef421a20cc79f21c710f6e8bd51` |
| 20261107224149 | admin_roster_lifecycle_guard | `supabase/migrations/20261107224149_admin_roster_lifecycle_guard.sql` | `61c0037bdb2fe54ffc216cf8dd13fcd7ac5ef1d7` |
| 20261107224311 | admin_fixture_management | `supabase/migrations/20261107224311_admin_fixture_management.sql` | `bc164dcd5e7b505cc0c56d8454055711484d4fe4` |
| 20261107224351 | admin_fixture_management | `supabase/migrations/20261107224351_admin_fixture_management.sql` | `f586326ec408dbebadbf458ae317f1e7252ce1bf` |
| 20261107224711 | admin_player_register | `supabase/migrations/20261107224711_admin_player_register.sql` | `3388931f7e41aac906568b4d31129e2705983c37` |
| 20261107224829 | admin_player_register_status_filter | `supabase/migrations/20261107224829_admin_player_register_status_filter.sql` | `8831b175b733f50285fa83e9414a7c67f998289d` |
| 20261107224926 | fixture_goal_scorer_validation | `supabase/migrations/20261107224926_fixture_goal_scorer_validation.sql` | `84d3c2183ef67ef223f91819b920fa133b10bc21` |
| 20261107225102 | goal_audit_actor_restrict | `supabase/migrations/20261107225102_goal_audit_actor_restrict.sql` | `360dd856fd393fc69d039c6b17475637bb75ee8f` |
| 20261107225233 | admin_season_statistics | `supabase/migrations/20261107225233_admin_season_statistics.sql` | `271252781b06ad5748d39dbe22f82aa8abf8c0d0` |
| 20261107225256 | admin_player_register_acl | `supabase/migrations/20261107225256_admin_player_register_acl.sql` | `4781169f3672fca481c5ce34734dc944b90859dd` |
| 20261107225453 | first_release_bideford_location_policy | `supabase/migrations/20261107225453_first_release_bideford_location_policy.sql` | `0f039bc23f94cebf0d5cd9094fd67d13d65f0195` |
| 20261107225645 | notification_outbox_preferences | `supabase/migrations/20261107225645_notification_outbox_preferences.sql` | `530fe6053acce6d4c512d379354a901851d08588` |
| 20261107225819 | notification_channel_claim | `supabase/migrations/20261107225819_notification_channel_claim.sql` | `43a3df4a580aeb9cfc60a99e82b90d16296f6730` |
| 20261107225844 | notification_uncertain_completion | `supabase/migrations/20261107225844_notification_uncertain_completion.sql` | `ed862ba044ae635d446404b7bcfb9653dbfe4a5a` |
| 20261107230137 | fixture_reminder_scheduler | `supabase/migrations/20261107230137_fixture_reminder_scheduler.sql` | `ab6c18ce2a2da0d6e0785635d2e28e756974a9b6` |
| 20261107230231 | sms_consent_audit | `supabase/migrations/20261107230231_sms_consent_audit.sql` | `190184d646c2cf0242ddb2c76c86b87d837437cc` |
| 20261107230302 | suppress_duplicate_captain_notices | `supabase/migrations/20261107230302_suppress_duplicate_captain_notices.sql` | `593f45ce0d3196db851634bed8eb2f92b971d543` |
| 20261107230305 | fixture_player_appearance_tracking | `supabase/migrations/20261107230305_fixture_player_appearance_tracking.sql` | `97eb5b8a7dfb3027a1d88d21c7624e55d1f33f04` |
| 20261107230322 | revoke_notification_trigger_exec | `supabase/migrations/20261107230322_revoke_notification_trigger_exec.sql` | `adc43e577055c111aaf6f1f5d387ee897ce3d491` |
| 20261107230404 | admin_player_detail_corrections | `supabase/migrations/20261107230404_admin_player_detail_corrections.sql` | `e28b5e6e3ac6e0086ed95d1ff09643eb62bbf423` |
| 20261107230643 | player_ban_notifications | `supabase/migrations/20261107230643_player_ban_notifications.sql` | `3d41983b1b250a109a893f115fb5d397028a2362` |
| 20261107230713 | permanent_notification_failure | `supabase/migrations/20261107230713_permanent_notification_failure.sql` | `4d99518bca2d39af8263e4d1702ba28a4cc2295a` |
| 20261107230921 | player_transfer_workflow | `supabase/migrations/20261107230921_player_transfer_workflow.sql` | `9af61ca54ecaeb0d5a329b8e2dd59020556c1740` |
| 20261107230942 | transfer_destinations_empty_for_ineligible | `supabase/migrations/20261107230942_transfer_destinations_empty_for_ineligible.sql` | `d4c7fd4d3b1620116a9e8ccde3917b48fa8f7e30` |
| 20261107231222 | admin_remove_player_from_team | `supabase/migrations/20261107231222_admin_remove_player_from_team.sql` | `c1aeed0458879c43a73d2d13c2704c9d9b9b92cd` |
| 20261107231311 | admin_remove_membership_status_cast | `supabase/migrations/20261107231311_admin_remove_membership_status_cast.sql` | `b4b7ded8d75ac46a20f4078bf0389a9d8b824943` |
| 20261107231424 | retire_legacy_transfer_requests | `supabase/migrations/20261107231424_retire_legacy_transfer_requests.sql` | `76a08c0515ccbd0aa809baffa4f800f89ef557ab` |
| 20261107231600 | finance_v1_manual_ledger | `supabase/migrations/20261107231600_finance_v1_manual_ledger.sql` | `a3e8c940d2d0268d32e9638f569d433666362038` |
| 20261107231622 | finance_ledger_balance_and_method_guard | `supabase/migrations/20261107231622_finance_ledger_balance_and_method_guard.sql` | `0b6405980b76ba1237a4be3434bffa85d7049e0b` |
| 20261107231632 | finance_options_for_finance_roles | `supabase/migrations/20261107231632_finance_options_for_finance_roles.sql` | `ec2ca4bbb34e0075d2eabec2b1dbcfc3d7aac606` |
| 20261107231646 | finance_summary_team_balance_rollup | `supabase/migrations/20261107231646_finance_summary_team_balance_rollup.sql` | `3419b564af3e86b1c1e8663a9c9c70c180b321ef` |
| 20261107231809 | finance_deny_direct_client_access | `supabase/migrations/20261107231809_finance_deny_direct_client_access.sql` | `e4097f346a2060dd3e58ecad89ad2a2e83c27b42` |
| 20261107232025 | admin_audit_history_reader | `supabase/migrations/20261107232025_admin_audit_history_reader.sql` | `59052e189a550d9250b555e40c8463a124de7aaa` |
| 20261107232124 | audit_log_metadata_rpc_only | `supabase/migrations/20261107232124_audit_log_metadata_rpc_only.sql` | `2880f68ab99127a3aef3482759d655c962bc0718` |
| 20261107232144 | audit_log_explicit_deny_policy | `supabase/migrations/20261107232144_audit_log_explicit_deny_policy.sql` | `4c21461ce8f8c2bddaaa040cdd7eb33a04969e6d` |
| 20261107233105 | guarded_notification_dispatch_scheduler | `supabase/migrations/20261107233105_guarded_notification_dispatch_scheduler.sql` | `2c33157cfd2fd6e680297ada3c5c093dd269db8b` |
| 20261107233311 | fixture_goal_records_explicit_deny_policy | `supabase/migrations/20261107233311_fixture_goal_records_explicit_deny_policy.sql` | `ae679e62f88737743c56646ccc539aa9e57ba779` |
| 20261107233439 | index_uncovered_foreign_keys | `supabase/migrations/20261107233439_index_uncovered_foreign_keys.sql` | `dfcd6d17ac2aaa3f59bdbac79b2558fbb6921bb9` |
| 20261107235914 | payment_partial_refund_status | `supabase/migrations/20261107235914_payment_partial_refund_status.sql` | `9a15e3a21891328477360fdd908ffac5aaa5a2ac` |
| 20261107235924 | stripe_player_fixture_checkout | `supabase/migrations/20261107235924_stripe_player_fixture_checkout.sql` | `9f85d9b7902100b1bd84cc2f62e24429c0e70e00` |
| 20261107235943 | payment_service_role_privileges | `supabase/migrations/20261107235943_payment_service_role_privileges.sql` | `c022cc0778d67f0145aed089a48a05a66325fb5b` |
| 20261108001150 | stripe_webhook_processing_lease | `supabase/migrations/20261108001150_stripe_webhook_processing_lease.sql` | `3d534bfe697974b1e799dc234377489b6c7cdd31` |
| 20261108003052 | 20261108040000_restrict_notification_internal_function_execution | `supabase/migrations/20261108003052_restrict_notification_internal_function_execution.sql` | `fd2835a554dd0e3a0c07f07e40a841886605086c` |
| 20261108003244 | 20261108043000_revoke_client_table_bypass_privileges | `supabase/migrations/20261108003244_revoke_client_table_bypass_privileges.sql` | `9ad7d978953fa883033a17726e1ed2787db97730` |
| 20261108003629 | 20261108050000_serialize_player_fixture_payment_creation | `supabase/migrations/20261108003629_serialize_player_fixture_payment_creation.sql` | `fe5a4ea38fd03e9065806fcfb40cad16a107dc0d` |
| 20261108004146 | 20261108060000_limit_self_service_profile_update_columns | `supabase/migrations/20261108004146_limit_self_service_profile_update_columns.sql` | `12224bcf877af11e05e367f8599197b266c8b2ac` |
| 20261108004430 | 20261108070000_require_captain_for_fixture_payment_actions | `supabase/migrations/20261108004430_require_captain_for_fixture_payment_actions.sql` | `a39f516ab32aefbfe8c22fb6c6a15a9179d09c7b` |
| 20261108004633 | 20261108080000_validate_team_membership_approval | `supabase/migrations/20261108004633_validate_team_membership_approval.sql` | `d5137eb4aaf44c9f8f16842181e314d438e00054` |
| 20261108004703 | 20261108090000_serialize_admin_player_team_assignment | `supabase/migrations/20261108004703_serialize_admin_player_team_assignment.sql` | `3eefbd13001d6091a86c7fa81af0c0e263594f16` |
| 20261108004741 | 20261108100000_serialize_transfer_approval | `supabase/migrations/20261108004741_serialize_transfer_approval.sql` | `8c86dcc73faa6e0f6c71d0b1c69ea67bf09febd3` |
| 20261108004806 | 20261108110000_validate_team_registration_captain_approval | `supabase/migrations/20261108004806_validate_team_registration_captain_approval.sql` | `47b4427c98c9a2d4ea155b8ce65cdec9a0b2be67` |
| 20261108005016 | 20261108120000_add_secure_captain_handover | `supabase/migrations/20261108005016_add_secure_captain_handover.sql` | `d13b2fc2cfb99bd6c31468deee961f9d7a895357` |
| 20261108005024 | 20261108121000_restrict_captain_handover_execute | `supabase/migrations/20261108005024_restrict_captain_handover_execute.sql` | `274ca175329218fed73f1cfca87e148d561da192` |
| 20261108010133 | 20261108130000_admin_context_preferences | `supabase/migrations/20261108010133_admin_context_preferences.sql` | `bb9268ecf983dc07ddc9f9a40c264748fde75b15` |
| 20261108010425 | 20261108140000_context_scoped_admin_dashboard | `supabase/migrations/20261108010425_context_scoped_admin_dashboard.sql` | `ef61b1fea79f612a406ebddd760371a24c84e3c8` |
| 20261108010502 | 20261108150000_context_scoped_admin_player_register | `supabase/migrations/20261108010502_context_scoped_admin_player_register.sql` | `ca907d7de32221c7c55035be2fe9ad5c21402cfa` |
| 20261108010634 | 20261108160000_context_scoped_admin_team_sheets | `supabase/migrations/20261108010634_context_scoped_admin_team_sheets.sql` | `ffc6750082fb92a066297631d1871321fa6b7340` |
| 20261108010707 | 20261108170000_context_scoped_admin_transfers | `supabase/migrations/20261108010707_context_scoped_admin_transfers.sql` | `3c7600542951cf7e44233a653d71b9b000f862cb` |
| 20261108010816 | 20261108180000_context_scoped_admin_fixtures | `supabase/migrations/20261108010816_context_scoped_admin_fixtures.sql` | `60297dc9d0ebdbe0ebb85265dd8e778542d0ade7` |
| 20261108011216 | 20261108190000_location_admin_assignments | `supabase/migrations/20261108011216_20261108190000_location_admin_assignments.sql` | `e253328502f84627e15aad9ff42854f962a1f351` |
| 20261108011320 | 20261108200000_enforce_location_admin_scope | `supabase/migrations/20261108011320_enforce_location_admin_scope.sql` | `e77f9aa0c6f513763c8fe9dd8e7ffdc7cb4ccb3a` |
| 20261108011333 | 20261108210000_scope_admin_setup_and_preferences | `supabase/migrations/20261108011333_scope_admin_setup_and_preferences.sql` | `aaef50e5d2dbf83c13cdb5a98ac5d9391e5f3087` |
| 20261108011423 | 20261108220000_expose_admin_scope_type | `supabase/migrations/20261108011423_expose_admin_scope_type.sql` | `c4295a4b905b3b364c605e3cbfc0bc6e79744720` |
| 20261108011516 | 20261108230000_restrict_global_player_identity_reviews | `supabase/migrations/20261108011516_restrict_global_player_identity_reviews.sql` | `e13d999a212d738161a4d811a6693f1baf4cdfa9` |
| 20261108011640 | 20261108240000_admin_location_assignment_search | `supabase/migrations/20261108011640_admin_location_assignment_search.sql` | `cf69fb547abe831c0422b8af3022a52061a280b4` |
| 20261108011751 | 20261108250000_enforce_location_admin_mutation_scope | `supabase/migrations/20261108011751_enforce_location_admin_mutation_scope.sql` | `48afd02b48b9f1b2c9a4f67f5db0fbc3e641ecfc` |
| 20261108011838 | 20261108260000_scope_admin_audit_notifications_and_stats | `supabase/migrations/20261108011838_scope_admin_audit_notifications_and_stats.sql` | `f0646ef97ad324c83f7c60c1331861f81ea2964a` |
| 20261108012459 | 20261108270000_location_scoped_admin_gallery | `supabase/migrations/20261108012459_location_scoped_admin_gallery.sql` | `aee977047c64492400054f5fc9311a283529f1e6` |
| 20261108012537 | 20261108280000_keep_unpublished_gallery_images_private | `supabase/migrations/20261108012537_keep_unpublished_gallery_images_private.sql` | `e235dd430f12dcc88bd72858ce49d2bbbb1f4411` |
| 20261108020706 | player_team_request_status_rpc | `supabase/migrations/20261108020706_player_team_request_status_rpc.sql` | `2cc6ad92429460ee1d23a9f406afe0ad875868bc` |

## Verification notes

- All 98 ledger versions have a corresponding canonical source path in the branch.
- All 101 migration file prefixes are unique: 98 applied ledger versions plus three separate forward-only migrations.
- No duplicate synthetic-prefix copies of applied sources remain in this branch.
- The canonical files are source artifacts only. This manifest does not certify clean-database replay, role behavior, or production release readiness.
- Do not apply any of the already-recorded versions to production.


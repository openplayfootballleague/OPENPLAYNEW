# Supabase migration integrity audit — 2026-11-14

Scope: issue #142 priority workstream (migration integrity). Evidence comes from a clean, isolated replay
(PostgreSQL 16 with Supabase auth/storage/realtime stubs) and the repository verifiers. **No hosted
database was read or changed.** No Supabase connector is attached to this session, so the hosted schema
could not be inspected. The last recorded hosted state is 99 applied migrations through
`20261108194831`, byte-identical to `scripts/verify-migration-source-manifest.mjs`.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Clean replay of every committed migration | 153 migrations apply in order; 0 generated from drafts | local replay harness |
| SQL behavioural tests (CI order) | 41/41 pass | `supabase/tests/*.sql` |
| Security assertions | pass | `scripts/verify-security-assertions.mjs` |
| Applied-source manifest | 99 applied sources unchanged; 54 declared forward-only pending | `verify-migration-source-manifest.mjs` |
| Draft/migration parity | 23 draft-backed migrations byte-identical to drafts | `verify-ci-migration-generation.mjs` |
| Generated types vs schema | match: 61 tables, 221 functions, 9 enums | new `scripts/verify-generated-types.mjs` (now a CI step after the replay) |
| Frontend RPCs | all 148 `.rpc()` names exist and are `authenticated`-executable | replay catalog query |

## Findings and corrections (forward-only; no historical migration edited)

1. **Draft-only migrations with non-deterministic versions (fixed).** Eight drafts had no committed
   migration. CI therefore created them with `supabase migration new`, giving a new version on every run.
   The hosted history could never match that, and replay order depended on CI timing. They are now
   committed as `20261113190000`–`20261113190007`. Each is a byte-identical copy of its draft, in the
   existing CI order. CI now takes its "diff against committed file" branch for them.
   - `referee_approved_report_correction_options`
   - `manual_season_recruitment_activation`
   - `admin_analytics_user_growth`
   - `location_venues_and_operating_hours`
   - `admin_analytics_registration_conversion`
   - `admin_product_analytics_scope`
   - `season_matchday_and_round_robin`
   - `season_completion_recruitment_guards`
2. **Messaging RPCs only in drafts (resolved).** The messaging drafts are identical to the committed
   migration `20261111194000`.
3. **`admin_record_fixture_result_with_appearances` in types without a migration (resolved).** It is
   defined in committed migrations and exists after replay.
4. **Generated types were stale (fixed).** The types file was missing:
   - 28 tables: messaging, referee, team fixture payments, gameweeks, guardian consent, inactivity
     warnings, MOTM and operating costs;
   - 2 columns: `fixtures.gameweek_id` and `player_registration_reviews.match_evidence`;
   - 73 functions, including service-role helpers that `supabase gen types` also emits.

   It also held 2 entries for a superseded integer-gameweek weather implementation
   (`admin_postpone_gameweek_weather` and `get_admin_weather_postponements`). No migration defines them
   since `982f1c73`, and the canonical API is `admin_postpone_gameweek` and
   `get_admin_postponable_gameweeks`; both entries were removed.

   The entries were produced from the replayed catalog because `supabase gen types` needs Docker
   images, which this environment's proxy blocks. Re-run the official generator when it is available.
   The CI verifier keeps names, columns, arguments and enums aligned either way.
5. **Time-of-day test flake (fixed).** `referee_match_reports.sql` and `referee_connect_payouts.sql`
   scheduled fixtures at `now()+N days` against an availability window of 00:00–23:59 with an exclusive
   end, so they failed whenever the suite ran at 23:59 London time. They now use fixed 19:00 London
   kick-offs.
   - Product note, owner decision needed: a referee cannot be available for a 23:59 kick-off, because
     the end time is exclusive and 23:59 is the latest end time that can be entered.
6. **Hosted drift.** This cannot be verified from this session. To compare, run
   `supabase migration list --linked` and `supabase db diff --linked` (read-only) with owner credentials,
   and record the output here.

## Hosted migrations needing owner approval

These 54 forward-only migrations are committed but not recorded as applied on the hosted project. Apply
them only with explicit owner approval, after a backup, in this order, using `supabase db push --include-all`.
`--include-all` is needed because three versions are older than the hosted baseline. Do not edit
already-applied sources.

     1. 20261108021000_captain_next_required_fixture_and_admin_amendment.sql
     2. 20261108150000_canonicalize_player_phone.sql
     3. 20261108160000_enforce_player_ban_and_captain_succession.sql
     4. 20261108220000_restrict_location_activation_to_global_admin.sql
     5. 20261108221000_scope_sensitive_rls_for_location_admins.sql
     6. 20261108221500_remove_platform_wide_location_admin_rls.sql
     7. 20261108222000_revoke_legacy_unscoped_admin_rpcs.sql
     8. 20261108223000_preserve_captain_membership_approval_scope.sql
     9. 20261109080000_player_age_tiers_and_guardian_consent.sql
    10. 20261109100000_player_account_retention_and_reactivation.sql
    11. 20261109110000_competition_identity_and_safe_player_erasure.sql
    12. 20261109130000_admin_player_retention_holds.sql
    13. 20261109140000_prevent_signin_bypass_of_retention.sql
    14. 20261109150000_retry_failed_player_account_erasure.sql
    15. 20261109160000_audit_location_admin_assignments.sql
    16. 20261109170000_points_only_league_table_ranking.sql
    17. 20261109180000_scope_fixture_venue_to_season_location.sql
    18. 20261109200000_scope_admin_result_statistics_to_location.sql
    19. 20261109210000_player_account_inactivity_warnings.sql
    20. 20261109220000_player_season_club_statistics.sql
    21. 20261109230000_player_led_and_emergency_transfer_workflow.sql
    22. 20261110120221_referee_application_workflow.sql
    23. 20261110133643_referee_fixture_assignments.sql
    24. 20261110135038_referee_match_reports.sql
    25. 20261110160000_referee_approved_report_corrections.sql
    26. 20261110190000_restrict_player_identity_review_policy_to_global_admin.sql
    27. 20261110190001_revoke_anon_user_roles_privileges.sql
    28. 20261110193000_admin_disciplinary_return_queue.sql
    29. 20261111190000_team_weekly_payment_workflow.sql
    30. 20261111191000_weather_gameweek_postponements.sql
    31. 20261111192000_referee_connect_payouts.sql
    32. 20261111193000_referee_payout_transfer_outbox.sql
    33. 20261111194000_secure_messaging_platform.sql
    34. 20261111200000_platform_feature_management.sql
    35. 20261111201000_player_self_service_statistics.sql
    36. 20261111203000_optional_goal_attribution.sql
    37. 20261111205000_admin_league_admin_role_management.sql
    38. 20261113100800_referee_connect_transfer_reconciliation_corrections.sql
    39. 20261113130000_finance_operating_costs_and_business_performance.sql
    40. 20261113131500_preserve_historical_admin_team_sheet_players.sql
    41. 20261113140000_serialize_membership_approval_authorization.sql
    42. 20261113141000_fix_admin_contextual_fixture_score_types.sql
    43. 20261113150000_fixture_motm_nominations.sql
    44. 20261113160000_title_final_and_season_completion_guard.sql
    45. 20261113170000_goal_assists_and_own_goals.sql
    46. 20261113180000_season_points_rules.sql
    47. 20261113190000_referee_approved_report_correction_options.sql
    48. 20261113190001_manual_season_recruitment_activation.sql
    49. 20261113190002_admin_analytics_user_growth.sql
    50. 20261113190003_location_venues_and_operating_hours.sql
    51. 20261113190004_admin_analytics_registration_conversion.sql
    52. 20261113190005_admin_product_analytics_scope.sql
    53. 20261113190006_season_matchday_and_round_robin.sql
    54. 20261113190007_season_completion_recruitment_guards.sql

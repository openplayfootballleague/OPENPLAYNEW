# Open Play — Continuous Development Status

**Last verified:** 8 November 2026, 00:03 UTC  
**Repository:** `openplayfootballleague/OPENPLAYNEW`  
**Supabase project:** `ghnrsysvrlgkjmdlwdmp` — Open Play New only  
**Applied database migrations:** 69

## Implemented in this repository and Supabase project

> **Latest session update (8 November 2026, 00:03 UTC):** Stripe test-mode player fixture payments have been added to this repository and deployed to the isolated Open Play New Supabase development project. Two payment migrations plus a backend-permissions follow-up are applied. `create-player-checkout` is active (version 1, JWT required); `stripe-webhook` is active (version 2, Stripe signature verification handled in-function, JWT disabled for webhook delivery). The latest branch includes player checkout/history, finance-admin payment reporting and season player-fee controls. Current CI run [42427960361](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42427960361) passed all 32 tests, Edge Function type-checks, TypeScript/build and Cloudflare dry run on commit `747b3bac668be5e3b61400dd48f6632a86041255`. No checkout has been completed and no test users, teams, fixtures or payments have been created.


### Accounts, registration and access control
- Sign-in returns users to the Player Hub; password-reset emails use the dedicated reset-password route; creating an account does not silently register a player.
- Player registration has a distinct completion state and handoff to the Player Hub.
- Public team registration and membership-request RPCs require authentication and a public season/published league.
- Public discovery tables grant anonymous read access only where RLS limits results to active/published data.
- Authenticated writes are restricted to the intended self-service profile and fixture-availability operations, with self-scoped RLS.
- Anonymous execution of SECURITY DEFINER authorization helpers and notification trigger functions has been revoked. The public RLS policies continue to work for anonymous discovery.

### Captain and team-sheet workflows
- Captains can view availability only for their own active squad.
- Optional squad numbers are managed through an audited RPC; values are limited to 1–99 and unique within the active squad.
- Captains can save and restore partial team-sheet drafts.
- Final team sheets require exactly 6 or 7 starters according to competition format, allow up to 3 or 4 substitutes, require exactly one goalkeeper from the starters, and prevent duplicate player selection.
- Submission locks the sheet in the database. The old RPC signature that bypassed goalkeeper selection was removed.
- The captain UI provides availability context, final review, and explicit confirmation before submission.

### League, fixture and result administration
- Administrators can create locations, leagues, seasons and season-specific teams. New leagues are unpublished and new seasons are draft/private by default.
- Season lifecycle transitions are guarded and audited. Completed/archived seasons cannot accept roster changes.
- Administrators can schedule fixtures, update guarded fixture statuses and record results.
- Both teams must submit and lock their team sheets before a result can be published.
- Each goal must be assigned to a player on the scoring team's submitted sheet. Repeat scorers are allowed; the scorer count must match the score.
- Result corrections require a reason, preserve prior goals as voided history, and are audited.
- The admin result editor has a review screen before publication.

### Player transfers
- Players can request a move to another approved team in the same open/active season. Transfer requests require a reason and are visible to the player in their Player Hub. Players can cancel pending requests.
- Captains cannot transfer until a replacement captain is appointed. Transfers are blocked while the player appears on a locked upcoming team sheet; an administrator must amend that sheet first.
- Administrators can approve or reject transfers with a reason. Approval closes the source membership and activates the destination membership atomically; transfer actions are audited and notify the player.
- Direct client writes to transfer requests are revoked; player and admin actions go through role-guarded RPCs.

### Player database and statistics
- The admin player register supports search by name, email and phone, registration-status filtering and pagination. The routine register omits date of birth and emergency-contact fields.
- Administrators can open a private player detail panel containing date of birth, emergency contact information and team membership history.
- Player name/contact/position corrections require an audit reason. Date of birth is read-only in this workflow.
- Player ban/unban actions require a reason and are audited; banned players cannot be selected on future submitted team sheets.
- `players.is_genuine` defaults to false. An administrator must explicitly classify a registered, non-banned player as genuine before their stats count. Classification changes are audited.
- Admin season statistics derive league standings, starts/substitute appearances, goals, goalkeeper appearances and goalkeeper clean sheets from locked sheets and confirmed results. Season history is derived from public seasons. No manual statistic editing is provided.

### Finance v1 — manual ledger
- Added an append-only team finance ledger for charges, payments received, fines, refunds and credits, with integer-pence amounts, optional fixture/due-date links, manual payment method/reference and internal notes.
- Finance read/write RPCs require `has_finance_access()` (platform admins or finance admins). The ledger table has RLS enabled, an explicit deny-all direct-client policy and no direct table grants.
- Finance entries are audit logged and cannot be edited/deleted; corrections must be recorded as additional entries. Refunds reverse a prior receipt and increase the amount outstanding; credits reduce it. Team overpayments do not offset another team's debt.
- Added an Admin Dashboard link to the Finance Ledger page, with season/team filters, summary totals and manual entry form. The original manual ledger remains append-only and separate from Stripe-backed player payments.
- Database remains empty: finance ledger contains 0 rows. Finance role acceptance testing needs an owner-approved test identity; do not grant finance roles or create accounts without approval.

### Finance v2 — Stripe test-mode player fixture payments
- Extended the existing `payment_records` table (no duplicate ledger) with player ownership, refund totals, Stripe fee/net fields, webhook event timestamps and checkout retry counter. Added the `partially_refunded` payment status in its own earlier migration so PostgreSQL commits the enum before dependent functions use it.
- Server-side `create_player_fixture_payment` uses `auth.uid()`, requires an approved/non-banned player and active membership in one of the fixture's teams, checks the fixture is payable, reads the season/gameweek player fee from `season_fee_configs`, and snapshots the amount. The browser cannot supply the amount.
- Added `admin_set_player_fixture_fee` for finance roles, with effective gameweek, validation and audit logging. Existing team fee settings are preserved when a player fee is added.
- Added `get_my_fixture_payments` for a player's own history and `get_admin_stripe_payments` for finance-authorised reporting. Direct payment-table writes are revoked from clients; authenticated users retain SELECT subject to the existing finance/captain RLS policy; the service role has explicit backend CRUD privileges.
- Added hosted Checkout Edge Function `create-player-checkout` (ACTIVE, version 1, JWT required). It accepts fixture/team IDs only, authenticates the player, reads the server-created amount and refuses any Stripe secret not prefixed `sk_test_`.
- Added `stripe-webhook` Edge Function (ACTIVE, version 2, JWT disabled because Stripe calls it directly). It verifies timestamped HMAC signatures, rejects live-mode events, records/retries event IDs, updates paid/failed/cancelled/refund states, and fetches Stripe balance transactions to record processing fees and net proceeds.
- Player Hub includes fixture payment actions, checkout return messaging and personal payment history. Finance page includes the Stripe payment register and season-specific player fee settings. Checkout success is not treated as proof of payment; only the verified webhook changes payment state.
- GitHub PR [#6](https://github.com/openplayfootballleague/OPENPLAYNEW/pull/6) remains open/draft and unmerged. Stripe secrets are not committed. No test-mode secret key, webhook signing secret or confirmed app origin has been configured in Supabase Edge Function secrets. No Stripe webhook endpoint has been registered yet.
- Verification: latest completed full CI at commit `c53233b36807a9287d71ea9317b6c85489757ab6` passed 32 tests, Deno type-checks, TypeScript/build and Cloudflare dry run. The current head `747b3bac668be5e3b61400dd48f6632a86041255` passed full CI run [42427960361](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42427960361). SQL smoke checks confirmed unauthenticated payment creation is rejected, unauthenticated finance access is false, own-history RPC returns zero rows when unauthenticated, and finance-only RPCs reject unauthorised calls.
- No Auth users, players, teams, fixtures, payment records or webhook events have been created. The user explicitly authorised disposable test accounts and Stripe test-mode testing, but the available Supabase connector exposes neither Auth Admin user creation/deletion nor Edge Function secret management. These actions must use an approved Supabase Dashboard/CLI path before full end-to-end testing.

### Administrator help and guided walkthrough
- Added a platform-admin-only operations guide at `/admin-help`, linked from the Admin Dashboard.
- The guide covers competition setup, player/team registration review, memberships, fixtures, team sheets/results, corrections, transfers, finance, notifications and audit history.
- Added an interactive 11-step guided walkthrough with progress, next/back, finish and exit controls. Access is checked through the protected platform-role helper; failed checks show a restricted state.

### Administrator audit history
- Added a searchable, paginated audit-history reader for platform administrators.
- The UI shows event action, entity type/ID, actor ID, timestamp and reason. It deliberately omits private `before_data` and `after_data` payloads.
- Direct `SELECT` on `audit_log` has been revoked from anonymous and authenticated clients, and an explicit deny-all RLS policy blocks direct access. The metadata RPC checks `has_platform_role()`; its execute grant is authenticated-only.
- The permission check confirms anonymous direct read and RPC execution are denied, authenticated direct read is denied, and authenticated RPC execution is granted. Actual admin-session page acceptance still needs an owner-approved test identity.

### Notifications
- Player Hub includes an in-app notification feed and notification preferences.
- Email and in-app notifications default on; SMS defaults off and requires explicit opt-in. SMS consent and revocation timestamps/version are stored and preference changes are audited. Direct client table updates are revoked; preferences are changed through the RPC.
- Database triggers enqueue notifications for team/member approvals, fixture scheduling/status changes and published/corrected results.
- The notification outbox tracks attempts, backoff, provider errors, holds, one manual retry, and unconfirmed delivery outcomes. Admin actions are audited.
- A JWT-verified Supabase Edge Function `deliver-notifications` is deployed (version 8; `verify_jwt=true`). It supports Resend email and Twilio SMS, checks admin/service-role access, claims only configured channels, distinguishes permanent provider/recipient errors from transient failures (non-retryable 4xx are terminal; 408/429/5xx remain retryable), and avoids blindly retrying a provider-accepted but unconfirmed message. The permanent-error classifier is shared with unit tests and the Edge Function is Deno type-checked in CI. Player ban/unban changes also generate notifications.
- A `pg_cron` job named `open-play-fixture-reminders` is active every 15 minutes. It enqueues idempotent 24-hour and 3-hour fixture reminders and cancels stale queued/in-app reminders when a fixture is moved or cancelled.
- A separate `open-play-notification-dispatch` minute job uses `pg_net` to invoke the Edge Function, but is **inactive by default**. Its database setting is `enabled=false`; the dispatcher function returns `NULL` without queuing an HTTP request while disabled. The Admin Dashboard exposes a guarded control to enable/disable it. Enabling requires Vault secrets `open_play_supabase_url` and `open_play_service_role_key`, a reason, and an explicit confirmation that Resend/Twilio provider secrets are configured and approved. Current Vault secret count is zero; cron is inactive; notification outbox is empty; no messages were sent.
- Added `pg_net` and a second minute-level `pg_cron` job, `open-play-notification-dispatch`, which invokes the Edge Function through a server-side worker. It is deliberately inactive by default; the settings row is `enabled=false` and the cron job is `active=false`.
- The Admin Dashboard now shows dispatch readiness and offers an audited enable/disable control. Enabling requires both `open_play_supabase_url` and `open_play_service_role_key` in Supabase Vault, a 10-character reason, and an explicit confirmation that Resend/Twilio Edge Function secrets are configured and approved for real delivery. Only platform administrators can change it.
- Verified the worker function returns `NULL` while disabled (no HTTP request queued), the cron job is inactive, Vault currently contains zero secrets, and the notification outbox contains zero events. No email or SMS was sent.

## Verification evidence

- GitHub Actions run [42422744988](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42422744988) passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run for the season-statistics dashboard.
- GitHub Actions run [42422509183](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42422509183) passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run for scorer validation and result review.
- Earlier team-sheet, RLS, admin setup and fixture changes also passed their respective CI runs.
- GitHub Actions run [42424034083](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42424034083) passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run after correcting a literal newline escape in the admin route introduced during transfer-queue work.
- GitHub Actions run [42424065363](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42424065363) passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run for Player Hub transfer decision notification copy. The successful run includes the player transfer UI, admin review queue and notification rendering.
- GitHub Actions run [42424234675](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42424234675) passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run for admin membership removal.
- GitHub Actions run [42424344218](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42424344218) passed all 15 domain tests, TypeScript check, production build and Cloudflare Worker dry run for match appearance capture and goalscorer eligibility.
- GitHub Actions run [42424703489](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42424703489) passed all 20 tests, TypeScript check, production build and Cloudflare Worker dry run for the finance ledger. The follow-up sign-in navigation link is in a separate CI run.
- GitHub Actions run [42425449833](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42425449833) passed all 32 tests, Deno type-check for the notification Edge Function, TypeScript check, production build and Cloudflare Worker dry run. The corrected notification worker was deployed to the separate Open Play New Supabase project as version 8 with JWT verification still enabled.
- GitHub Actions run [42425666119](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42425666119) passed all 32 tests, Deno Edge Function type-check, TypeScript check, production build and Cloudflare Worker dry run for the guarded automatic-dispatch controls.
- GitHub Actions run [42425770535](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42425770535) passed all 32 tests, Deno Edge Function type-check, TypeScript check, production build and Cloudflare Worker dry run after adding an explicit deny-all RLS policy to the final sensitive goal-record table.
- GitHub Actions run [42425944340](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42425944340) passed all 32 tests, Deno Edge Function type-check, TypeScript check, production build and Cloudflare Worker dry run after updating the administrator guide with the exact Vault and provider secret names.
- GitHub Actions run [42424849096](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42424849096) passed the 20-test suite, TypeScript check, production build and Cloudflare Worker dry run for the administrator audit-history UI.
- GitHub Actions run [42425103732](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42425103732) passed all 20 tests, TypeScript check, production build and Cloudflare Worker dry run for the guided admin help walkthrough and access-check error handling.
- The season-statistics SQL was executed against the empty project and returned the expected empty result sets/zero summary. Real-data calculations still need acceptance testing.
- Supabase health advisor: no findings.
- Transfer and membership write-surface verification: anonymous transfer-table SELECT is denied; authenticated direct INSERT/UPDATE on transfer requests and team memberships is denied. Authenticated users can SELECT transfer requests under owner/admin RLS, and must use guarded RPCs to request, cancel, resolve or amend memberships.
- Supabase security advisor: no anonymous-callable SECURITY DEFINER warnings and no RLS-without-policy INFO findings remain. It reports 59 authenticated-callable SECURITY DEFINER functions; the linter flags these regardless of internal guards. A structural review found all `admin_*` RPCs check `has_platform_role()` or `has_finance_access()`, while self-service/captain RPCs scope to `auth.uid()` or active captain membership. The four finance RPCs check `has_finance_access()`; the audit-history and dispatch-control RPCs check `has_platform_role()`.
- Sensitive tables `fixture_goal_records`, `finance_entries`, and `audit_log` all have explicit deny-all direct-client RLS policies and no anon/authenticated table grants; privileged reads/writes occur through guarded RPCs.
- The performance advisor reports unused indexes and permissive-policy notices. Do not drop indexes or weaken RLS without workload and access-model review.
- Reminder enqueue smoke test returned 0, as expected: there are no fixtures or users in this project.
- Current database counts: 0 Auth users, 0 players, 0 fixtures, 0 notification preferences and 0 notification events. No demo or production data has been inserted.
- GitHub Actions run [42424034083](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42424034083) passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run for the player transfer request UI and administrator review queue. The transfer notification-copy follow-up is currently in CI.
- Notification delivery has not been end-to-end tested. No Resend/Twilio credentials or Supabase Vault invocation secrets are configured and no real email/SMS has been sent. The 15-minute cron job enqueues reminders; a separate minute-level dispatch job is installed but deliberately inactive until an authorised platform administrator enables it after credential setup and explicit confirmation.

## Environment boundary

Separate Open Play reports in the Library document substantial Stage 2–4 work in an isolated Lovable draft, including prior admin screens and notification flows. Those reports are not proof that those changes exist in this GitHub repository or Supabase project. This `OPENPLAYNEW` project is a separate empty environment; no production records or draft test data have been copied. The live Lovable app and this repository must not be treated as interchangeable.

## Performance review
- Added covering indexes for all 11 foreign-key columns flagged by the Supabase performance advisor. The `unindexed_foreign_keys` finding is now clear.
- The advisor still reports 50 unused indexes because this project is empty and has no production workload; retain them until real query usage is available rather than removing planned indexes prematurely.
- 15 multiple-permissive-policy warnings remain where admin-manage policies overlap with self/public/captain access policies. These were left unchanged to avoid altering RLS semantics before authenticated acceptance tests; review consolidation once test identities and representative data are available.

## Remaining launch blockers

1. Complete browser acceptance tests for player detail, correction, ban/unban, genuine classification, player transfers, finance ledger, admin audit history and the help walkthrough.
2. The owner has authorised disposable non-production test identities and their removal after testing. Use a secure Supabase Auth Admin mechanism; current connector tooling cannot create/delete Auth users, so use the Dashboard/CLI once an authorised path is available. Do not self-appoint an administrator.
3. Test the complete sign-up, email verification, sign-in, password reset, player registration, team registration, membership request and captain approval journey.
4. Test saved team-sheet drafts, goalkeeper selection, final submission/locking, admin amendment and result publication/correction with realistic test fixtures.
5. Configure Resend and Twilio credentials, verify sender/domain and SMS sender configuration, then test consent, delivery, failure, retry, hold, unconfirmed and opt-out handling with approved test recipients. The Supabase Vault currently contains no secrets; provider credentials and the service-role invocation secret are not configured.
6. Configure the Resend/Twilio Edge Function secrets and the two Supabase Vault invocation secrets, run controlled delivery tests, then obtain explicit owner approval to enable the minute-level dispatch job. The schedule is implemented but remains inactive by default.
7. Test 24-hour and 3-hour reminders with fixtures and users; verify rescheduling/cancellation invalidates stale reminders. Test the transfer request/approval/rejection flow with two approved teams in one test season.
8. Finish remaining admin operations and the full matchday lifecycle. The admin help guide and step-by-step walkthrough are implemented. Stripe Checkout foundations and player/finance UI are now present in PR #6, but test-mode secrets, webhook registration, end-to-end checkout/refund tests, admin refund controls and payout reconciliation remain outstanding. Complete finance-role acceptance and comprehensive security testing.
9. Merge/reconcile the PWA and official OP branding changes, then complete real-device install/cache testing.
10. Owner-verify Bideford league, season, venue, team and fixture data before any production seeding. Bideford is the only launch location; Barnstaple and Torrington remain inactive.
11. Configure production environment variables, Auth redirects, email confirmation, hosting and monitoring. Production deployment has not occurred; CI has only run a Cloudflare Worker dry run.

## Next execution priority

Complete approved finance-role, audit-history, admin-help and player-database acceptance tests. Continue with the full matchday lifecycle and authenticated end-to-end tests. Keep production deployment blocked until the owner-approved test identities, provider configuration, real Bideford data and launch checks are complete.

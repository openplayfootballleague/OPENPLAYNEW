# Open Play — Continuous Development Status

**Last verified:** 8 November 2026, 00:22 UTC  
**Repository:** `openplayfootballleague/OPENPLAYNEW`  
**Supabase project:** `ghnrsysvrlgkjmdlwdmp` — Open Play New only  
**Applied database migrations:** 69

## Implemented in this repository and Supabase project

> **Latest session update (8 November 2026, 00:18 UTC):** Hardened Stripe webhook duplicate-delivery handling. Added `processing_started_at` and an index to `stripe_webhook_events`; the migration is applied to the isolated development database. The webhook now atomically claims unprocessed events, returns a retryable HTTP 409 when another worker holds the five-minute lease, releases the lease after recorded processing failures, and clears it on success. The updated `stripe-webhook` is deployed to the development project as ACTIVE version 3 (`verify_jwt=false`). Current CI runs [42428637941](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42428637941) and [42428645678](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42428645678) were triggered by the migration and function commits and are being verified. No signed Stripe event has yet been replayed against the configured endpoint; secrets and webhook registration remain unconfigured.


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
- The Finance page includes the Stripe payment register and season-specific player fee settings. General Player Hub payment controls have been removed. The Captain Hub currently has no Stripe payment action UI; captain-only payment presentation and the correct payer model must be settled before checkout can be enabled. Checkout success is not treated as proof of payment; only the verified webhook changes payment state.
- GitHub PR [#6](https://github.com/openplayfootballleague/OPENPLAYNEW/pull/6) remains open/draft and unmerged. Stripe secrets are not committed. No test-mode secret key, webhook signing secret or confirmed app origin has been configured in Supabase Edge Function secrets. No Stripe webhook endpoint has been registered yet.
- Verification: current PR head `b37852cb6509d86d02e16487effdee23ce7a3343` passed full CI run [42428405414](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42428405414). Earlier SQL smoke checks confirmed unauthenticated payment creation is rejected, unauthenticated finance access is false, own-history RPC returns zero rows when unauthenticated, and finance-only RPCs reject unauthorised calls. These are not substitutes for authenticated end-to-end checkout/refund tests.
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


## 8 November 2026 — player-facing visual foundation progress

- Added the permanent visual authority and implementation/acceptance specification at `docs/player-facing-visual-design-master-specification.md` (commit `7eea1bf21a2ac81e38b547e410b033d22668dbd6`).
- Added the `player-facing` scope to Player Hub, Captain Hub, Match Centre, Teams, Join, sign-in, sign-up, player registration and password-reset routes. This allows the new visual system to be isolated from the public marketing site and Admin Dashboard.
- Added Oswald and Inter font loading and scoped player-facing design tokens: black/charcoal surfaces, white/grey text, #FF6500 accent, dark cards/inputs and orange focus outlines. Existing global typography and public/admin styles were not globally replaced.
- Verified GitHub Actions success for route commits `5930acd1`, `455d5f6b`, `a4261916`, `2191d68d` and stylesheet commit `dab8a4cc`. Workflow runs: `42429035522`, `42429042008`, `42429048694`, `42429059233`, `42429074635` respectively. These are build/typecheck CI results, not visual/browser acceptance.
- Retrieved and visually inspected the Library asset named `Connected Orange OP Monogram.png`. It is the orange connected OP mark on black and is a candidate source for the official asset. It is not yet committed to the repository. The repository tree currently contains only `public/favicon.svg` among image assets; therefore do not point UI code at a nonexistent logo path or substitute a recreated mark. Next asset task is to transfer the exact original bytes into the repository using a supported binary upload route, then implement the shared clickable logo header. The image source is the Library asset, not a newly generated logo.
- Remaining visual work: shared header and bottom navigation, standardised reusable cards/buttons/tables/status components, route-by-route styling, mobile/tablet/desktop screenshot review, exact logo integration, and functional regression testing.
- Team badge upload/background removal/quality-review workflow remains unimplemented. Do not publish low-confidence processed badges.
- Stripe work remains test-mode only; captain payer semantics are unresolved and checkout remains unavailable until the payer model is decided.
- Admin Dashboard remains excluded from player-facing visual CSS scope.


## 8 November 2026 — route-state styling consistency

- Audited all player-facing route render states and found secondary/error/empty/loading branches in Join, Captain Hub, player registration and password reset that still used the unscoped `notice-page` class. This meant those states could fall back to the legacy light panel instead of the approved dark player-facing system.
- Updated every `notice-page` main element in those four routes to include `player-facing`. This is CSS scoping only; no route guards, data access, workflows or business logic changed.
- Verified by refetching all four source files: Join has 4 scoped main states, Captain Hub 2, player registration 3 and password reset 2; none of these files retains an unscoped `notice-page` main.
- GitHub Actions build verification runs 42429529130 and 42429537132 were still in progress at the time of this update. Do not count these changes as CI-passed until those runs complete successfully.
- The previous visual-foundation build run 42429350785 completed successfully. This does not substitute for browser/device visual acceptance.


## 8 November 2026 — player-facing component styling expansion

- Extended the scoped player-facing design system to cover match rows and scores, public team-directory cards, captain request and availability rows, fixture selection controls, league tables, form validation states, and disabled/selected button states.
- Added responsive table handling and mobile panel adjustments. Styling is scoped under `.player-facing`; public marketing pages, Finance and Admin Dashboard are not intentionally restyled.
- This is presentation-only CSS. No business logic, permissions, routes, Supabase policies or payment behaviour changed.
- Prior route-state consistency commits all passed GitHub Actions: runs 42429529130 (Captain Hub), 42429537132 (password reset), and 42429580279 (status documentation).
- CSS expansion commit: `559fef809eb4f94f066691de1aad237980a15173`. CI status for this exact commit must be checked before treating it as verified.
- The exact official logo and shared navigation remain blocked on safe transfer of the supplied binary asset. No substitute logo or fabricated icon package was introduced.


## 8 November 2026 — shared player bottom navigation

- Added `src/components/player-bottom-navigation.tsx`, a shared four-destination navigation component (Player Hub, Match Centre, Teams, Join Open Play). It uses inline accessible SVG icons and TanStack Router links; no new icon dependency was introduced.
- Integrated the shared navigation into Player Hub, Captain Hub, Match Centre, Teams and Join Open Play.
- Added fixed safe-area-aware mobile navigation styling and a centered compact desktop navigation treatment. Main page bottom padding is increased only when the navigation is present.
- The navigation is also being added to sign-in, sign-up, player-registration and password-reset flows; these route updates were made during this execution session and require CI confirmation.
- The user supplied the exact connected orange OP mark again in this session (1254×1254 RGBA PNG, 459,212 bytes). It is confirmed as the canonical logo reference. The asset is not yet in the Git repository: the available GitHub binary blob API accepts base64 text but this execution environment does not expose the local uploaded file bytes to that connector action. No lossy recreation or external-host substitution was made.
- The bottom-navigation component commit `fa5418a9377479ece2637c9e8da90211b44ea861` passed CI run 42429786708. The first route integrations passed CI runs 42429794337 (Teams), 42429804062 (Captain Hub) and the initial CSS run was pending at time of writing. Remaining route/style CI runs: 42429813808, 42429821498 and 42429828850; confirm before declaring the entire navigation change green.
- Browser-based visual acceptance has not yet been performed. Public marketing homepage and Admin Dashboard remain unchanged.


## 8 November 2026 — navigation CI and database advisor review

- Confirmed the documentation commit for the shared navigation passed CI run 42429873263.
- Completed the shared navigation integration on sign-in, sign-up, player-registration and password-reset routes. Latest commits: `191c6689f58fed8bb5f7cbf65df304949d3b7830` and `1b1b534043b161b90c6c318861b80e489e148348`. These final two route commits are awaiting their own CI runs at the time of this update.
- Supabase security and performance advisors were run against development project `ghnrsysvrlgkjmdlwdmp`.
- Security advisor reported 63 SECURITY DEFINER functions executable by authenticated users. Inspection of representative definitions confirms they include explicit in-function authorization checks (e.g. `has_platform_role()`, `has_finance_access()`, `is_active_team_captain()`, or `auth.uid()` ownership checks); the linter warning is not by itself proof of an authorization bypass. Anonymous execution was false for the inspected function set. A full per-function authorization review is still required before production.
- Performance advisor reports multiple permissive RLS policies on 15 tables and 51 unused indexes. These are review candidates, not safe automatic cleanup: several permissive policies deliberately combine admin management with player/captain access, and unused indexes may be useful under real workload. No policies or indexes were changed.
- A first attempt to call the advisor without its required `type` parameter failed validation and made no database changes; both subsequent typed advisor calls succeeded.
- No production configuration, live payments, or production data were changed.


## 8 November 2026 — notification function execution hardening

- Investigated the Supabase security advisor's SECURITY DEFINER warnings by querying all 78 public SECURITY DEFINER functions in the development project.
- Confirmed none of the 78 inspected functions were executable by the `anon` role. Fifteen notification dispatch/trigger functions were nevertheless callable by `authenticated` without user-facing authorization checks; these are internal worker, scheduler, enqueue-helper, and database-trigger functions.
- Added migration `20261108040000_restrict_notification_internal_function_execution.sql` and applied it successfully to development. It revokes EXECUTE from PUBLIC, anon and authenticated for the 15 internal notification functions, preserving existing service_role grants on the worker RPCs.
- Post-migration privilege query verified all 15 are no longer executable by anon or authenticated. Service-role access remains enabled where it was already granted for the worker RPCs. Database trigger functions remain attached to their triggers.
- No production changes. No user notifications were dispatched during this permission change.
- CI for the navigation route changes and preceding documentation commits is green (runs 42429967967 and 42429943236 both successful). The security migration has been applied to dev; CI for its repository migration commit is pending.
- Remaining security review: the other SECURITY DEFINER functions need per-function verification of authorization semantics, and the full RLS policy set still needs review.


## 8 November 2026 — public table privilege hardening

- Completed a direct privilege/RLS inventory of all 24 public application tables and 50 public RLS policies in the development database. RLS was enabled on all 24 inspected tables.
- The inventory exposed a separate high-priority issue: the Supabase default table grants included `TRUNCATE`, `REFERENCES` and `TRIGGER` privileges for anon/authenticated on public application tables. These privileges are not constrained by row-level security in the same way as ordinary row operations; in particular, TRUNCATE bypasses row policies.
- Added and applied migration `20261108043000_revoke_client_table_bypass_privileges.sql`. It revokes those three privileges from anon and authenticated on all existing public tables and updates the postgres role's default privileges in the public schema to prevent them being reintroduced for future tables.
- Verified with `has_table_privilege` across all public tables: zero tables remain where anon or authenticated can TRUNCATE, declare REFERENCES, or create TRIGGER privileges.
- Existing SELECT/INSERT/UPDATE/DELETE grants were not changed; row access remains controlled by the existing RLS policies. No application feature permissions were broadened.
- The earlier notification internal-function permission migration is also applied and verified. Its CI run 42430099570 passed. The follow-up documentation CI run is still pending at the time of this entry.
- This is development-project hardening only. The same migrations must be reviewed and applied through the production release process after staging/acceptance verification; production was not modified.


## 8 November 2026 — repeatable database security assertions

- Added `supabase/tests/security_privilege_assertions.sql` with executable assertions that: every public application table has RLS enabled; anon/authenticated have no TRUNCATE, REFERENCES or TRIGGER privileges on public tables; anon cannot execute public SECURITY DEFINER functions; and authenticated cannot execute the 15 internal notification worker/trigger functions.
- Executed the assertions against development immediately after the privilege migrations. Result: `security privilege assertions passed`.
- These are explicit database regression assertions, not a substitute for full user-role integration testing. Authenticated SECURITY DEFINER functions that remain callable must continue to be reviewed for their in-function ownership/role checks.


## 8 November 2026 — follow-up verification and authorization review

- Confirmed GitHub Actions runs 42430240761 (table privilege migration), 42430255406 (security-hardening documentation), 42430282251 (security assertion file) and 42430288933 (follow-up documentation) all completed successfully.
- Re-ran Supabase security advisor after restricting internal notification execution and table-level client privileges. It continues to report 63 authenticated-executable SECURITY DEFINER functions. These are largely deliberate user-facing/admin RPCs, and the advisor warning is intentionally retained for review rather than suppressed.
- Inspected the sensitive team-management functions `resolve_team_membership_request`, `set_team_squad_number`, `save_team_sheet_draft` and `submit_team_sheet`. They validate authenticated actor identity and require platform-admin or active-captain rights scoped to the relevant team; team-sheet writes additionally validate fixture participation, roster membership, player eligibility, duplicate selection, goalkeeper selection, and lock state.
- Inspected admin player register, finance ledger/summary, Stripe ledger and admin team-sheet read RPCs. They check platform or finance roles before returning privileged records.
- The remaining 63 SECURITY DEFINER functions still need an exhaustive structured authorization and data-minimization review; this targeted inspection is not a blanket sign-off.
- The user-uploaded canonical orange connected OP logo is present in the current working container and visually confirmed. The repository connector does not provide a direct binary-file bridge from that local path into GitHub; only UTF-8 file writes and base64 text blobs are available. No substitute logo was committed.
- No production changes, no test users or payment records seeded, and no live Stripe configuration.


## 8 November 2026 — payment creation concurrency hardening

- Review of the 63 authenticated-executable SECURITY DEFINER RPCs found the payment-record creation path relied on a SELECT FOR UPDATE of a possibly absent row. The partial unique index prevented duplicate records, but concurrent first-time requests could still race and return a uniqueness error rather than the existing pending payment.
- Added and applied `20261108050000_serialize_player_fixture_payment_creation.sql`. It acquires a transaction-scoped advisory lock keyed by the authenticated player and fixture before checking/creating the payment record. The existing partial unique index remains the final integrity guard.
- Verified the deployed development function definition contains `pg_advisory_xact_lock`; anon execution remains false and authenticated execution remains true, with the function's own authenticated-membership validation retained.
- Reworked `supabase/tests/security_privilege_assertions.sql` into a plain SQL result set to avoid procedural-block delimiter ambiguity in the SQL execution runner. Executed it successfully; all five assertions returned true, including the payment-creation serialization check.
- The full 63-function review is still open. This pass specifically validated captain-scoped team sheet and membership functions, finance/admin read RPCs, and player payment ownership. No claim of exhaustive authorization sign-off is made.

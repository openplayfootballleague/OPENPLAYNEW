# Open Play — Continuous Development Status

**Last verified:** 7 November 2026, 23:09 UTC  
**Repository:** `openplayfootballleague/OPENPLAYNEW`  
**Supabase project:** `ghnrsysvrlgkjmdlwdmp` — Open Play New only  
**Applied database migrations:** 50

## Implemented in this repository and Supabase project

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

### Player database and statistics
- The admin player register supports search by name, email and phone, registration-status filtering and pagination. The routine register omits date of birth and emergency-contact fields.
- Administrators can open a private player detail panel containing date of birth, emergency contact information and team membership history.
- Player name/contact/position corrections require an audit reason. Date of birth is read-only in this workflow.
- Player ban/unban actions require a reason and are audited; banned players cannot be selected on future submitted team sheets.
- `players.is_genuine` defaults to false. An administrator must explicitly classify a registered, non-banned player as genuine before their stats count. Classification changes are audited.
- Admin season statistics derive league standings, starts/substitute appearances, goals, goalkeeper appearances and goalkeeper clean sheets from locked sheets and confirmed results. Season history is derived from public seasons. No manual statistic editing is provided.

### Notifications
- Player Hub includes an in-app notification feed and notification preferences.
- Email and in-app notifications default on; SMS defaults off and requires explicit opt-in. SMS consent and revocation timestamps/version are stored and preference changes are audited. Direct client table updates are revoked; preferences are changed through the RPC.
- Database triggers enqueue notifications for team/member approvals, fixture scheduling/status changes and published/corrected results.
- The notification outbox tracks attempts, backoff, provider errors, holds, one manual retry, and unconfirmed delivery outcomes. Admin actions are audited.
- A JWT-verified Supabase Edge Function `deliver-notifications` is deployed (version 5). It supports Resend email and Twilio SMS, checks admin/service-role access, claims only configured channels, distinguishes permanent provider/recipient errors from transient failures, and avoids blindly retrying a provider-accepted but unconfirmed message. Player ban/unban changes also generate notifications.
- A `pg_cron` job named `open-play-fixture-reminders` is active every 15 minutes. It enqueues idempotent 24-hour and 3-hour fixture reminders and cancels stale queued/in-app reminders when a fixture is moved or cancelled.

## Verification evidence

- GitHub Actions run [42422744988](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42422744988) passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run for the season-statistics dashboard.
- GitHub Actions run [42422509183](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42422509183) passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run for scorer validation and result review.
- Earlier team-sheet, RLS, admin setup and fixture changes also passed their respective CI runs.\n- GitHub Actions run [42424034083](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42424034083) passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run after correcting a literal newline escape in the admin route introduced during transfer-queue work.\n- GitHub Actions run [42424065363](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42424065363) passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run for Player Hub transfer decision notification copy. The successful run includes the player transfer UI, admin review queue and notification rendering.
- The season-statistics SQL was executed against the empty project and returned the expected empty result sets/zero summary. Real-data calculations still need acceptance testing.
- Supabase health advisor: no findings.
- Supabase security advisor: no anonymous-callable SECURITY DEFINER warnings remain. It reports 45 authenticated-callable SECURITY DEFINER functions; a source scan confirmed each includes an identity, role or service-role check. Keep a manual review of those guards in the launch security checklist.
- One RLS INFO finding remains for `fixture_goal_records`: RLS is enabled with no direct client policies intentionally; goal history is accessed through role-guarded admin/statistics RPCs.
- The performance advisor reports unused indexes and permissive-policy notices. Do not drop indexes or weaken RLS without workload and access-model review.
- Reminder enqueue smoke test returned 0, as expected: there are no fixtures or users in this project.
- Current database counts: 0 Auth users, 0 players, 0 fixtures, 0 notification preferences and 0 notification events. No demo or production data has been inserted.
- The admin player-detail UI build initially failed on nullable RPC argument types. The latest fix changed those arguments to typed strings; GitHub Actions run [42423640387](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42423640387) then passed all 12 domain tests, TypeScript check, production build and Cloudflare Worker dry run. Later notification/template/type changes are under a subsequent CI run.
- Notification delivery has not been end-to-end tested. No Resend/Twilio credentials have been configured in this session, no real email/SMS has been sent, and automated dispatch scheduling is not configured. The 15-minute cron job enqueues reminders only; an administrator can invoke the delivery worker after provider secrets are configured.

## Environment boundary

Separate Open Play reports in the Library document substantial Stage 2–4 work in an isolated Lovable draft, including prior admin screens and notification flows. Those reports are not proof that those changes exist in this GitHub repository or Supabase project. This `OPENPLAYNEW` project is a separate empty environment; no production records or draft test data have been copied. The live Lovable app and this repository must not be treated as interchangeable.

## Remaining launch blockers

1. Complete the current admin player-detail build and run browser acceptance tests for player detail, correction, ban/unban and genuine classification.
2. Obtain an owner-approved non-production test identity, an approved admin test identity and an accessible mailbox. Do not self-appoint an administrator or create test accounts without authorization.
3. Test the complete sign-up, email verification, sign-in, password reset, player registration, team registration, membership request and captain approval journey.
4. Test saved team-sheet drafts, goalkeeper selection, final submission/locking, admin amendment and result publication/correction with realistic test fixtures.
5. Configure Resend and Twilio credentials, verify sender/domain and SMS sender configuration, then test consent, delivery, failure, retry, hold, unconfirmed and opt-out handling with approved test recipients.
6. Configure an automatic delivery invocation schedule. The current cron schedule enqueues fixture reminders but does not dispatch email/SMS.
7. Test 24-hour and 3-hour reminders with fixtures and users; verify rescheduling/cancellation invalidates stale reminders.
8. Finish remaining admin operations and the full matchday lifecycle, payments/Stripe and verified webhooks, reconciliation/refunds, and comprehensive security/acceptance testing.
9. Merge/reconcile the PWA and official OP branding changes, then complete real-device install/cache testing.
10. Owner-verify Bideford league, season, venue, team and fixture data before any production seeding. Bideford is the only launch location; Barnstaple and Torrington remain inactive.
11. Configure production environment variables, Auth redirects, email confirmation, hosting and monitoring. Production deployment has not occurred; CI has only run a Cloudflare Worker dry run.

## Next execution priority

Finish and verify the current Player Hub transfer notification build. Then add player-database acceptance tests and continue with authenticated end-to-end tests. Keep production deployment blocked until the owner-approved test identities, provider configuration, real Bideford data and launch checks are complete.

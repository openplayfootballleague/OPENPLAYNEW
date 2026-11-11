# Phase 1 final audit checklist

Status: **Latest automated CI fully green — manual audit and release prerequisites remain open**

Scope: Open Play New Phase 1 registration safeguards, identity/consent controls, player access restrictions, account retention and permanent competition-history preservation.

This checklist is the release gate for Phase 1. A section is not complete merely because code exists; it requires source review and passing evidence. No production migration, Edge Function deployment, merge or unattended retention activation is authorised by this checklist.

## 1. Automated verification

- [x] Earlier Phase 1 implementation state passed application build, Deno checks, domain tests, Edge Function/navigation assertions, Cloudflare dry-run, clean migration replay and SQL/Auth lifecycle suites in [#1424](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42646379541).
- [x] Latest audit corrections fully passed in [#1537](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42687671582). Both build and database jobs are green: canonical migration source manifest, Edge Function security configuration, viewer navigation assertions, Deno type-check, domain tests, app build, Cloudflare dry-run, clean migration replay, hosted migration-order verification, RLS/security assertions, finance/location rules, age and guardian consent, retention/reactivation/holds, permanent competition identity and erasure, captain next-fixture/post-match amendments, and Auth signup/email confirmation/password recovery.
- [x] Clean local Supabase migration replay succeeds from an empty database.
- [x] Migration source manifest matches the actual migration files and Git blobs.
- [x] Deno type-check succeeds for all Edge Functions.
- [x] Domain tests pass.
- [x] TypeScript application type-check/build succeeds.
- [x] Cloudflare Worker bundle dry-run succeeds.
- [x] Database security assertions pass.
- [x] Existing RLS, grants, role-scope, finance, membership and identity-review regression suites pass.
- [x] Phone canonicalisation and player-ban/captain-succession suites pass.
- [x] Age-tier, guardian-consent, withdrawal, cooldown and admin-review SQL suite passed in [#1488](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42671920202), including UK civil-date/DST/leap-day boundaries, under-16 private membership access, and expired/consumed withdrawal-token checks.
- [x] Retention/reactivation lifecycle suite passes.
- [x] Global-admin retention-hold permissions, closure exclusion and audit lifecycle suite passes.
- [x] Permanent competition-identity and safe-erasure suite passed in [#1537](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42687671582), including guardian expiry, both service-role trigger bypasses, permanent-ID scorer options, post-erasure result correction and retained `Former player` statistics.
- [x] Auth signup, email confirmation and password-recovery lifecycle passes.
- [x] Location administrator grants and revocations are audit-logged; duplicate grants do not duplicate events, stale grants remain revocable after role removal, and only global admins can mutate assignments (forward-only migration and SQL regression coverage).
- [x] The fixed bottom navigation contains exactly Home, Match Centre, Join Open Play and More; the public Home route redirects registered players to Player Hub, and the More page exposes the teams, gallery and account workspaces.
- [x] Banned players are redirected away from Player Hub to the restricted registration-status screen; public Home authentication lookups ignore stale responses after account changes and recover from failed session lookups instead of hanging. Static regression assertions and both CI jobs passed in [#1422](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42645896667).
- [x] Public Match Centre and admin season statistics use points-only rankings; teams level on points share positions and goal difference is display-only. Dedicated unit/SQL regression tests passed in [#1424](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42646379541).
- [x] Captains Hub preselects the next required fixture. Database resolver, parent/child sheet triggers and post-match admin amendment controls passed regression coverage in [#1537](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42687671582). Direct client INSERT/UPDATE/DELETE on team-sheet tables is revoked; authenticated users must use the protected RPCs.

## 2. Registration and account security

- [x] Phone numbers are canonicalised and invalid/colliding legacy values fail safely.
- [x] Duplicate identity matching counts name, phone and email independently and applies the agreed 2-of-3 threshold.
- [x] Applicant-facing routes do not expose another player's private details or registration/ban status (SQL regression coverage).
- [x] Pending/rejected players cannot join or register with a team.
- [x] Player profile self-service permissions are limited to the approved fields.
- [x] Ban/unban is transactional, audited and does not silently restore membership.
- [x] Captain succession is deterministic and handles the no-eligible-successor case safely.
- [x] Under-16 users cannot create a player identity or access player-only functions.
- [x] Ages 16–17 require guardian verification and a separate global-admin decision.
- [x] Guardian verification and withdrawal tokens are hashed, one-use and time-limited. Verification expires after 7 days; withdrawal expires after 2 years and is rejected at age 18. Expiry and consumption regression checks passed in [#1488](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42671920202).
- [x] Guardian withdrawal suspends access and removes active/pending memberships and captaincy without destroying history.

## 3. Account retention and reactivation

- [x] Eligibility requires 12 months without successful sign-in, no active/pending membership, no unresolved payment or pending transfer, and no global/location administrator assignment.
- [x] Never-signed-in accounts use account creation time as the inactivity baseline.
- [x] Global and location administrators, legal/safeguarding holds and unresolved financial obligations are excluded.
- [x] The global-admin retention workspace can search player accounts and set/clear holds with a required reason; every change is recorded in the audit log. Holds cannot be applied after the final `erasure_due` stage.
- [x] Auth sign-in timestamp updates cannot reopen `closed` or `erasure_due` accounts; only the verified, single-use reactivation flow can restore `active` status (forward-only migration and regression test).
- [x] The application blocks private-page rendering while retention status is checked and fails closed when the status query errors; users can retry without discarding the session.
- [x] Eligibility is rechecked under lock immediately before closure and erasure. Membership activation takes the same profile/player locks.
- [x] Closure bans Auth sign-in and the app rejects closed/erasure-due accounts when observed.
- [x] Restricted archive lasts 12 months.
- [x] Reactivation is non-enumerating, verified by a single-use 24-hour email link and protected by a database cooldown.
- [x] Reactivation restores the same registered player account but no membership, pending request, captaincy or squad permissions.
- [x] Concurrent use of a single-use reactivation link cannot cause a losing retry to re-ban an account already reactivated by the winning request; the account-status gate still blocks private access if completion did not commit.
- [x] Expired archives are processed idempotently; `erasure_due` accounts remain in the queue after transient storage/Auth failures, and repeated marking is safe without duplicate initial audit events.
- [x] Worker logs do not disclose account UUIDs, email addresses or other direct identifiers.
- [x] The approved 90/30/7-day inactivity warning cadence is implemented in the branch with a service-role-only, per-inactivity idempotency ledger, retryable delivery claims, Resend idempotency keys and a fail-closed worker path. A database trigger independently blocks account closure until all three notices are accepted by the email provider and at least seven days have elapsed after the final notice. Clean replay, warning-stage/grace-period and failed-send retry regression checks passed in [#1537](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42687671582).
- [x] The retention workflow is manual-only: its daily cron has been removed and overlapping runs are serialized until warning email delivery, controlled staging acceptance and release approval are complete. No workflow dispatch has been run against live accounts.
- [ ] Resend secrets, sender identity, 90/30/7-day email content, provider idempotency and live email round-trip are verified in a controlled staging environment before activation.

## 4. Permanent competition identity and erasure

- [x] Every existing registered player receives a random account-independent competition identity.
- [x] Every historic team-sheet appearance and goal record is mapped to the correct identity before the migration can complete.
- [x] Missing/unmappable historical records fail the migration rather than silently losing history.
- [x] New team-sheet and goal records are assigned a valid identity by database triggers.
- [x] Account-linked foreign keys are detached safely before Auth deletion.
- [x] The erasure worker removes the public avatar object before profile/contact scrubbing and Auth deletion; storage-removal failure stops the erasure attempt and leaves the account queued for retry.
- [ ] Live avatar-object deletion and retry behaviour still require disposable-account staging verification.
- [x] Guardian consent data is deleted where no longer required.
- [x] Registration review match lists, reviewer references and reviewer free-text notes are scrubbed.
- [x] Notification payloads and audit metadata are reviewed for direct identifiers and scrubbed where associated with the account.
- [x] Historic appearances, goals, results and statistics remain intact under the retained 'Former player' competition identity.
- [ ] Privacy/legal review determines whether the stable competition identity plus retained match history is genuinely anonymous under UK GDPR or remains pseudonymous personal data. Until that review confirms otherwise, treat the retained identity/history as restricted personal data with a documented lawful basis and retention period.
- [ ] PostHog Phase 1 integration is partially implemented on the integration branch: the browser SDK mounts only after explicit opt-in and the privacy-settings gate, Global Privacy Control overrides opt-in, stable Supabase UUID identification/reset is implemented, privileged actors are excluded, and a strict non-PII event/property allow-list is enforced. The connected OPENPLAYNEW EU project currently reports no ingested event; `.env.example` keeps the project token blank and `VITE_POSTHOG_PRIVACY_SETTINGS_VERIFIED=false`. Remaining work: privacy review and project settings verification, configure approved preview/staging environment variables, broaden audited event coverage, implement trusted server-side capture for authoritative actions where required, verify ingestion and consent revocation in staging, and preserve the existing 749 historical events until their configured retention expires. Session replay, autocapture and exception capture remain disabled.
- [x] A returning person receives a new, unlinked competition identity after permanent erasure.
- [x] Standard team-sheet amendment cannot overwrite a former player's protected historic appearance.
- [ ] Payment/accounting records follow a separately documented retention schedule, with direct account/customer links detached where permitted.

- [x] Public Match Centre and admin season statistics use points-only rankings; teams level on points share positions and goal difference is display-only. Dedicated unit/SQL regression tests passed in [#1484](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42671278961).

- [x] Finance workspace waits for a verified signed-in session before loading protected finance RPCs; password recovery offers a non-enumerating resend path for expired links and signs out after password change. Static CI assertions passed in [#1424](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42646379541).

- [x] Fixture scheduling rejects active venues belonging to a different location than the selected season. Forward-only SQL migration and function-definition regression test passed in [#1424](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42646379541).
- [x] Clean migration replay reproduces the deployed location checks for admin result entry, scorer options and season statistics; static security assertions accept both approved location guard helpers. The hosted-order replay verifies 99 canonical applied sources plus 14 pending forward-only migrations (113 total) and passed in [#1537](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42687671582).

## 5. Manual product and security review

- [ ] Execute the expanded [Phase 1 manual acceptance runbook](phase-1-manual-acceptance-runbook.md) in an approved isolated staging environment using disposable synthetic accounts; record scenario results, device/browser matrix, redacted evidence and reviewer sign-off. The suite now explicitly covers the full visitor-to-player-to-member-to-captain journey, abandoned/resumed registration, team applications, join approval/rejection, leave/removal, captaincy changes, account switching/session expiry, transfer approval/denial/cancellation/deadlines/races, private messaging permissions and delivery failures, Stripe test-mode payments, fee deadlines, overdue handling, refunds, disputes, webhook idempotency and reconciliation, plus admin dashboard usability, permitted editing, role/location boundaries, audit history and destructive/bulk-action safeguards.
- [ ] Review registration form, error states and pending-review messaging on mobile and desktop.
- [ ] Confirm and document the remaining transfer rules, messaging scope and actual configured team-fee amount/currency. The fixture-payment policy itself is agreed: payment due 24 hours before kick-off with a visible countdown; one strike when that deadline is missed; a further 12-hour late-payment window; cancellation at 12 hours before kick-off if still unpaid; the non-paying team remains liable for its match fee and the paid opponent receives a full refund. Three strikes in a season trigger suspension and referral to admins; proposed removal requires explicit admin review/clearance, with reinstatement or removal recorded and never automatic. Validate the full policy in Stripe test mode, including timezone/DST boundaries, refund failures/retries, audit history and role permissions.
- [x] Static player-facing stylesheet coverage now applies Inter/Oswald, black/charcoal/orange surfaces, dark cards/forms, responsive spacing and the fixed four-tab bottom navigation. Route inspection confirms the player-facing class is applied to Player Hub, Match Centre, Teams, Join, Captain Hub, registration, sign-in, sign-up and password reset screens.
- [ ] Complete real-device visual acceptance on mobile, tablet and desktop. Static CSS inspection is not a substitute for viewing and interacting with the screens at those breakpoints.
- [x] Under-16s use account-based basic-view access (not anonymous-only). They may browse public Home, Match Centre and Teams/league information (fixtures, results and tables); Join Open Play must remain non-actionable for them. They cannot create a player identity, join/register a team, become captain or access player-only functions. Player registration starts at 16; ages 16–17 require verified guardian consent and separate administrator approval.
- [ ] Review guardian verification, admin decision and withdrawal flows end-to-end.
- [ ] Review ban/unban and captain succession screens against the database behaviour.
- [ ] Review account closure/reactivation pages and session handling.
- [ ] Complete the dedicated admin dashboard workflow suite (ADM-07–ADM-35): verify every authorised dashboard section is navigable and operational; permitted edits save correctly and propagate; invalid/protected edits are rejected; location/global/finance permissions are precise; approvals, fixtures, results, team sheets, transfers, gallery, statistics, finance, feature toggles, audit history and bulk/destructive actions behave correctly. Confirm an admin can complete normal work end-to-end without a developer/database workaround.
- [ ] Review admin result entry, scorer options, season statistics, team sheets and transfer/payment readers after anonymisation.
- [ ] Verify admin and referee result workflows publish official scores with no or partial goalscorer attribution, preserve only explicitly recorded eligible scorers, and never create invented individual goal records; cover new submissions and audited corrections in clean replay and authenticated staging.
- [ ] Verify the new Player Hub self-service season/career statistics RPC and responsive UI on a clean database replay and authenticated staging account. Assists and Man of the Match remain excluded until their audited capture and correction workflows are implemented.
- [x] Review every service-role Edge Function for secret handling, authentication, rate limits, idempotency and safe logging (all six function sources reviewed; staging delivery remains open).
- [x] Review all 77 authenticated-callable SECURITY DEFINER functions for explicit search_path, least privilege, grants and role/location/data-scope checks (read-only hosted snapshot, 9 November 2026).
- [x] Review all new/changed foreign keys and deletion behaviours against the full schema; clean replay and erasure regression suite passed.
- [x] Review the existing hosted Security Advisor baseline separately from the not-yet-deployed Phase 1 migrations.
- [x] Confirm no unexpected changes to the hosted Supabase project, production deployment or live user data.

## Hosted Security Advisor follow-up (read-only snapshot, 9 November 2026)

- The hosted project contains 96 SECURITY DEFINER functions in the public schema. All 96 set an explicit empty search_path; none is missing a fixed search_path.
- 77 are executable by authenticated users and 0 are executable by anon. The 77 authenticated RPCs are the source of the 77 advisor WARN findings.
- Of the 96 functions, 19 are not executable by either anon or authenticated and are internal-only (service/trigger paths).
- 76 of the 77 authenticated-callable functions reference auth.uid() in their definition. The remaining function, get_admin_stripe_payments, delegates its authorization check to has_finance_access(), whose definition scopes access to the caller's finance/admin role using auth.uid().
- The reviewed role helpers (has_finance_access, has_platform_role, has_global_admin_role, can_administer_location, is_active_team_captain and is_active_team_member) all use auth.uid() and have an explicit empty search_path.
- The three advisor INFO tables (admin_context_preferences, gallery_items and location_admin_assignments) have RLS enabled and no policies. Direct SELECT/INSERT/UPDATE/DELETE privileges are all false for both anon and authenticated, consistent with the RPC-only access design.
- A line-by-line review of all 77 authenticated-callable RPC definitions was completed against this hosted snapshot. The reviewed functions use direct `auth.uid()` checks or a reviewed caller-scoped helper; global player-detail, registration-review, notification-control, audit-history and location-assignment operations require global-admin roles; finance operations require the global finance/admin role; location operations enforce assigned-location context; player and captain operations are scoped to the signed-in user or an active team membership. No anonymous execution path or confirmed cross-user/cross-location authorization bypass was identified in the reviewed definitions. No dynamic SQL execution was found in the authenticated-callable SECURITY DEFINER set.
- The hosted snapshot predates the new location-assignment audit migration. The branch now records each actual grant/revocation in `audit_log`, avoids duplicate grant events, and permits stale assignment revocation after the league-admin role is removed. This is covered by a local SQL regression test; it has not been applied to the hosted project.
- All six Edge Function sources were reviewed. `guardian-consent` and `player-account-retention` have public entrypoints but validate the signed-in user, one-use token or cron secret themselves; `stripe-webhook` validates Stripe's raw-body signature and rejects live-mode events; `public-gallery` exposes only published items in active locations; `create-player-checkout` validates the signed-in user; and `deliver-notifications` accepts the service-role worker path or a global administrator for manual dispatch. Function gateway settings are explicit and protected by CI assertions. Guardian emails omit date of birth, notification provider error records omit raw response bodies, and checkout no longer contains a Lovable-origin fallback.
- The hosted snapshot predates the 14 un-applied Phase 1 migrations; it does not certify their future hosted grants or function definitions. Those are covered by clean local replay and SQL regression tests, with deployment still blocked pending release approval.

## 6. Release prerequisites (not part of local CI)

- [x] Confirmed the hosted migration ledger contains 99 applied entries and 14 pending forward-only migrations. The clean hosted-order replay verified the 99-source baseline plus 14 pending files (113 total) using `--include-all`; three pending files are older than the latest applied version. Verified in [#1537](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42687671582). Do not reapply the 99 recorded migrations.
- [x] Current branch contains 14 pending forward-only migrations (99 hosted baseline + 14 pending = 113 total), including `20261109210000_player_account_inactivity_warnings.sql`. The updated manifest, hosted-order verification, clean replay and SQL security/lifecycle suites passed in [#1537](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42687671582). The hosted ledger remains unchanged at 99 applied entries.
- [ ] Configure required Supabase and GitHub secrets in the intended environment.
- [ ] Apply migrations and deploy Edge Functions only after explicit release approval.
- [ ] Verify guardian and reactivation email delivery in staging.
- [ ] Verify the daily retention workflow manually against disposable test accounts before scheduling it.
- [ ] Confirm the individual data controller's full legal name and final public contact details before publishing the privacy notice. Open Play is the currently unregistered trading name; the confirmed contact email is openplayfootballleague@gmail.com and no postal/business address is currently held.
- [ ] Confirm legal/privacy review of the retention periods, legal-hold process, under-18 data, payment/accounting retention and the anonymisation-versus-pseudonymisation status of retained competition history.
- [ ] Obtain explicit approval before merge, production migration, Edge Function deployment or enabling unattended account closure/erasure.

## Audit outcome

Phase 1 remains **not complete** until all applicable automated checks are green, source and data-flow review has no unresolved critical/high-risk findings, manual acceptance scenarios are signed off, and release prerequisites are documented. Any intentionally deferred item must be recorded as a known limitation with an owner and must not be represented as completed.

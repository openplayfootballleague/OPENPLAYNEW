# Phase 1 final audit checklist

Status: **Automated verification passed — manual audit and release prerequisites remain open**

Scope: Open Play New Phase 1 registration safeguards, identity/consent controls, player access restrictions, account retention and permanent competition-history preservation.

This checklist is the release gate for Phase 1. A section is not complete merely because code exists; it requires source review and passing evidence. No production migration, Edge Function deployment, merge or unattended retention activation is authorised by this checklist.

## 1. Automated verification

- [x] Latest audit checklist commit passed both jobs in [#1379](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42635182947). The Edge Function security-boundary assertions, Deno checks, application build, domain tests and Cloudflare dry-run passed in [#1389](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42639212223); its clean database replay has completed all test steps and is finishing runner cleanup.
- [x] Clean local Supabase migration replay succeeds from an empty database.
- [x] Migration source manifest matches the actual migration files and Git blobs.
- [x] Deno type-check succeeds for all Edge Functions.
- [x] Domain tests pass.
- [x] TypeScript application type-check/build succeeds.
- [x] Cloudflare Worker bundle dry-run succeeds.
- [x] Database security assertions pass.
- [x] Existing RLS, grants, role-scope, finance, membership and identity-review regression suites pass.
- [x] Phone canonicalisation and player-ban/captain-succession suites pass.
- [x] Age-tier, guardian-consent, withdrawal, cooldown and admin-review suites pass.
- [x] Retention/reactivation lifecycle suite passes.
- [x] Global-admin retention-hold permissions, closure exclusion and audit lifecycle suite passes.
- [x] Permanent competition-identity and safe-erasure suite passes.
- [x] Auth signup, email confirmation and password-recovery lifecycle passes.

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
- [x] Guardian verification and withdrawal tokens are hashed, one-use, time-limited and rate-limited.
- [x] Guardian withdrawal suspends access and removes active/pending memberships and captaincy without destroying history.

## 3. Account retention and reactivation

- [x] Eligibility requires 12 months without successful sign-in and no active/pending membership.
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
- [x] Expired archives are processed idempotently; failed erasure remains banned and is retried.
- [x] Worker logs do not disclose account UUIDs, email addresses or other direct identifiers.
- [ ] Advance-warning email cadence is agreed and implemented before unattended closures are enabled. **Current documented gap:** 90/30/7-day advance notices are not yet implemented.
- [ ] Resend secrets, sender identity and live email round-trip are verified in a controlled staging environment before activation.

## 4. Permanent competition identity and erasure

- [x] Every existing registered player receives a random account-independent competition identity.
- [x] Every historic team-sheet appearance and goal record is mapped to the correct identity before the migration can complete.
- [x] Missing/unmappable historical records fail the migration rather than silently losing history.
- [x] New team-sheet and goal records are assigned a valid identity by database triggers.
- [x] Account-linked foreign keys are detached safely before Auth deletion.
- [ ] Player profile/contact/avatar data is scrubbed and avatar storage deletion is confirmed before Auth deletion.
- [x] Guardian consent data is deleted where no longer required.
- [x] Registration review match lists, reviewer references and reviewer free-text notes are scrubbed.
- [x] Notification payloads and audit metadata are reviewed for direct identifiers and scrubbed where associated with the account.
- [x] Historic appearances, goals, results and statistics remain intact under the retained 'Former player' competition identity.
- [ ] Privacy/legal review determines whether the stable competition identity plus retained match history is genuinely anonymous under UK GDPR or remains pseudonymous personal data. Until that review confirms otherwise, treat the retained identity/history as restricted personal data with a documented lawful basis and retention period.
- [x] A returning person receives a new, unlinked competition identity after permanent erasure.
- [x] Standard team-sheet amendment cannot overwrite a former player's protected historic appearance.
- [ ] Payment/accounting records follow a separately documented retention schedule, with direct account/customer links detached where permitted.

## 5. Manual product and security review

- [ ] Review registration form, error states and pending-review messaging on mobile and desktop.
- [ ] Review guardian verification, admin decision and withdrawal flows end-to-end.
- [ ] Review ban/unban and captain succession screens against the database behaviour.
- [ ] Review account closure/reactivation pages and session handling.
- [ ] Review admin result entry, scorer options, season statistics, team sheets and transfer/payment readers after anonymisation.
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
- One non-authorization auditability gap was noted: `admin_set_location_assignment` is restricted to global administrators but does not currently write an `audit_log` entry when an assignment is granted or revoked. Record this for hardening before broad delegation of location administration.
- All six Edge Function sources were reviewed. `guardian-consent` and `player-account-retention` have public entrypoints but validate the signed-in user, one-use token or cron secret themselves; `stripe-webhook` validates Stripe's raw-body signature and rejects live-mode events; `public-gallery` exposes only published items in active locations; `create-player-checkout` validates the signed-in user; and `deliver-notifications` accepts the service-role worker path or a global administrator for manual dispatch. Function gateway settings are explicit and protected by CI assertions. Guardian emails omit date of birth, notification provider error records omit raw response bodies, and checkout no longer contains a Lovable-origin fallback.
- The hosted snapshot predates the seven un-applied Phase 1 migrations; it does not certify their future hosted grants or function definitions. Those are covered by clean local replay and SQL regression tests, with deployment still blocked pending release approval.

## 6. Release prerequisites (not part of local CI)

- [ ] Confirm the final migration plan against the hosted migration ledger; do not reapply previously recorded migrations.
- [ ] Configure required Supabase and GitHub secrets in the intended environment.
- [ ] Apply migrations and deploy Edge Functions only after explicit release approval.
- [ ] Verify guardian and reactivation email delivery in staging.
- [ ] Verify the daily retention workflow manually against disposable test accounts before scheduling it.
- [ ] Confirm legal/privacy review of the retention periods, legal-hold process, under-18 data, payment/accounting retention and the anonymisation-versus-pseudonymisation status of retained competition history.
- [ ] Obtain explicit approval before merge, production migration, Edge Function deployment or enabling unattended account closure/erasure.

## Audit outcome

Phase 1 remains **not complete** until all applicable automated checks are green, source and data-flow review has no unresolved critical/high-risk findings, manual acceptance scenarios are signed off, and release prerequisites are documented. Any intentionally deferred item must be recorded as a known limitation with an owner and must not be represented as completed.

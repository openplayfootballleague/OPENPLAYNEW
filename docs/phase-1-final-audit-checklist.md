# Phase 1 final audit checklist

Status: **Automated verification passed — manual audit and release prerequisites remain open**

Scope: Open Play New Phase 1 registration safeguards, identity/consent controls, player access restrictions, account retention and permanent competition-history preservation.

This checklist is the release gate for Phase 1. A section is not complete merely because code exists; it requires source review and passing evidence. No production migration, Edge Function deployment, merge or unattended retention activation is authorised by this checklist.

## 1. Automated verification

- [x] Latest implementation commit has a fully green GitHub Actions run (run [#1378](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42634737332)).
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

- [ ] Phone numbers are canonicalised and invalid/colliding legacy values fail safely.
- [ ] Duplicate identity matching counts name, phone and email independently and applies the agreed 2-of-3 threshold.
- [ ] Applicant-facing routes do not expose another player's private details or registration/ban status.
- [ ] Pending/rejected players cannot join or register with a team.
- [ ] Player profile self-service permissions are limited to the approved fields.
- [ ] Ban/unban is transactional, audited and does not silently restore membership.
- [ ] Captain succession is deterministic and handles the no-eligible-successor case safely.
- [ ] Under-16 users cannot create a player identity or access player-only functions.
- [ ] Ages 16–17 require guardian verification and a separate global-admin decision.
- [ ] Guardian verification and withdrawal tokens are hashed, one-use, time-limited and rate-limited.
- [ ] Guardian withdrawal suspends access and removes active/pending memberships and captaincy without destroying history.

## 3. Account retention and reactivation

- [ ] Eligibility requires 12 months without successful sign-in and no active/pending membership.
- [ ] Never-signed-in accounts use account creation time as the inactivity baseline.
- [ ] Global and location administrators, legal/safeguarding holds and unresolved financial obligations are excluded.
- [ ] The global-admin retention workspace can search player accounts and set/clear holds with a required reason; every change is recorded in the audit log. Holds cannot be applied after the final `erasure_due` stage.
- [x] Auth sign-in timestamp updates cannot reopen `closed` or `erasure_due` accounts; only the verified, single-use reactivation flow can restore `active` status (forward-only migration and regression test).
- [x] The application blocks private-page rendering while retention status is checked and fails closed when the status query errors; users can retry without discarding the session.
- [ ] Eligibility is rechecked under lock immediately before closure and erasure.
- [ ] Closure bans Auth sign-in and the app rejects closed/erasure-due accounts when observed.
- [ ] Restricted archive lasts 12 months.
- [ ] Reactivation is non-enumerating, verified by a single-use 24-hour email link and protected by a database cooldown.
- [ ] Reactivation restores the same registered player account but no membership, pending request, captaincy or squad permissions.
- [ ] Expired archives are processed idempotently; failed erasure remains banned and is retried.
- [ ] Worker logs do not disclose account UUIDs, email addresses or other direct identifiers.
- [ ] Advance-warning email cadence is agreed and implemented before unattended closures are enabled. **Current documented gap:** 90/30/7-day advance notices are not yet implemented.
- [ ] Resend secrets, sender identity and live email round-trip are verified in a controlled staging environment before activation.

## 4. Permanent competition identity and erasure

- [ ] Every existing registered player receives a random account-independent competition identity.
- [ ] Every historic team-sheet appearance and goal record is mapped to the correct identity before the migration can complete.
- [ ] Missing/unmappable historical records fail the migration rather than silently losing history.
- [ ] New team-sheet and goal records are assigned a valid identity by database triggers.
- [ ] Account-linked foreign keys are detached safely before Auth deletion.
- [ ] Player profile/contact/avatar data is scrubbed and avatar storage deletion is confirmed before Auth deletion.
- [ ] Guardian consent data is deleted where no longer required.
- [ ] Registration review match lists, reviewer references and reviewer free-text notes are scrubbed.
- [ ] Notification payloads and audit metadata are reviewed for direct identifiers and scrubbed where associated with the account.
- [ ] Historic appearances, goals, results and statistics remain intact under the retained 'Former player' competition identity.
- [ ] Privacy/legal review determines whether the stable competition identity plus retained match history is genuinely anonymous under UK GDPR or remains pseudonymous personal data. Until that review confirms otherwise, treat the retained identity/history as restricted personal data with a documented lawful basis and retention period.
- [ ] A returning person receives a new, unlinked competition identity after permanent erasure.
- [ ] Standard team-sheet amendment cannot overwrite a former player's protected historic appearance.
- [ ] Payment/accounting records follow a separately documented retention schedule, with direct account/customer links detached where permitted.

## 5. Manual product and security review

- [ ] Review registration form, error states and pending-review messaging on mobile and desktop.
- [ ] Review guardian verification, admin decision and withdrawal flows end-to-end.
- [ ] Review ban/unban and captain succession screens against the database behaviour.
- [ ] Review account closure/reactivation pages and session handling.
- [ ] Review admin result entry, scorer options, season statistics, team sheets and transfer/payment readers after anonymisation.
- [ ] Review every service-role Edge Function for secret handling, authentication, rate limits, idempotency and safe logging.
- [ ] Review all security-definer functions for explicit search_path, least privilege, correct grants and role/location checks.
- [ ] Review all new/changed foreign keys and deletion behaviours against the full schema.
- [ ] Review the existing hosted Security Advisor baseline separately from the not-yet-deployed Phase 1 migrations.
- [ ] Confirm no unexpected changes to the hosted Supabase project, production deployment or live user data.

## Hosted Security Advisor follow-up (read-only snapshot, 9 November 2026)

- The hosted project contains 96 SECURITY DEFINER functions in the public schema. All 96 set an explicit empty search_path; none is missing a fixed search_path.
- 77 are executable by authenticated users and 0 are executable by anon. The 77 authenticated RPCs are the source of the 77 advisor WARN findings.
- Of the 96 functions, 19 are not executable by either anon or authenticated and are internal-only (service/trigger paths).
- 76 of the 77 authenticated-callable functions reference auth.uid() in their definition. The remaining function, get_admin_stripe_payments, delegates its authorization check to has_finance_access(), whose definition scopes access to the caller's finance/admin role using auth.uid().
- The reviewed role helpers (has_finance_access, has_platform_role, has_global_admin_role, can_administer_location, is_active_team_captain and is_active_team_member) all use auth.uid() and have an explicit empty search_path.
- The three advisor INFO tables (admin_context_preferences, gallery_items and location_admin_assignments) have RLS enabled and no policies. Direct SELECT/INSERT/UPDATE/DELETE privileges are all false for both anon and authenticated, consistent with the RPC-only access design.
- This is a scoped read-only baseline review, not a complete line-by-line certification of every RPC. The per-function role/location/data-scope review remains open; do not remove grants or weaken access based only on the advisor warning.
- The hosted snapshot predates the six un-applied Phase 1 migrations; it does not certify their future hosted grants or function definitions. Those are covered by clean local replay and SQL regression tests, with deployment still blocked pending release approval.

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

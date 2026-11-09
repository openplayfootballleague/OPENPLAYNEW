# Phase 1 final audit checklist

Status: **Audit preparation in progress — not signed off**

Scope: Open Play New Phase 1 registration safeguards, identity/consent controls, player access restrictions, account retention and permanent competition-history preservation.

This checklist is the release gate for Phase 1. A section is not complete merely because code exists; it requires source review and passing evidence. No production migration, Edge Function deployment, merge or unattended retention activation is authorised by this checklist.

## 1. Automated verification

- [ ] Latest commit has a fully green GitHub Actions run.
- [ ] Clean local Supabase migration replay succeeds from an empty database.
- [ ] Migration source manifest matches the actual migration files and Git blobs.
- [ ] Deno type-check succeeds for all Edge Functions.
- [ ] Domain tests pass.
- [ ] TypeScript application type-check/build succeeds.
- [ ] Cloudflare Worker bundle dry-run succeeds.
- [ ] Database security assertions pass.
- [ ] Existing RLS, grants, role-scope, finance, membership and identity-review regression suites pass.
- [ ] Phone canonicalisation and player-ban/captain-succession suites pass.
- [ ] Age-tier, guardian-consent, withdrawal, cooldown and admin-review suites pass.
- [ ] Retention/reactivation lifecycle suite passes.
- [ ] Permanent competition-identity and safe-erasure suite passes.
- [ ] Auth signup, email confirmation and password-recovery lifecycle passes.

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
- [ ] An authorised, audited admin workflow exists to set, review and clear retention holds with a recorded reason. **Current gap:** the schema has a hold flag, but no verified admin UI/RPC workflow has been signed off.
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

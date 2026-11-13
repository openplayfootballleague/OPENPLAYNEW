# Phase 2 — Backend and data architecture

## Scope
The dedicated Supabase project **Open Play New** is the only backend for this repository. No old project identifiers, credentials or production records are reused.

## Domain model
- **Identity:** Supabase Auth owns credentials; `profiles` stores player profile and private contact/emergency details. Roles are separately granted in `user_roles`.
- **Competition:** locations contain leagues; leagues contain seasons. A season owns its competition format and lifecycle.
- **Historical teams:** `teams` is the long-lived club identity. `season_teams` stores that club's season-specific name, badge and colours, so archived records remain historically accurate.
- **People:** season registration is separate from team membership. Membership carries the season-specific captain assignment and optional squad number.
- **Matchday:** fixtures reference two season teams; results, team sheets, player selections and availability are separate records.
- **Transfers:** player movement is requested and reviewed rather than silently changing membership history.
- **Money:** the current Finance v1 is an append-only manual ledger. Card processing and automated collection are not implemented; any later payment integration requires an explicit product decision and verified webhook/idempotency controls.
- **Operations:** notification events and append-only audit records support delivery tracking and accountability.

## Security approach
- RLS is enabled on application tables.
- Client-side UI visibility is never treated as authorization.
- User role grants, financial writes, fixture result confirmation, payment state transitions and audit records must be performed by trusted server-side functions.
- Sensitive profile data is not public by default.
- Archived seasons are read-only at the application/service layer and must not be mutated through ordinary captain workflows.
- Security-definer functions must retain explicit role/ownership checks and narrowly scoped execute grants.

## Team sheet rules
- Six-a-side: exactly 6 starters and up to 3 substitutes.
- Seven-a-side: exactly 7 starters and up to 4 substitutes.
- Squad numbers are optional.
- These format-aware validations are enforced server-side at submission, not only in the interface.

## Backend status — 7 November 2026
- The dedicated Supabase project **Open Play New** is connected and provisioned.
- 63 database migrations are recorded as applied.
- The application schema and role-guarded workflows are implemented, including registration, teams, seasons, fixtures, team sheets, results, transfers, player statistics, finance ledger, audit history and notification preferences/outbox.
- The `deliver-notifications` Edge Function is deployed. Its current deployed version and provider configuration must be verified in the Supabase dashboard before live delivery testing.
- The fixture-reminder cron job enqueues reminders; it does not itself dispatch email or SMS.
- The database is intentionally empty: no Auth users, players, fixtures, locations, leagues or seasons have been seeded.
- No test or production data should be created without owner approval.

## Remaining backend and launch work
1. Complete browser acceptance testing using owner-approved test identities.
2. Configure and verify Supabase Auth email confirmation, Site URL, redirect allow-list and a production SMTP provider.
3. Configure Resend/Twilio secrets and an automatic notification-dispatch invocation schedule before attempting real delivery.
4. Verify RLS and privileged RPC behavior with anonymous, ordinary authenticated and approved administrator identities.
5. Seed only owner-approved Bideford league, season, venue, team and fixture data before opening registrations. Barnstaple and Torrington remain inactive for the first release.
6. Keep production deployment blocked until acceptance, security and operational launch checks are complete.

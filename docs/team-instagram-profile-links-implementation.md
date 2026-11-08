# Team Instagram profile links — implementation notes

## Implemented on the development branch

- Added strict client-side URL normalisation in `src/lib/teams/instagram.ts` and tests. Only direct HTTPS profile URLs on `instagram.com` or `www.instagram.com` are accepted; arbitrary domains, HTTP, query strings, post URLs, path traversal and malformed handles are rejected.
- Added the optional Instagram profile URL field to the existing team registration form. Empty input is sent as null and does not block registration.
- Added the team-level `teams.instagram_profile_url` schema change in migration source `20261108015000_team_instagram_profile.sql`. The value is stored on `teams`, never on a player profile.
- Added server-side validation and URL normalisation in the registration and update RPCs.
- Added a captain-facing editor in the Captains Hub. Active captains can update or remove the link without re-registering.
- Added an admin team social-profile register and location-scoped update/read RPCs. Platform admin/super-admin can manage globally; location admins are restricted through `can_administer_location`.
- Added a public directory Instagram icon only when a profile URL exists. It opens the exact HTTPS URL in a new browser context with `noopener noreferrer`; the browser/OS can hand off to the Instagram app where configured.
- Added restricted public column access and an RLS policy that exposes only the team ID and Instagram URL for teams attached to approved, published public seasons. The `created_by` field is not exposed to anonymous visitors.

## Existing form discrepancy

The current branch's team registration form contains team name and colours, but no existing Instagram username/handle question. This implementation adds the requested optional profile-link field without inventing a username field that is not present in the current application.

## Database and migration gate

The migration source has been committed but **not applied**. The connected Supabase migration ledger has source/version mismatches and duplicate/renamed entries compared with the branch migration directory. The existing migration-source recovery task must be reconciled before applying any new migration. Consequently the current production database does not yet have the new column or RPCs, and this feature is not production-ready until the migration is safely reconciled, applied in the approved environment and verified.

## Remaining verification

- Await CI for the latest app commit.
- Verify the new SQL migration against the live schema and migration reconciliation before applying.
- Run registration cases: no link, valid link, invalid link.
- Run captain/admin update and removal cases.
- Verify public directory visibility and RLS for anonymous, ordinary authenticated, captain, location-admin, league-admin and platform-admin roles.
- Verify team link isolation across distinct team IDs and shared team IDs across seasons/locations.
- Verify app handoff/browser fallback on iOS and Android.

No production schema changes or deployments have been made.

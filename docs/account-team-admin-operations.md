# Open Play account, role and launch operations

## Account onboarding

- Public browsing does not require an account.
- Sign-up creates an Auth user and the database trigger creates an empty private profile row. It does not create a player, team membership or role.
- Email verification must be enabled in Supabase Auth. Add the exact local and production origins to the Auth URL allow-list, with `/player` as the email confirmation redirect.
- Sign-in and password recovery use Supabase Auth. Password reset returns to `/sign-in`; configure the matching redirect URL.
- Player registration is a separate authenticated RPC. The database checks the account email, confirmed email timestamp, date of birth, duplicate identity metrics and existing registration state.
- A player with two or more matching identity metrics is queued for manual review. Only a registered, non-banned player may request team membership or submit a team application.

## Team registration and membership

- A team application creates a permanent team record and a season-specific team profile in `pending` status.
- The applicant is recorded as a pending membership, not a captain.
- A platform administrator approves or rejects the team application. Approval activates the applicant membership and captain role atomically.
- Players request to join an approved team. Membership remains pending until an active captain or platform administrator approves it.
- Rejected membership requests use a distinct `rejected` state. A player may submit a fresh request after rejection; voluntary departures remain `left`.
- The Captains Hub reads a restricted database projection that returns only team roster names and membership workflow fields. It does not expose email, phone, date of birth or emergency contacts.
- Captains can submit fixture team sheets through a server-side RPC. The database validates the fixture/team pairing, captain authority, active and approved player memberships, exact starter count, substitute limit and duplicate player selection. Team sheets cannot be changed after locking.
- Squad numbers are optional. Active players in the same season team cannot share a squad number.

## Profile pictures

The `profile-avatars` bucket accepts JPEG, PNG and WebP images up to 5 MB. Objects are publicly readable as profile pictures, but authenticated users can write or delete only inside their own UUID folder. The database profile row stores the object path, not a service credential or arbitrary URL.

## First administrator bootstrap

No user is automatically made an administrator. After the first trusted owner account has been created and its email verified, a project owner must grant the initial role from the Supabase SQL Editor using that account real Auth user UUID:

```sql
insert into public.user_roles (user_id, role, granted_by)
values ('REPLACE_WITH_VERIFIED_AUTH_USER_UUID', 'super_admin', 'REPLACE_WITH_VERIFIED_AUTH_USER_UUID');
```

Do not expose a public bootstrap endpoint or grant administrator privileges from client-side code. Keep the initial grant auditable and restrict Supabase project-owner access.

## Required Supabase Auth settings

1. Enable email/password authentication and email confirmation.
2. Set the production Site URL to the production Open Play origin.
3. Add local development and production origins to the redirect allow-list.
4. Ensure the email confirmation link redirects to `/player` and password recovery redirects to `/sign-in`.
5. Configure a branded, deliverable SMTP provider before public launch; the default test mail service is not a production mail solution.

## Current release data requirements

The public app reads only published seasons and approved teams. Do not seed fake fixtures or placeholder team data. Before opening registrations, create the real Bideford location, published league, season, dates, fees and approved team records using the admin workflows. Keep Barnstaple and Torrington unpublished until explicitly enabled for a later release.

## Security and verification

- All privileged workflow changes are server-side RPCs with role checks and audit events.
- Never place Supabase secret/service-role keys in `VITE_` variables or browser code.
- Run `npm test`, `npm run build` and `npx wrangler deploy --dry-run` for each release.
- Run Supabase security, performance and health advisors after schema changes. SECURITY DEFINER helper warnings must be reviewed against their RLS use; do not revoke required RLS helper execution blindly.
- Live end-to-end tests still require real verified test accounts and a configured email delivery path. Do not treat CI compilation as proof that email delivery or production authentication is working.
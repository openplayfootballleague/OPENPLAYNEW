# Open Play New — Stage 1: Account foundations, security and permissions

**Scope:** The entire application, including public entry points, player, captain, finance and administrator areas.
**Working branch:** `integration/complete-product-build`
**Release state:** Development only. No merge, deployment, hosted migration or production configuration change is authorised.
**Cost rule:** No paid test branches, paid test services or other testing expenditure.

Stage 1 is the shared identity and permission foundation on which every later product stage depends. A screen is not Stage 1-complete merely because it hides a link: protected data and actions must be authorised by Supabase/RPC/server rules as well.

## Required product contract

1. A Supabase Auth account is not a registered Open Play player.
2. A registered player is not automatically a club member.
3. Club membership is not automatically captain authority.
4. Captain authority is tied to an approved active season-club membership.
5. Administrator authority is explicitly provisioned and, where applicable, scoped to assigned locations.
6. Platform/super-admin privileges are never self-service and cannot be granted by an ordinary account.
7. The account email remains governed by verified Supabase Auth; it is not editable through an ordinary profile-table update.
8. Sensitive identity, eligibility, ban, emergency-contact and role fields are not client-writable.
9. Public browsing remains available without authentication; protected personal, captain, finance and administrator data does not.
10. A user must never be able to elevate access by changing client state, route URLs, request payloads or local profile fields.

## Stage 1 checklist

### A. Account lifecycle

- [x] Email/password account creation route exists.
- [x] Email verification is required before player registration.
- [x] Password sign-in route exists.
- [x] Sign-out is available in the player registration/account flow.
- [x] Password recovery request is wired from sign-in.
- [x] Password reset route updates the password and signs the user out after success.
- [x] Expired/invalid reset-link page now allows a fresh reset email request.
- [ ] Confirm Supabase Auth site URL and redirect allowlist for local/preview/release origins.
- [ ] Confirm email provider/SMTP delivery and verification templates.
- [ ] Confirm rate limits and anti-bot/CAPTCHA policy for sign-up, sign-in, resend and password recovery.
- [ ] Confirm duplicate Auth account responses remain privacy-safe and actionable.
- [ ] Confirm session expiry, refresh, cross-tab sign-out and revoked-session behaviour across all protected areas.

### B. Player identity and registration boundary

- [x] Account and player registration are separate records/states.
- [x] Player registration RPC is authenticated-only and requires verified email in the client flow.
- [x] Player identity matching/approval is performed by the database RPC, not trusted client state.
- [x] Pending-review/rejected/banned states are represented separately from an ordinary Auth session.
- [x] The account email is sourced from the verified Auth session in the registration form.
- [ ] Reconcile and document duplicate-identity edge cases, including concurrent submissions and privacy-safe review outcomes.
- [ ] Confirm returning-player identity linking and account recovery/relinking policy without creating duplicate player identities.

### C. Profile and personal-data permissions

- [x] Player self-service fields are limited by database column grants.
- [x] Date of birth and emergency-contact fields are excluded from ordinary authenticated client updates.
- [x] Profile avatar storage policies are owner-folder scoped.
- [x] Account/player IDs, registration status, ban state, genuine-player state, captain status and membership are system/approval controlled.
- [ ] Confirm the complete player-visible/admin-visible/captain-visible field matrix and publish the privacy notice.
- [ ] Confirm account email change uses Supabase's verified email-change flow, not a direct profile update.
- [ ] Review account deletion/data-retention and subject-access/correction procedures.

### D. Roles, permissions and administrator provisioning

- [x] Anonymous execution of public-schema SECURITY DEFINER helpers is revoked in the deployed migration history.
- [x] Authenticated clients cannot directly mutate user_roles.
- [x] Location administrator assignments are stored behind RPC-only permissions.
- [x] Location-scoped administrator reads and mutations use server-side location checks.
- [x] Finance access has a separate permission boundary.
- [x] Captain operations are enforced through database RPCs and membership state rather than client labels.
- [ ] Complete one documented role/action matrix for anonymous, account-only, registered player, captain, finance admin, location admin, platform admin and super admin across every route and RPC.
- [ ] Complete secure first-super-admin bootstrap using a verified owner-approved identity and a one-time controlled grant; no self-promotion.
- [ ] Confirm role assignment/revocation and location assignment changes are audited and take effect promptly in active sessions.
- [ ] Review every protected route for direct-URL access and fail-closed behaviour when role/context lookup fails.

### E. App-wide access and session handling

- [ ] Apply one reusable session/authorization boundary across Player Hub, Captain Hub, Finance and all 15 administrator workspaces.
- [ ] Ensure every data-loading query and mutation has a server/database authorization check, not just a client route guard.
- [ ] Ensure users with multiple roles are routed to the correct permitted workspace without granting broader privileges.
- [ ] Ensure sign-out and session loss clear sensitive in-memory state and return users to an appropriate public page.
- [ ] Ensure public pages remain browseable without requiring an account or exposing private records.

### F. Policy and operational readiness

- [ ] Approve and publish the privacy notice, including identity matching, date of birth, contact data, analytics and retention.
- [ ] Confirm the player transfer/one-club-per-season policy and ensure the same policy is reflected in player-facing wording and admin actions.
- [ ] Confirm support/recovery route for lost access, duplicate identity disputes and rejected registrations.
- [ ] Record the approved Auth redirect origins, email provider, anti-abuse settings and account recovery runbook without storing secrets in Git.

## Work recorded in this Stage 1 pass

- Updated `src/routes/reset-password.tsx` so an expired reset link can request a fresh email directly instead of dead-ending at sign-in.
- After a successful password change, the user is signed out and prompted to sign in again.
- The existing sign-up, sign-in, player registration, profile grants, RLS/RPC and location-scoped role protections were inspected.
- Read-only inspection confirmed the deployed database exposes the player registration and role-check RPCs to authenticated users but not anonymous users. No database changes were made.
- No paid test branch was created, no test identities were provisioned, no hosted migration was applied, and no deployment or merge occurred.

## Completion rule

Stage 1 is complete only when all applicable checklist items are implemented and the external configuration/policy items are resolved. Items requiring owner approval or provider configuration must remain clearly marked as blocked; they must not be simulated or reported as complete. Later product stages may proceed against these documented contracts, but must not bypass them.


## Read-only permission audit — 8 November 2026

A further inspection was performed against the currently deployed Supabase project using SELECT-only catalog queries. No database writes or configuration changes were made.

### Confirmed in the deployed database

- `user_roles` has a SELECT policy for the account owner or platform administrator; authenticated users have SELECT only, with no direct INSERT/UPDATE/DELETE grant.
- `profiles` has owner/platform-admin read and update policies, plus owner insert policy; the authenticated table grant currently exposes SELECT only, so profile writes must use the approved RPC/server path.
- `players` has a self/platform-admin SELECT policy and authenticated SELECT only.
- `team_memberships` has self/active-captain/platform-admin SELECT policy and authenticated SELECT only.
- `audit_log` has an explicit deny-all client policy and no authenticated/anonymous table grant in the inspected grants.
- The inspected grants show no direct client write privileges for these identity/role tables.

### Reconciliation required before Stage 1 can be marked complete

The deployed policy catalogue is not identical to the integration branch's original policy migration text. For example, deployed `season_teams` contains policy names and expressions that differ from the branch's initial migration. This is a migration-history/source-of-truth reconciliation item, not permission to overwrite deployed policies. Compare the complete applied migration ledger and current catalog definitions before authoring any forward-only correction.

### Next implementation priorities

1. Build a route/RPC access matrix from every protected page and every called RPC, distinguishing UI navigation from authoritative database authorization.
2. Trace `/admin`, `/finance`, `/captain` and `/player` page load paths and verify fail-closed handling when session/role/context lookups fail.
3. Reconcile role vocabulary and scoped admin checks with the deployed schema; do not assume a `user_roles` row alone grants location access.
4. Add free, repository-level tests for pure access/routing decisions and static permission invariants. SQL behaviour remains unverified without a separate database, and no paid environment will be created.

## Route-to-RPC security audit — 8 November 2026 (read-only)

The current integration branch was traced through the Player, Captain, Finance and Administrator route files. The protected workspaces use Supabase RPCs for privileged actions rather than writing role, finance, membership or administrative records directly from the browser. The Player Hub also reads the signed-in user's own profile, player, membership and notification records under the deployed table policies.

A read-only query of the deployed PostgreSQL function catalogue checked the 56 privileged RPCs called by the current Captain, Finance and Administrator routes:

- All 56 inspected functions are SECURITY DEFINER.
- All 56 deny execution to anon and grant execution to authenticated.
- All 56 function definitions contain an authentication/authorisation guard marker (auth.uid() or a recognised role/scope helper).
- Captain RPCs explicitly check active captain membership; finance RPCs use the finance permission helper; administrator RPCs use platform-role and/or location-scope checks.

This is a useful high-level invariant check, not a substitute for reviewing every function body and testing each role against every resource. A text-pattern check can confirm that a guard is present but cannot prove that the guard is correctly placed or that every returned row is scoped correctly. The full role/action matrix and per-function location-scope review remain open.

### Route-level findings

- /captain loads dashboard, fixture, availability and team-sheet data through dedicated captain RPCs. The database functions check active captain membership. The route itself does not yet share a reusable signed-in session boundary.
- /finance loads and mutates data only through finance/admin RPCs. The database functions check finance access. The route itself does not yet share a reusable signed-in session boundary.
- /admin loads and mutates through admin RPCs, including contextual location/league/season parameters. The database functions perform role and scope checks; the selected UI context is not itself authority. The route itself does not yet share a reusable signed-in session boundary.
- /player checks the Supabase session and clears key player state on sign-out, while reading the user's own records. Its sign-out/session-loss handling and asynchronous load cancellation still need a full pass.
- Public browse routes (/, /teams, /match-centre, /gallery, /join) remain separate from the protected workspaces; their query exposure and registration entry points still need a route-by-route public-data audit.

### Verification state

The latest integration-branch commit at the time of this audit is 86f6a11a4c4ad3427ae1b47e1f3fff0225f6d6c4. GitHub reports its Build verification workflow completed successfully. This confirms the repository's configured CI for that commit; it does not exercise live Supabase role combinations or provider configuration.

No hosted writes, migrations, paid branches, test accounts, deployment or merge were performed.
### Additional privilege-boundary finding — location activation

The deeper function-body review identified an over-broad role gate in the deployed definition of `admin_set_location_active`: it checked `can_administer_location(...)` and `has_platform_role()`, and `has_platform_role()` includes `league_admin`. This meant an assigned location administrator could reach a platform-wide location activation/deactivation control through a direct RPC call even though the UI hid that control. The function's Bideford-first-release constraints limited the impact, but the role boundary was still incorrect.

A new forward migration, `20261108220000_restrict_location_activation_to_global_admin.sql`, now replaces that broad gate with an explicit `admin`/`super_admin` requirement. A regression assertion was added to `supabase/tests/security_privilege_assertions.sql`. These are repository changes only: the migration has NOT been applied to the hosted project, and the regression test has NOT yet been replayed against an isolated database. Until the migration is approved and applied, this remains a live-project finding and Stage 1 must not be signed off.

The audit also confirmed the intended helper semantics: `has_platform_role()` includes `admin`, `super_admin` and `league_admin`; `can_administer_location()` grants global admins all locations and `league_admin` only assigned locations; `has_finance_access()` grants `admin`, `super_admin` and `finance_admin`; and captain actions use active captain membership. This role distinction must be preserved in the final role/action matrix.

### Additional RLS privacy finding — location-admin overreach

A second live catalogue review found that several direct-table RLS policies used `has_platform_role()` as an administrator shortcut. That helper deliberately includes `league_admin`, so a location-scoped administrator could query sensitive records outside their assigned location. The affected policy families included player/profile reads, team memberships, fixture team sheets and sheet players, fixture availability, notification events and audit history. `fixture_availability` also grants authenticated clients direct INSERT/UPDATE privileges, making its over-broad admin policy materially more than a read-only concern.

A new forward migration, `20261108221000_scope_sensitive_rls_for_location_admins.sql`, replaces those policies. Self-service player/profile access remains self-only; global admin access remains explicit; team/membership/sheet/availability access is constrained to active team membership, captain authority or the relevant assigned location; notification and audit history are restricted to global admins plus notification owners. Fixture availability direct administrative writes are global-admin-only. The contextual admin RPCs remain the route for location-admin workspaces.

Regression assertions were added to `supabase/tests/security_privilege_assertions.sql` for the new policy names and to ensure the sensitive policies no longer use the platform-wide role helper. This is still repository-only. Neither new migration has been applied to hosted Supabase, and the regression suite has not yet been replayed against an isolated database. These are release-blocking until tested and approved for application.

### Current acceptance position

The live read-only audit has now identified two concrete role-boundary defects and prepared repository migrations/tests for both. This is exactly why the earlier 56-function marker count is not a full security pass. The Stage 1 checklist percentage remains unchanged until the migration/test evidence and remaining session, role-matrix, account-provider and policy checks are completed.
### Follow-on RLS policy composition check

Reviewing the live policy catalogue exposed an important PostgreSQL detail: permissive `FOR ALL` policies also apply to `SELECT`, so narrowing a separate `SELECT` policy alone does not remove broader access. The follow-on migration `20261108221500_remove_platform_wide_location_admin_rls.sql` changes the remaining `*_admin_manage` policies on competition/workflow tables to explicit global-admin-only, then provides separate public/member/assigned-location read policies where needed. It also tightens season registrations, notification preferences, player registration reviews, transfer requests and user-role reads to owner/global-admin boundaries.

The security advisor currently reports three RLS-enabled tables with no policies: `admin_context_preferences`, `gallery_items` and `location_admin_assignments`. A read-only privilege check confirmed that anon and authenticated have no direct SELECT, INSERT, UPDATE or DELETE grants on these tables, so the missing policies do not currently grant client access. The advisor also reports 80 authenticated-executable SECURITY DEFINER functions; these are intentional API RPCs only where their internal guards are correct, and the warning is not itself proof of a vulnerability. The live advisor reports 15 multiple-permissive-policy warnings; some arise from the `FOR ALL` plus `SELECT` policy composition and should be rechecked after the proposed migration is tested/applied.

Regression assertions now check that the sensitive policies and global-admin manage policies no longer rely on `has_platform_role()` for broad access. These migrations remain unapplied to the hosted project and the tests remain unexecuted against an isolated database.
The new `user_roles` self/global-admin SELECT policy uses a dedicated SECURITY DEFINER helper (`has_global_admin_role()`) rather than querying `user_roles` recursively from its own RLS policy. The helper is executable by authenticated users only and derives the caller from `auth.uid()`; no client-supplied user ID is accepted. A regression assertion verifies the policy uses this helper and denies anon execution.
### Protected workspace session boundary implementation

Added `src/lib/auth/use-required-session.ts` as a shared client-side session-state boundary and integrated it into the Captain, Finance and Admin route components. The hook subscribes to Supabase auth-state changes, resolves the initial session without allowing a late initial lookup to overwrite a newer auth event, unsubscribes on unmount, and gates workspace data loading/rendering until authenticated. Unauthenticated users are redirected to sign-in. The Player Hub retains its existing session-aware loader and sign-out state clearing; it is not yet migrated to this shared hook. Database RPC/RLS checks remain authoritative for role and resource permissions, so this client hook is not treated as a substitute for server-side authorization.

GitHub Build verification passed for the shared hook and Captain route commits. Verification for the subsequent Finance/Admin route commits is still running. This does not yet close the full app-wide session checklist item: Player Hub integration, session-expiry/cross-tab behaviour, in-flight request cancellation and direct-route regression checks remain.
### Player Hub sign-out/session-loss cleanup

The Player Hub auth listener now clears player/profile identity, memberships, team requests, team/fixture/availability state, notification preferences/events, transfer options/requests, payment rows, avatar URL, admin flag and edit state when the session is lost. The initial session lookup is guarded against overwriting a newer auth-state event, and asynchronous player/fixture loads verify that the active user ID still matches before writing sensitive results into component state. The full account-switch/cross-tab behaviour still needs end-to-end regression coverage.
### Working role/action matrix — derived from deployed helpers and RPC guards

| Actor | Permitted boundary | Explicitly outside its authority |
|---|---|---|
| Anonymous visitor | Published active locations, published leagues/seasons, approved public teams, published fixtures/results and published gallery assets | Accounts, private player/profile data, memberships, availability, team sheets, finance, admin RPCs |
| Account-only user | Own Auth account/session, own role/profile rows, verified-email player registration workflow | Player privileges, team membership, captain powers, finance or admin workspaces |
| Registered player | Own player/profile data, own team requests/memberships, own availability, own notifications and payment history | Other players' private data, captain actions without active captain membership, admin or finance powers |
| Active team captain | Exact active captain membership's team roster, team fixtures, team availability and team sheets; membership request decisions, squad numbers and captain handover for that team | Other teams, other locations, finance and platform-wide administration |
| Finance admin | Finance options, ledger, summary, Stripe payment review and finance entry actions through finance RPCs | Player identity review, platform roles, location activation, competition administration unless separately granted |
| Location admin (`league_admin`) | Assigned location only: contextual competition/team/fixture/player-register work, scoped team/membership/sheet/gallery access and location-scoped administrative mutations | Other locations, global identity review, global notification outbox/audit, global player bans/profile corrections, location assignment and activation, finance unless separately granted |
| Platform admin / super admin | Platform-wide administrative and location access, global identity reviews, sensitive player corrections, notification operations, audit and location-admin assignments | Super-admin bootstrap cannot be self-appointed; first grant requires a controlled owner-approved process |

The location-admin and global-admin boundaries in this matrix describe the target contract after the pending RLS migrations are applied; the hosted project currently retains the two identified role-boundary defects. This is the current intended contract, not a claim that every RPC has passed a positive/negative test for every row. The final matrix must be reconciled against all exposed RPC signatures and direct-table grants, especially legacy/unused RPCs not called by the current route code.
### CI scope limitation

The repository Build verification workflow runs Deno type checks for Edge Functions, domain unit tests, the TypeScript production build/type check and a Cloudflare Worker dry-run bundle validation. It does not start a Supabase/PostgreSQL instance, apply migration files or execute `supabase/tests/*.sql`. A green workflow therefore verifies application code/build only; it does not validate the new RLS migrations or SQL regression assertions.
### Legacy unscoped admin RPC exposure

The full deployed SECURITY DEFINER inventory identified four older, unscoped read RPCs that were still executable by authenticated users: `get_admin_dashboard()`, `get_admin_player_register(...)`, `get_admin_team_sheets()` and `admin_get_transfer_requests(...)`. Each checked `has_platform_role()` but did not enforce an assigned location. Since that helper includes `league_admin`, a location administrator could call these older endpoints directly and retrieve platform-wide queues/player/transfer/sheet data, bypassing the contextual routes.

The active Admin route calls the contextual replacements instead. Added `20261108222000_revoke_legacy_unscoped_admin_rpcs.sql` to revoke client execution from the four legacy functions, and a regression assertion confirms anon and authenticated cannot execute them. This is a repository-only change pending isolated replay and approved hosted migration.
### Fixture venue location-scope correction

The per-RPC review also found that `admin_create_fixture` verified the venue was active but did not verify that its location matched the fixture's season location. A location admin could therefore create a fixture in their assigned league while attaching another active location as the venue. Added `20261108222500_scope_fixture_venue_to_season_location.sql` to enforce that relationship and a regression assertion in `security_privilege_assertions.sql`. This is repository-only pending isolated replay.
### Captain membership-approval permission correction

The deployed `resolve_team_membership_request` function applied an assigned-location administrator check before its later active-captain check. That ordering unintentionally blocked a captain who was not also a location administrator from approving or rejecting membership requests for their own team. Added `20261108223000_preserve_captain_membership_approval_scope.sql` so the initial scope gate accepts either an administrator assigned to the team location or the active captain of the exact membership's team; the subsequent role check still limits captain decisions to their own team. Added a regression assertion. This migration is pending isolated replay.
The notification delivery Edge Function previously used the legacy `get_admin_dashboard()` RPC solely as its administrator authorization check. Before revoking that legacy RPC, the function was updated to use `admin_get_notification_dispatch_status()`, which already enforces the explicit global-admin role boundary. This preserves the intended manual delivery-worker authorization while allowing the unscoped dashboard RPC to be retired. The Deno type-check in CI covers this Edge Function change.
### Checkout origin configuration correction

The player checkout Edge Function still contained a fallback CORS/allowed-origin value for the retired Lovable-hosted application. Removed that fallback: `APP_ORIGIN` is now required, and checkout returns a configuration error when it is absent rather than accepting the retired host. This keeps the independent Open Play New deployment boundary intact.

## Player Hub account-switch isolation correction — 12 November 2026

A follow-up source review found that the Player Hub auth listener updated the session but only cleared a small subset of cached state on sign-out. It did not reload the full Player Hub dataset when a different account signed in within the same mounted page. That contradicted the earlier session-cleanup acceptance note and could leave stale profile, notification, transfer, payment, avatar or statistics data visible after an account switch.

PR #116 (fix/player-hub-session-isolation-2026-11-12) corrects the route to:
- classify same-user token refresh, account switch and sign-out transitions;
- clear all account-specific Player Hub state before switching identities or signing out;
- reload the full dataset for a newly authenticated user;
- invalidate stale in-flight reads and stale failures using a request-generation guard;
- preserve the current state on same-user token refresh; and
- keep a visible load error rather than redirecting away when protected data could not be loaded.

Unit tests cover the transition classifier. Exact-head build, domain tests, clean local Supabase replay and Chromium/PWA acceptance are pending on the latest PR head. This is a client-side isolation fix; database RPC/RLS remains authoritative. No hosted migration, production identity, merge or deployment was performed.

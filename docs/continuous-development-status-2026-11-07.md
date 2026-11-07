# Open Play — Continuous Development Status

**Last verified:** 7 November 2026, 22:20 UTC  
**Repository:** `openplayfootballleague/OPENPLAYNEW`  
**Supabase project:** `ghnrsysvrlgkjmdlwdmp` (Open Play New only)

## Completed and verified in this development increment

- Supabase database migrations through `captain_squad_number_management` are applied to the new Open Play project. The project reports healthy status and the database health advisor returns no findings.
- Public team registration and membership request RPCs are restricted to authenticated users and require a public season and published league at the database boundary.
- Sign-in returns users to the Player Hub; password-reset emails return users to the dedicated reset-password route; new accounts return to the Player Hub rather than being silently registered as players.
- Player registration now has a distinct completion state and a handoff to the Player Hub.
- Captain availability reads are restricted to the captain's own active squad. The table RLS policy was corrected so one team's captain cannot read the opponent's availability responses.
- Captains can assign or clear optional squad numbers through a SECURITY DEFINER RPC that verifies active captain membership, validates the 1–99 range, writes an audit event, and relies on the unique active squad-number index to prevent duplicates.
- Generated Supabase TypeScript types were refreshed after the new RPCs.

## Verification evidence

- Latest GitHub Actions run: [42420063051](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42420063051) — passed domain tests, TypeScript check, production build, and Cloudflare Worker dry run.
- Five existing domain tests cover 6-a-side/7-a-side starter and substitute limits, duplicate players, and optional/unique/range-checked squad numbers.
- Supabase migration history confirms 19 migrations applied.
- SQL permission check confirms anonymous users cannot execute `get_captain_availability` or `set_team_squad_number`; authenticated execution is granted. The availability policy exists once and its predicate scopes captain reads to their own team membership.
- Supabase health advisor: no findings.
- Supabase security advisor still reports generic SECURITY DEFINER warnings. These functions are deliberately used for protected RPCs and RLS helpers; each has a fixed empty search path, and the application RPCs check the caller's identity/role. Three helper functions remain callable by anon because public-table RLS policies invoke them; with no authenticated UID they return false. This should remain part of the launch security review.

## Not yet verified / remaining

- No controlled end-to-end sign-up, email verification, sign-in, password reset, player registration, team request, captain approval, or squad-number browser test has been completed. A real mailbox and controlled accounts are needed.
- No admin user has been appointed; do not self-grant or seed an administrator without explicit owner authorization and an audited process.
- No production Cloudflare deployment has occurred. CI only performs a dry run.
- Production environment variables and Supabase Auth redirect allow-list still need to be configured and verified in the hosting dashboard.
- Official OP logo asset still needs to be placed in the application repository without recreating it.
- Real Bideford league, season, venue, team and fixture data must be owner-verified before seeding. Do not add demo records to production.
- Finance/Stripe, verified webhook processing, payment reconciliation/refunds, email/SMS notifications, full admin operations, transfer workflows, full team-sheet and matchday lifecycle, and comprehensive acceptance/security tests remain outstanding.

## Next execution priority

Run controlled end-to-end account and player registration tests on a non-production test account, then complete the Player Hub and team-joining/captain approval acceptance path. Continue with admin operational workflows, real Bideford data readiness, payments and notifications. Keep production deployment blocked until all launch gates are verified.

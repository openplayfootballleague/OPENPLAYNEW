# Open Play — Continuous Development Status

**Last verified:** 7 November 2026, 22:31 UTC  
**Repository:** `openplayfootballleague/OPENPLAYNEW`  
**Supabase project:** `ghnrsysvrlgkjmdlwdmp` (Open Play New only)

## Completed and verified in this development increment

- Supabase database migrations through `client_table_privileges` are applied to the dedicated Open Play project. The project reports `ACTIVE_HEALTHY`; the health advisor returns no findings.
- Public team registration and membership request RPCs are restricted to authenticated users and require a public season and published league at the database boundary.
- Sign-in returns users to the Player Hub; password-reset emails return users to the dedicated reset-password route; new accounts return to the Player Hub rather than being silently registered as players.
- Player registration has a distinct completion state and a handoff to the Player Hub.
- Captain availability reads are restricted to the captain's own active squad. One team's captain cannot read the opponent's availability responses.
- Captains can assign or clear optional squad numbers through a SECURITY DEFINER RPC that verifies active captain membership, validates the 1–99 range, writes an audit event, and relies on the unique active squad-number index to prevent duplicates.
- Generated Supabase TypeScript types include the new squad-number RPC.
- **Client table grants corrected:** public browsing tables now grant anonymous SELECT only where RLS policies restrict results to active/published data. Authenticated users have SELECT privileges subject to RLS. Direct client writes are limited to profile UPDATE and fixture-availability INSERT/UPDATE, both protected by self-scoped RLS policies.
- Database permission verification found no unexpected anonymous table SELECT grants; anonymous profile SELECT remains denied; authenticated role/audit-log INSERT remain denied; the anonymous authorization helpers return false without an authenticated identity.\n- **Team-sheet submission hardened:** a submitted sheet is locked in the database; a captain must designate exactly one goalkeeper from the starting players; the database stores the goalkeeper marker, enforces that a goalkeeper is a starter, and enforces one goalkeeper per sheet. The old RPC signature was removed so it cannot bypass goalkeeper selection.\n- Captain UI now includes goalkeeper selection, an availability status for roster members, a final team-sheet review showing starters/substitutes/selected unavailable players, and an explicit confirmation checkbox before submission.

## Verification evidence

- GitHub Actions run [42420063051](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42420063051) passed domain tests, TypeScript check, production build, and Cloudflare Worker dry run.
- GitHub Actions run [42420671012](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42420671012), for the client-privilege migration commit, passed domain tests, TypeScript check, production build, and Cloudflare Worker dry run.\n- GitHub Actions run [42420918796](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42420918796), for the captain team-sheet confirmation UI and route syntax fix, passed all seven domain tests, TypeScript check, production build, and Cloudflare Worker dry run.
- Seven domain tests cover 6-a-side/7-a-side starter and substitute limits, duplicate players, goalkeeper selection, and optional/unique/range-checked squad numbers.
- Supabase migration history confirms 21 migrations applied.
- The Supabase security advisor still reports generic SECURITY DEFINER warnings. The three anonymous-callable helpers are used by RLS policies, have a fixed empty search path, and return false when `auth.uid()` is null. Application RPCs have their own identity/role checks. Keep this in the launch security review; do not blindly revoke helper execution.
- Supabase health advisor: no findings.

## Not yet verified / remaining

- No controlled end-to-end sign-up, email verification, sign-in, password reset, player registration, team request, captain approval, or squad-number browser test has been completed. The new Supabase project currently has zero Auth users; a controlled test account and accessible mailbox are required.
- No admin user has been appointed; do not self-grant or seed an administrator without explicit owner authorization and an audited process.
- No production Cloudflare deployment has occurred. CI performs a dry run only.
- Production environment variables, SMTP delivery, email-confirmation settings and Supabase Auth redirect allow-list still need to be configured and verified in the hosting/Supabase dashboards.
- Official OP logo asset still needs to be placed in the application repository without recreating it.
- Real Bideford league, season, venue, team and fixture data must be owner-verified before seeding. Do not add demo records to production. Bideford is the only launch location; Barnstaple and Torrington remain inactive.
- Saved team-sheet drafts, admin amendments to locked sheets with audit logging, and the complete matchday lifecycle (including reminder delivery) remain outstanding.\n- Finance/Stripe, verified webhook processing, payment reconciliation/refunds, email/SMS notifications, full admin operations, transfer workflows, and comprehensive acceptance/security tests remain outstanding.

## Next execution priority

Run controlled end-to-end account and player registration tests on a non-production test account as soon as an approved test mailbox is available. Then complete the Player Hub and team-joining/captain approval acceptance path. Continue with admin operational workflows, Bideford data readiness, payments and notifications. Keep production deployment blocked until all launch gates are verified.

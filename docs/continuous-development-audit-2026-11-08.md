# Open Play — Continuous Development Audit
**Audit date:** 8 November 2026 (UTC)
**Repository:** `openplayfootballleague/OPENPLAYNEW` only
**Supabase project:** `ghnrsysvrlgkjmdlwdmp` (Open Play New) only

## Scope and safety
This report records a read-only review of the repository and its connected Supabase project. No schema, data, secrets, application deployment, or production settings were changed during this audit. All future work must remain inside this repository and Supabase project. Bideford remains the only intended first-release location; Barnstaple and Torrington must remain inactive.

## Live Supabase observations
- Project status: ACTIVE_HEALTHY.
- Applied migration records: 97.
- Public base tables: 30; all 30 have RLS enabled.
- Auth users: 0.
- Rows in `public.user_roles`: 0.
- The database is empty of real acceptance-test identities and match data.
- The security advisor currently reports 79 SECURITY DEFINER functions executable by the authenticated role. This is a lint warning, not proof of an authorization bypass; every exposed function still needs a complete authorization review.
- The security advisor reports three RLS-enabled tables without direct policies: `admin_context_preferences`, `gallery_items`, and `location_admin_assignments`. Confirm direct client grants are revoked and that the intended RPC-only access path is correctly guarded before treating these as accepted.
- The performance advisor reports unused indexes and multiple permissive-policy overlaps. Do not remove indexes or consolidate policies without workload and semantic regression testing.

## Repository state
The following six pull requests are visible in OPENPLAYNEW and remain open/draft in GitHub metadata at audit time:
- #1 PWA install support and official OP branding. Browser install/offline/cache acceptance on real devices remains outstanding.
- #2 Local migration-ledger reconciliation. Its description documents the earlier 35-migration snapshot; it must be reconciled against the current 97-record Supabase ledger before being considered complete.
- #3 Bideford-only first-release location activation. GitHub currently reports it as not mergeable; investigate the branch/base conflict before any merge.
- #4 Foundation/backend status documentation.
- #5 Admin Dashboard Needs Attention quick navigation. Browser acceptance remains outstanding.
- #6 Stripe test-mode player fixture checkout lifecycle. Current acceptance requirements include CI on the current head, test secrets, checkout/webhook/refund/reconciliation tests, admin refund controls and payout reconciliation.

The latest commit visible on the main branch at the time of this audit is `8fd92113c97dc696362ac4c3c812270dd0c477bf` (documentation update, 7 November 2026 23:36 UTC). The four checked PR head commits returned no combined commit-status contexts through the connected status endpoint. This is not evidence that CI passed or failed; workflow run/job records must be checked separately.

## Verified historical CI evidence
The prior status report records successful GitHub Actions runs for domain tests, TypeScript, production build and Cloudflare Worker dry-run, including runs 42425449833, 42425666119, 42425770535 and 42425944340. These are historical results and do not certify the current heads of PRs #1–#6.

## Outstanding launch gates
1. Reconcile all 97 remote migration records to local migration files and resolve PR #2 against the current ledger.
2. Inspect PR #3's merge conflict and verify Bideford-only activation safeguards remain consistent with the deployed schema.
3. Obtain owner-approved non-production player/admin test identities and an accessible mailbox. Do not self-assign privileged roles or create identities without the required approval.
4. Run authenticated browser acceptance for sign-up, email verification, sign-in, password reset, player registration, team registration, join requests, captain approval, team sheets, goalkeeper selection, result publication/correction, transfers, player database, finance, audit history and admin help.
5. Complete PR #1 PWA installation/cache tests on iOS Safari, Android and desktop using a non-production preview.
6. Complete PR #5 browser and keyboard-navigation acceptance.
7. Complete PR #6 Stripe test-mode checkout, webhook idempotency/retry, failure/cancellation/expiry, refund and fee/net reconciliation tests. Configure test secrets only through an approved secret-management route; never commit secrets or enable live payments.
8. Complete notification provider configuration and controlled test delivery. Keep automatic dispatch disabled until provider credentials, sender configuration and owner approval are confirmed.
9. Verify Bideford venue, league, season, teams and fixtures before any data seeding.
10. Configure production environment variables, Auth redirects, hosting, monitoring and operational support. Production deployment remains a separate final gate requiring explicit approval.

## Next execution priority
Reconcile the current 97-record Supabase migration ledger with the repository's local migration files and determine the exact scope of PR #2's outdated 35-record snapshot. Continue with independent code and CI review while preserving the production and security gates above.


## Migration-ledger reconciliation — follow-up verification (8 November 2026)
A fresh read of the live Supabase migration ledger and GitHub recursive trees materially changes the assessment of PR #2:
- Live Supabase ledger: **97 records**.
- `main`: **62** local `supabase/migrations/*.sql` files.
- PR #2 head (`chore/reconcile-supabase-migration-ledger-2026-11-07`): **35** local migration files.
- Comparing normalized migration names (removing the leading local timestamp) gives **96 distinct remote names**, because the live ledger contains two records named `admin_fixture_management`.
- **37 distinct live migration names have no matching local filename on main**. These include Bideford-only activation, player appearance tracking, Stripe checkout/refunds/webhook processing, finance role/summary functions, further security hardening, admin location scoping, and gallery privacy.
- Three local filenames on main have no same-named remote ledger entry: `finance_balance_semantics`, `audit_log_deny_all_policy`, and `fixture_goal_records_deny_all`. Their semantics/version mapping must be checked, not discarded.
- The remote ledger contains two separate `admin_fixture_management` records (versions `20261107224311` and `20261107224351`). They must remain separate history entries even if their SQL content is identical.

**Disposition:** PR #2 is not ready to merge. Its stated 35↔35 reconciliation describes an earlier ledger state and does not cover the current 97 applied records. Do not merge it, rerun migrations, edit the live migration ledger, or rename/delete files on the basis of name-only matching.

**Safe next step:** inventory all migration files across the relevant OPENPLAYNEW branches/PR heads; retrieve the exact SQL blobs for each live-missing migration where present; match by content and history (including duplicate versions); then create a reviewed, deterministic local filename/snapshot reconciliation on a dedicated branch. Any live migration with no recoverable SQL source must be explicitly reported as an unreconciled historical migration, not reconstructed speculatively.

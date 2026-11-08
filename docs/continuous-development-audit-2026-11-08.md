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


## Cross-branch migration coverage — PR #6 head (8 November 2026)
Recursive Git tree inspection of all six open PR heads found migration-file counts of #1: 35, #2: 35, #3: 39, #4: 59, #5: 62 and #6: 92. PR #6 is the broadest migration-bearing branch, but it is still not an exact representation of the live ledger.

Against PR #6's 92 migration files, normalized-name comparison found these live ledger entries without a matching local file:
- `admin_fixture_management` — **two separate applied versions** (`20261107224311`, `20261107224351`); neither is preserved by PR #6's local filename set.
- `first_release_bideford_location_policy`.
- `fixture_player_appearance_tracking`.
- `finance_options_for_finance_roles`.
- `finance_summary_team_balance_rollup`.
- `audit_log_explicit_deny_policy`.
- `fixture_goal_records_explicit_deny_policy`.
- `location_admin_assignments`.

PR #6 also has three local migration names without same-named live ledger records: `finance_balance_semantics`, `audit_log_deny_all_policy`, and `fixture_goal_records_deny_all`. This is a name-level comparison only; the files may correspond to differently named applied versions, so inspect SQL and version history before concluding they are unapplied or safe to omit. The separate PR #3/#4 trees contain some of these earlier local-only / Bideford files, but no cross-branch exact one-to-one reconciliation has yet been demonstrated.

**Current conclusion:** no available PR head has been verified as a complete, exact, safe 97-record migration source. PR #2 is stale; PR #6 is closest but still has unresolved historical coverage. Do not merge PR #2 or #6 as a migration-ledger fix, and do not apply any of these SQL files to the live project as part of reconciliation.


## Pull-request freshness and CI checks — 8 November 2026
Fresh PR metadata/compare checks:
- PR #3 (`feat/bideford-only-location-activation-2026-11-07`) is **diverged** from `main`: 3 commits ahead and 133 behind; GitHub reports `mergeable=false`. Its own PR description says automated CI and admin-account E2E testing are pending. Rebase onto current main, resolve conflicts, then rerun the Bideford-only migration/policy/UI checks; do not force-merge.
- PR #6 (`feat/stripe-test-checkout-lifecycle`) latest observed head is `99dcc76e64a8c34e92616cf8241a41748fa23904`, 215 commits, 61 changed files, and GitHub reports `mergeable=false`. Its latest recursive tree contains 92 migration files. A direct GitHub check-runs lookup for that exact head returned zero check runs; this is **no recorded check-run evidence**, not a passing CI result.
- The main CI workflow currently installs locked dependencies, type-checks only `supabase/functions/deliver-notifications/index.ts`, runs `npm test`, runs `npm run build`, and performs a Cloudflare Worker dry-run. It does not currently type-check the Stripe Edge Functions on `main`; PR #6 modifies the workflow and must be checked at its latest head before relying on that addition.

**Disposition:** both PR #3 and PR #6 require rebase/conflict resolution and fresh checks before merge. No merge or deployment was performed. The audit branch remains documentation-only.


## Further work completed — source inventory and Stripe code review (8 November 2026)
### Migration source inventory
- Created and verified `docs/supabase-migration-source-reconciliation-2026-11-08.md` on this documentation branch.
- Inspected migration directories from `main`, PR #2, PR #3 and PR #6. The union contains 128 file entries across refs (including duplicate copies of the same migration across branches).
- Name matching covers **91 of the 97 live ledger records**. Six exact-name SQL sources were not found in those inspected trees: `fixture_player_appearance_tracking`, `finance_options_for_finance_roles`, `finance_summary_team_balance_rollup`, `audit_log_explicit_deny_policy`, `fixture_goal_records_explicit_deny_policy`, and `20261108190000_location_admin_assignments`.
- The two live `admin_fixture_management` versions are represented separately in PR #2's timestamped snapshot. The Bideford-only migration is present in PR #3.
- The three differently named local migrations (`finance_balance_semantics`, `audit_log_deny_all_policy`, `fixture_goal_records_deny_all`) are still unresolved as semantic equivalents, not counted as replacements.
- This is **name-level source coverage only**. SQL contents have not yet been hash-compared with the exact applied migrations. No live migration history was edited and no migration was run.

### Stripe static review
- Created `docs/stripe-test-checkout-static-review-2026-11-08.md` on this documentation branch.
- Identified three code-level acceptance blockers in PR #6: (1) failed/expired checkout attempts cannot reliably be restarted and `checkout_attempt` is never incremented; (2) the `charge.succeeded` webhook path records fee/net but does not transition the payment to paid; (3) checkout completion does not compare Stripe amount/currency/session identity with the stored payment record before marking it paid.
- These are static findings, not executed test failures. PR #6 must be corrected and tested before checkout is accepted or enabled.

### Master requirements / previous evidence review
- The Library contains the full application audit (`Open-Play-Full-Application-Audit-v2.md`), Stage 2 completion evidence, final admin-phase evidence, final acceptance preparation and production-readiness checklist. These are supporting historical reports, not all current-head verification.
- The audit reinforces that account creation is not player registration; the registration → player → team journey and genuine-data acceptance remain key launch gates. The master prompt itself was not located as a dedicated file in the repository docs inspected so far.

**No code implementation, merge, deployment, Stripe secret configuration, test account creation, or production data change was made in this follow-up.**

**Project-boundary note:** the Library reports include material from the earlier Lovable/live application. They are historical context only and are not treated as evidence that OPENPLAYNEW contains or has accepted those features. OPENPLAYNEW's repository, Supabase project and current branch evidence remain the sole implementation source of truth for this development run.


## Fresh PR #6 CI recheck — 8 November 2026
A later refresh of PR #6 metadata shows its head at `e69178622ef00a520c4fac0057322062dd0657d0`; GitHub now reports `mergeable=true` (still draft). The exact head has one completed `Build verification` workflow run, **42435119130**, with the single `build` job successful. All recorded steps passed: locked dependency install, Deno setup, Supabase Edge Function type-check, domain tests, TypeScript/build, and Cloudflare Worker dry-run. This supersedes the earlier zero-check-runs observation for the previous head. It does not clear the three static checkout/payment findings documented separately, nor does it constitute end-to-end Stripe acceptance. No merge was performed.


## Fresh CI sweep across all six open PR heads — 8 November 2026
A direct GitHub check-runs lookup on each current PR head returned one completed successful `build` check for every PR:
- #1 PWA branding/install — success; real-device acceptance remains open.
- #2 migration filename reconciliation — success; scope remains stale/incomplete against the current 97-record ledger.
- #3 Bideford-only activation — success; branch remains non-mergeable/diverged and authenticated admin acceptance is pending.
- #4 foundation/status documentation — success.
- #5 Needs Attention navigation — success; browser/keyboard acceptance remains open.
- #6 Stripe checkout — success; static lifecycle/financial-integrity findings and end-to-end payment acceptance remain open.

CI success establishes the current build workflow passed; it does not substitute for real-device, authenticated-role, migration-content, or Stripe integration acceptance. All six PRs remain drafts at this check. No PR was merged.


## Latest follow-up — 8 November 2026
- Expanded the migration recovery search to all nine visible branches (128 distinct SQL filenames). The same six applied migration sources remain absent; GitHub path history returned no commits for their expected filenames. Three later files appear conceptually related (finance balance semantics, audit-log deny policy, fixture-goal-record deny policy), but they are not the original SQL and have not been treated as exact replacements. The migration report now records this and the safe recovery route.
- Expanded Stripe review to a fourth blocker: PR #6 does not add a player-facing route/component that actually invokes the checkout Edge Function or presents payment history. The current Player Hub only handles a return query string; that is not an end-to-end checkout UI. The final RPC migration also requires an active captain, so the intended payer role must be settled and the UI must reflect server enforcement.
- PR #6's static review now has four acceptance blockers: retry lifecycle, `charge.succeeded` paid-state transition, checkout amount/currency/session verification, and missing player-facing entry point/payment history.
- No original migration SQL was fabricated; no application code or database changes were made in this continuation.

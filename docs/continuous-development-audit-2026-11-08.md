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


## Source-restoration action — Bideford policy migration
The live Supabase ledger includes `first_release_bideford_location_policy`, but `main` did not contain its applied SQL source. The original divergent PR #3 branch contained the exact source. To avoid merging its 133-commit-behind branch, a clean branch was created from `main` and the exact migration file was restored byte-for-byte:
- Branch: `fix/restore-bideford-location-policy-source-2026-11-08`
- Commit: `cb6c4793d43665ee32dae649de8a5d86e0286d4f`
- Source blob SHA (same on original branch and restored branch): `0f039bc23f94cebf0d5cd9094fd67d13d65f0195`
- PR #7: https://github.com/openplayfootballleague/OPENPLAYNEW/pull/7
- PR #7 is draft; no check-runs were available at the first post-create check. It is not merged. This is source restoration only, not a migration re-run or a change to the live location state.

This leaves the small admin activation UI changes from PR #3 unported. They must be ported against the current `main` version of `src/routes/admin.tsx` separately and tested; the stale PR #3 branch must not be merged wholesale.


## Live first-release location policy spot-check
Read-only Supabase inspection against `ghnrsysvrlgkjmdlwdmp` confirms:
- `locations` currently contains **zero rows**. Therefore no Bideford location is currently active or configured in this project; the admin UI will need an authorised location creation before activation can be exercised.
- The database check constraint `locations_first_release_active_bideford_check` restricts active rows to town `Bideford`.
- The unique partial index `locations_single_active_first_release_idx` allows at most one active location.
- `admin_set_location_active` and `admin_create_location` are executable by `authenticated` and `postgres`; no `anon` execute grant was returned.
- The live `admin_set_location_active` function also calls `can_administer_location(p_location_id)` before the platform-role check, reflecting the later location-admin scope hardening. The restored original migration remains the historical source; subsequent scope migrations remain authoritative for the current function body.

PR #7's current-head build check was observed in progress at the last poll. No live rows or activation state were changed.


## Stripe progress — 8 November 2026
PR #6 now has captain-only Player Hub checkout and personal payment-history UI, hardened webhook settlement validation and seven regression tests for session/charge validation. Latest CI run `42435790150` passed all steps including Edge Function type-check, domain tests, TS/build and Cloudflare dry-run. PR remains draft and unmerged.

The remaining retry-lifecycle defect requires a new atomic server-side transition and a properly generated migration source. The available connected tooling does not expose the Supabase CLI `migration new` workflow; I have not fabricated a migration filename or edited an already-applied migration to bypass that requirement. This is the next technical blocker to resolve. No database schema or live payment state was changed during this continuation.


## Admin Needs Attention navigation consolidation — 8 November 2026
Ported the four admin summary shortcuts and their target section IDs onto the current-main-based Bideford policy PR #7, retaining the Bideford activation controls. Keyboard focus styling and accessible labels were included. The older PR #5 was closed as superseded; its navigation changes are preserved in PR #7. PR #7's latest head `36e3247380eb2b8289a468d27b4c76eff08e9b1d` has a new build verification run `42435893691` in progress at the last check. Browser acceptance remains outstanding.


## Latest build verification — 8 November 2026
- PR #7 latest head `36e3247380eb2b8289a468d27b4c76eff08e9b1d`: workflow run `42435893691` completed successfully. Deno Edge Function type-check, domain tests, TypeScript/build and Cloudflare Worker dry-run passed. The Bideford activation UI, restored migration source and Needs Attention shortcuts compile together. PR #7 remains draft pending browser/admin acceptance and review.
- PR #6 latest head `f09481620c8e90759ca3dac872a3477efa586a01`: workflow run `42435790150` completed successfully with Edge Function type-check, domain tests, TypeScript/build and Cloudflare dry-run all passed. Stripe test flow remains draft pending retry migration, test secrets/accounts, Stripe event tests and browser acceptance.
- PR #5 is closed as superseded; its shortcut-navigation work is included in PR #7.

- Ported the `FIRST_RELEASE_LOCATION_POLICY.md` documentation from stale PR #3 onto PR #7 as well. PR #7 now carries the historical migration source, guarded admin activation UI, accessible Needs Attention shortcuts and the policy documentation. Its latest code-bearing head `36e3247380eb2b8289a468d27b4c76eff08e9b1d` passed CI; the subsequent documentation-only commit does not trigger a new build. No location rows have been created or activated.

- Closed stale PR #3 as superseded after porting all three of its changed files (Bideford migration, admin activation UI, and policy documentation) to PR #7. No changes were merged from its diverged branch.

- PR #6 current head `1b6b0fa412aed40f6a9c45ec05263a8a22ba82d3` passed CI run `42436207960` after the Stripe settlement hardening. The workflow passed Edge Function type-check, domain tests (including 12 settlement regression cases), TypeScript/build and Cloudflare dry-run. The retry-attempt transition and live test-mode acceptance remain open.

- Exact CI log inspection for PR #6 run `42436207960`: 5 Vitest files passed, 48 total tests passed (including all 12 Stripe settlement tests); Deno type-check, Vite/TypeScript production build and Cloudflare Worker dry-run all succeeded.

- Updated stale PR #2's description to explicitly mark its 35-row migration snapshot superseded and warn not to merge its 157-commit-behind branch. It remains open as historical source-candidate evidence while six original applied SQL sources are unrecovered.


## Stripe retry blocker closed in code — 8 November 2026
PR #6 now implements atomic retry of expired/failed checkout attempts using the existing `checkout_attempt` column and a compare-and-set update; no new migration was needed. Checkout sessions are reused while open, attempts increment once on retry, and unique idempotency keys are derived from the attempt. Session and PaymentIntent metadata bind webhook events to the exact attempt; stale events from older attempts are acknowledged without mutating the current payment. The webhook also uses a compare-and-set payment snapshot to protect concurrent retries and preserves paid/refunded terminal states.

Latest code-bearing PR #6 head `d15f48f59e3693c517a139ea0cb54920696a477c` passed run `42436764026`: Deno type-check, 67 tests across 6 files (27 Stripe-specific), TypeScript/Vite production build and Cloudflare Worker dry-run. Test-mode Stripe/browser acceptance is still blocked by missing test secrets and an approved test identity; hosted Edge Functions remain checkout v1/webhook v5 and have not been deployed with the new code. Admin refund controls and payout reconciliation remain incomplete.


## Advisor recheck — 8 November 2026, 02:03 UTC
- Supabase health advisors returned no findings.
- Security advisors continue to report 3 RLS-enabled tables with no direct policies: `admin_context_preferences`, `gallery_items`, `location_admin_assignments`. A separate read-only `information_schema.table_privileges` query returned no direct `anon`, `authenticated` or `PUBLIC` grants for these tables, consistent with their RPC-only access model. These are INFO findings, not demonstrated direct Data API access.
- The authenticated SECURITY DEFINER warning count remains 79. This warning alone does not establish a bypass; continue function-by-function authorization review. Do not blanket-revoke intended authenticated RPCs.
- Performance advisors continue to report unused indexes and multiple permissive RLS policies. No changes made because the hosted database is empty and query workload/semantics have not been established.


## New migration deployability blocker — 8 November 2026
The latest hosted ledger snapshot is 98 rows, not 97. Across all 10 visible branches (129 distinct migration files), 92 ledger rows have a source candidate and six applied SQL sources remain missing. More importantly, 56 of the 92 candidates have a local filename version prefix that differs from the actual ledger version. The current PR #6 branch has 93 migration files, zero matching leading version prefixes and nine duplicate version prefixes. Gallery migrations illustrate the mismatch: live versions `20261108012459`/`20261108012537`, local filenames `20261108270000_...`/`20261108280000_...`.

This is a **deployment blocker**: do not run `supabase db push` or treat the current migration tree as a valid baseline. Do not bulk-rename by name alone; recover authoritative SQL history, map each source to its exact ledger version, resolve duplicates and verify content before creating a unique, ledger-aligned migration directory. No migration rename/re-run or live DB write was performed.


## Canonical OP logo asset integration blocker
The exact canonical orange connected OP monogram is present in the user's Library as `Vivid Orange Sporty Op Monogram.png` (1254×1254, transparent background); I inspected the original asset and confirmed it is the single intended OP mark. The current repository `public/open-play-logo.png` remains an older horizontal asset (208×115), so the app header/PWA branding is not yet verified against the canonical source. The available GitHub file-creation action accepts text/base64 strings, but the file connector exposes the materialized image only as an opaque image pointer; there is no safe binary pass-through to the repository in this session. I have not redrawn, approximated, recompressed or substituted the logo. Exact binary upload is still required before branding acceptance.


## Public Gallery implementation and hosted verification — 8 November 2026
PR #6 now includes the public Gallery route, admin upload/publish controls, and a `public-gallery` Edge Function. The hosted function is deployed as version 2 with `verify_jwt=true`; its deployed source was compared with the current PR branch and is identical. Read-only Supabase checks confirm the `open-play-gallery` bucket is private, limited to 10 MB and JPG/PNG/WebP, with storage policies allowing public reads only for published gallery items and assigned-admin access to location-scoped objects. The two gallery migrations are present in the live 98-row ledger.

The project currently has **zero active locations and zero gallery items**, so real public gallery content/URL acceptance cannot yet be exercised. No images were uploaded and no location was activated. The gallery migration local filename prefixes do not yet match their actual ledger versions; this is covered by the migration deployability blocker above.

- Follow-up: the `player_team_request_status_rpc` migration source has been restored on PR #6 under the actual live ledger version `20261108020706_player_team_request_status_rpc.sql`, replacing the mismatched `20261108021000_...` filename. This raises exact prefix alignment on that branch from zero to one; the other mismatches and nine duplicate prefixes remain open.

- PR #6 latest head `0754c34f9d3b2f1bdaed79c9d0905145b26d6ba8` passed CI run `42437517983`: Deno type-check, 74 tests across 7 files, TypeScript/Vite build and Cloudflare Worker dry-run. The earlier type-check failures in the new admin context selector and team-request status types were corrected; current head is green.


## Latest Supabase advisor and RPC security spot-check — 8 November 2026
Fresh security/performance/health advisor results:
- 3 tables remain RLS-enabled with no direct policies: `admin_context_preferences`, `gallery_items`, `location_admin_assignments`. A direct privilege check confirms **anon and authenticated have no SELECT/INSERT/UPDATE/DELETE table privileges** on these tables. They are accessed through guarded RPCs/service-role paths; the advisor finding is informational, not a direct table-exposure issue.
- 80 authenticated-executable `SECURITY DEFINER` functions are flagged for review. This is a warning requiring a full function-by-function guard/search-path audit, not proof of a bypass.
- 52 unused-index notices and 15 multiple-permissive-policy notices remain. Do not drop indexes or consolidate policies without workload and semantic tests.
- Health advisor returned no lints.
- Read-only source inspection confirms `admin_register_gallery_item` and `admin_set_gallery_item_published` call `assert_admin_location_context`; `get_admin_gallery_items` checks platform role and `can_administer_location`; `get_my_team_request_statuses` filters strictly to `auth.uid()`. These new RPCs are executable by `authenticated` and `postgres`, not `anon`.


### SECURITY DEFINER function triage
A read-only SQL triage of all 80 authenticated-executable SECURITY DEFINER functions found: all 80 have an explicit function `search_path` setting; 79 contain `auth.uid()` checks; the remaining function is `get_admin_stripe_payments(uuid)`, which gates access through `has_finance_access()`. 53 include an explicit platform/location/finance role-scope helper. No function was found lacking both `auth.uid()` and a role/scope guard by this simple pattern scan. This is a useful triage signal, **not** a substitute for reviewing all 80 function bodies, nested helper behavior, argument validation and cross-tenant data boundaries.


## Continuous execution session — live verification addendum (8 November 2026, 02:15 UTC)

This addendum supersedes any earlier point-in-time counts in this report where they differ.

### Live database snapshot
- Supabase project `ghnrsysvrlgkjmdlwdmp` remains `ACTIVE_HEALTHY`.
- `supabase_migrations.schema_migrations`: **98 rows** (read-only SQL count).
- Public tables: **30**, all **30/30 RLS enabled**.
- Auth users: **0**; `public.user_roles`: **0**. No approved authenticated acceptance identities or production-like match data exist in this project.
- Storage buckets: **2**; scheduled cron jobs: **2**.
- Active Edge Functions: `deliver-notifications` v8, `create-player-checkout` v1, `stripe-webhook` v5, `public-gallery` v3. The public-gallery hosted function is not yet demonstrated to match the latest repository source; verify before changing it.

### SECURITY DEFINER ACL and search-path verification
A read-only catalog query across public functions returned:
- 95 total `SECURITY DEFINER` functions.
- 80 executable by `authenticated`.
- **0 executable by `anon`**.
- 15 not executable by either client role.
- 0 SECURITY DEFINER functions without an explicit pinned `search_path`.
- 16 functions did not contain one of the direct authorization markers used by the simple scan. Manual inspection of those 16 showed 15 are internal service/trigger functions not executable by authenticated users; the remaining `get_admin_stripe_payments(uuid)` checks `has_finance_access()`. That helper checks `auth.uid()` against `user_roles` and permits only `admin`, `super_admin` or `finance_admin`.
- The 80 authenticated-executable functions remain subject to full semantic review of authorization, input validation, nested helper behaviour and location/season isolation. The advisor warning is not treated as proof of a vulnerability or as automatically accepted.

### Current advisor snapshot
- Security: 3 RLS-enabled/no-policy tables (`admin_context_preferences`, `gallery_items`, `location_admin_assignments`); their direct client table grants are revoked and access is intended through guarded RPCs. 80 authenticated-executable SECURITY DEFINER warnings.
- Performance: 7 unindexed foreign keys, 52 unused-index notices and 15 multiple-permissive-policy notices.
- Health: no lints.
- No security or performance changes were made during this verification.

### CI and release gates
- PR #6 head `0754c34f9d3b2f1bdaed79c9d0905145b26d6ba8` passed workflow `42437517983`: Deno Edge Function type-check, Vitest (7 files / 74 tests), TypeScript/Vite production build and Cloudflare Worker dry-run all succeeded.
- PR #6 remains draft and unmerged. This CI result does not prove hosted Checkout/webhook/refund acceptance.
- Migration source recovery and deployability remain blocked: six exact applied SQL sources are unrecovered; live ledger version prefixes do not match candidate filenames and duplicate local prefixes remain. Do not push/merge a migration baseline or run migrations to production.
- No Auth users, test Stripe credentials, approved test mailbox, production secrets or production deployment were created/configured.

### Execution decision
Continue with independent application work and verification while keeping the migration and production gates closed. The next database-related action is to obtain an authoritative archive of the six missing original migration SQL files, then perform exact content/version reconciliation; do not reconstruct or backdate them.


## Continuous execution session — location guard and hosted-function parity (8 November 2026, 02:18 UTC)

### Bideford activation guard verified against live PostgreSQL
Read-only inspection of `public.admin_set_location_active(uuid, boolean, text)` and the `locations` constraints/indexes confirms:
- RPC requires a non-null authenticated actor, `has_platform_role()`, and `can_administer_location(location_id)`.
- Activation reason is required (5–500 characters).
- Only a location whose trimmed town is Bideford can be activated.
- A transaction advisory lock serialises activation changes; a partial unique index permits at most one active location.
- Deactivation is blocked while the location has a published league or a public, registration-open or active season.
- Successful changes update `locations` and append before/after values plus reason to `audit_log`.
- RPC is executable by `authenticated`, not `anon`. The database also has a Bideford-only check constraint.
- Current live location count remains zero; no location or competition data was seeded.

This verifies the database-side policy shape, not the browser confirmation flow. Admin acceptance still needs an authorised account.

### Hosted Edge Function source parity
Compared the currently hosted `index.ts` with the PR #6 branch source:
- `deliver-notifications` v8: exact source match.
- `public-gallery` v3: exact source match.
- `create-player-checkout` v1: does not match the current PR #6 source.
- `stripe-webhook` v5: does not match the current PR #6 source.

The Stripe functions are intentionally not redeployed: test secrets and test-mode webhook registration are not configured, and no real test checkout has been approved. Treat the hosted versions as older than the current branch and do not rely on source parity until a controlled test deployment is approved.

### Player location/season selection regression coverage
On PR #6, extracted the existing saved-context resolution into a pure helper and added tests for valid saved context, cross-location stale-season rejection, stale-location fallback and empty-location fallback. This is a behaviour-preserving refactor; GitHub Actions workflow `42437938149` for head `31b5615944ddd7665bb47583d27218d35c68622e` was still running at the time of this addendum. No test pass is claimed until that workflow completes.


## Final verification addendum — 8 November 2026, 02:19 UTC

### Direct grants on RLS/no-policy tables
A read-only PostgreSQL privilege check confirmed that `anon` and `authenticated` have **no SELECT, INSERT, UPDATE or DELETE privileges** on any of:
- `admin_context_preferences`
- `gallery_items`
- `location_admin_assignments`

All three have RLS enabled and no direct policies. This confirms the intended RPC-only access boundary at the table-grant layer; each exposed RPC still requires its own authorization and location-scope review.

### Regression-test CI outcome
Workflow `42437938149` completed successfully on PR #6 head `31b5615944ddd7665bb47583d27218d35c68622e`:
- Supabase Edge Function type-check: passed.
- Vitest: **7 test files / 78 tests passed**.
- TypeScript and Vite production build: passed.
- Cloudflare Worker validation (dry run): passed.

PR #6 description has been updated with this evidence. The PR remains draft; CI does not replace browser acceptance, Stripe test-mode acceptance or migration reconciliation.

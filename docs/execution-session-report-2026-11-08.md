# Open Play continuous development execution report — 8 November 2026

**Scope:** `openplayfootballleague/OPENPLAYNEW` only  
**Supabase:** `ghnrsysvrlgkjmdlwdmp` (Open Play New only)  
**Latest verified code head:** `9e3fab4ded9c1f8c7673cd2b2ea6be2d640fead3`

## Completed and verified

### Stripe fixture checkout hardening
- Checkout retry uses a compare-and-set transition over payment status, checkout attempt and previous Checkout session. Stripe idempotency keys are unique per payment attempt.
- Existing open Checkout sessions are reused. Expired/failed sessions can advance to a new attempt; concurrent callers cannot claim the same attempt.
- The Checkout function no longer tells a player that a session is paid before the webhook updates the authoritative payment record.
- Webhook settlement uses compare-and-set predicates over the captured payment status, attempt, session ID and last event timestamp. Delayed events cannot overwrite a newer attempt; conflicting updates release the event lease and return a retryable 409.
- Webhook validation covers payment-record metadata, attempt metadata, Checkout session identity, amount, currency and PaymentIntent. Charge-only settlement, duplicate-event leases, event ordering and refund-state preservation are covered in the Stripe settlement implementation.
- Finance Stripe payment register now displays gross amount, status, refunded amount, Stripe fee, net proceeds and paid date. Fee/net values are populated from verified Stripe balance-transaction webhook events.
- Player-facing captain checkout and own-payment history are present on the PR branch. The RPC enforces active captain membership, not merely UI visibility.

### Bideford first-release and admin work
- PR #7 restores the exact applied Bideford policy migration source byte-for-byte and ports Bideford-only activation/deactivation controls to the current admin page.
- The activation UI requires a reason and explicit confirmation. Future areas remain inactive.
- The same PR includes Needs Attention navigation improvements and a first-release policy guide.
- Live read-only checks confirm the Bideford-only active-town constraint, single-active-location index and server-side activation checks. The designated Supabase project currently has zero location rows; Bideford must be created and activated by an authorised admin before use.

## Automated verification

- Latest PR #6 head `9e3fab4ded9c1f8c7673cd2b2ea6be2d640fead3`: workflow run [42436900182](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42436900182) passed:
  - Supabase Edge Function type-check
  - Vitest domain tests
  - TypeScript and production build
  - Cloudflare Worker dry-run validation
- PR #7 head `cd9178fb39c7ced51b93f710c9be081e2b711c16`: build check passed.
- PR #1, #2, #4 and #5 latest inspected heads also had successful build checks.
- Earlier intermediate Stripe CI runs failed on nullability/scope/type errors. Those failures were investigated and corrected; the latest head above passed.
- No browser, physical-device or Stripe API end-to-end test was run.

## Supabase read-only advisor and security spot-check

- Health advisors returned no findings.
- Security advisors reported three RLS-enabled tables with no direct policies: `admin_context_preferences`, `gallery_items` and `location_admin_assignments`. A separate read-only privilege query returned no direct `anon`, `authenticated` or `PUBLIC` table grants for these tables, consistent with RPC-only access. This is not treated as a vulnerability without contrary privilege evidence.
- Security advisors also reported 79 authenticated-executable SECURITY DEFINER functions. This is a warning category, not proof of an authorization bypass; each function needs body/grant review. Do not revoke execute or alter policy semantics indiscriminately.
- Performance advisors report unused indexes and multiple permissive policies. No indexes or policies were changed because the database is still empty and workload/semantic impact has not been measured.

## Outstanding blockers

1. **Stripe test environment:** configure test-only `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, confirmed `APP_ORIGIN`, and register the Stripe test webhook. No secrets were added in this session.
2. **Stripe end-to-end acceptance:** initial checkout, cancellation, expiry/retry, async failure/retry, success, charge-only settlement, duplicate/concurrent/out-of-order events, partial/full refunds, fee reconciliation and cross-user/unauthorised access.
3. **Finance v2:** finance-admin refund initiation controls and payout-level reconciliation are still incomplete. Current fee/net reconciliation is per charge/balance transaction, not payout settlement.
4. **Browser/admin acceptance:** verify PR #7 activation UI and admin navigation with an authorised admin account.
5. **PWA acceptance:** PR #1 build passes, but install/offline behavior requires real-device browser testing. Its manifest icons and Apple touch icon have not yet been verified against the exact canonical logo asset; do not substitute a recreated logo.
6. **Migration source recovery:** 97 applied ledger rows were rechecked. The union of inspected branches contains 128 distinct migration filenames; six exact original sources remain missing: `fixture_player_appearance_tracking`, `finance_options_for_finance_roles`, `finance_summary_team_balance_rollup`, `audit_log_explicit_deny_policy`, `fixture_goal_records_explicit_deny_policy`, and `20261108190000_location_admin_assignments`. No exact source was recovered from visible branch/path history. Obtain an authoritative archive/export or source backup; do not fabricate or backdate migrations.
7. **Production:** review, merge, configure and deploy only after all required approvals and acceptance tests. No production deployment was performed.

## Safety

- No live Stripe payments, test payments, Auth users, test fixture data, or location records were created.
- No database migrations were applied or rerun.
- No notification messages were sent.
- No secrets were added.
- PR #6 and PR #7 remain draft and unmerged.

## Completion estimate

A verified percentage cannot be calculated from the available evidence because the master requirements do not yet have a complete, measurable acceptance checklist and multiple end-to-end/production gates remain. The last recorded 58% figure was provisional and is not re-labelled as verified here.

## Precise next task

Complete the Stripe test-environment setup through an owner-approved Supabase Dashboard/CLI path, then execute the documented end-to-end payment acceptance matrix using a disposable captain/test fixture. In parallel, implement the finance-admin refund and payout reconciliation workflow with a proper migration generated by the Supabase CLI, not a hand-invented migration file.


## Continuous execution continuation — live authorization review (8 November 2026, 02:30 UTC)

### Current code/CI checkpoint
- PR #6 current head before this documentation update: `8698acc3c6fa5700786a2e4deb1c86eb37b557d2`.
- Exact head workflow run `42438352387` completed successfully: Deno type-check of all four Supabase Edge Functions, 7 Vitest files / 78 tests, TypeScript/Vite production build, and Cloudflare Worker dry-run.
- PR #6 is open, draft, unmerged; GitHub currently reports it mergeable against main. This does not clear migration, integration, security or acceptance gates.

### New confirmed defect: captain membership approval — issue #9
Read-only inspection of the live hosted definitions confirms `resolve_team_membership_request(uuid,text)` calls `can_administer_location(...)` before its own-team active-captain check. The helper does not grant team captains access. Ordinary captains are therefore blocked before their intended authorization path.

Tracked in https://github.com/openplayfootballleague/OPENPLAYNEW/issues/9 and recorded in PR discussion. Required fix is a new forward migration with role-aware authorization and regression tests for own-team approval/rejection, cross-team denial, unauthenticated denial, admin scope and concurrent one-team-per-season protection.

### New confirmed defect: location activation role scope — issue #10
Read-only inspection confirms `has_platform_role()` includes `league_admin`, and `can_administer_location()` permits a league admin assigned to the target location. The live `admin_set_location_active(uuid,boolean,text)` RPC uses both checks without an explicit `admin`/`super_admin` requirement. An assigned league admin can therefore satisfy the database guard even though the agreed UI exposes activation only to global admins.

Tracked in https://github.com/openplayfootballleague/OPENPLAYNEW/issues/10 and recorded in PR discussion. Required fix is a forward migration explicitly requiring `admin` or `super_admin`, preserving all Bideford, single-active-location, deactivation and audit protections, with role-isolation tests.

### Database and deployment safety
- Live Supabase ledger remains 98 records; six exact applied SQL sources remain unrecovered and candidate filename/version reconciliation is incomplete.
- No live database writes, migrations, role grants, test users, secrets, Stripe sessions, location records or production deployments were performed.
- Do not alter historical migrations to fix either issue. Generate forward migrations with the Supabase CLI only after source reconciliation and test planning.

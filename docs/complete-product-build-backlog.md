# Open Play New — Complete Product Build

**Umbrella tracker:** https://github.com/openplayfootballleague/OPENPLAYNEW/issues/37  
**Integration workspace:** `integration/complete-product-build`  
**Base snapshot:** `feat/stripe-test-checkout-lifecycle` at `7b8a72e8988fae6a1284462276c77715466c477d`  
**Status:** Build inventory established; feature integration in progress. No merge or release authorised.

## Development operating model

Repeat steps 1–5 continuously:
1. Select the next incomplete requirement from issue #37 and the authoritative product specifications.
2. Implement on a dedicated, dependency-aware branch; integrate into the shared development workspace only after source/ancestry review.
3. Commit code, migrations, tests and documentation.
4. Update issue #37 and the relevant feature issue/PR with exact scope, commit, tests, dependencies and blockers.
5. Move immediately to the next incomplete requirement.

Run targeted checks for changed code and never leave a known failing check unresolved. Defer the complete cross-product acceptance campaign until the scope is assembled. Keep merge, hosted migrations and release behind the later approval gate.

## Product inventory

The complete feature-level checklist, including the 15-section admin workspace, public/player/captain experiences, location/season lifecycle, registration, competition, finance, analytics, communications, gallery, security and release prerequisites, is maintained in [issue #37](https://github.com/openplayfootballleague/OPENPLAYNEW/issues/37). The authoritative admin requirements remain in `docs/admin-dashboard-location-season-analytics-master-specification.md`.

## Current integration risks

- Existing pull requests are based on several different feature branches. Compare ancestry and merge bases; never merge by PR number or title alone.
- PostHog has competing implementations: PR #29 is consent-gated; PR #35 describes a direct provider and identity configuration. Reconcile to one privacy-first design before integration or enabling capture.
- PR #36 initial-squad validation CI failed on three tests because the fixtures did not preserve the nominated captain and did not exceed the maximum squad size. Corrected tests have been committed to the feature branch; rerun and verify the new head.
- Migration reconciliation and role-scope fixes must remain forward-only and replayable in an isolated database. No hosted migration is authorised.
- The exact canonical OP logo binary, approved non-production Auth Admin test identities, SMTP, Stripe test webhook/secrets and provider privacy settings require approved external paths/configuration.
- Notification dispatch remains inactive; no production data, privileged identities, payments, future-location activations or production deployment may be created as part of this build.

## Status vocabulary

- **Implemented:** code exists on a branch.
- **Integrated:** reconciled into the shared development workspace.
- **Verified:** relevant automated and acceptance evidence passes.
- **Released:** explicitly approved and deployed.

Do not conflate these states or claim completion from a successful build alone.


## Pull-request dependency map (reviewed 8 November 2026)

### Baseline family A — application/Stripe feature baseline
These PRs declare the same base SHA `7b8a72e8988fae6a1284462276c77715466c477d`:
- #36 initial squad validation (head `54efcf302ce829d583e59e27a1facdf0bd329635`, CI green). Safe to port as a domain helper; not yet a complete registration feature.
- #29 consent-gated PostHog foundation (head `f9fe77d4f640692798ddfad11190a7f3156be26b`, previously green). Candidate privacy architecture; route/provider/package changes need reconciliation before porting.
- #32 profile self-service permission regression test (head `4239bd5aea5c13d5b0c72ccc9158562ad24820c7`). Candidate security regression test; must be rerun on its own head.
- #28 migration source reconciliation (base SHA differs: `e7a64f32940dedaba16d0e38453d95b188dbce76`). Treat as a separate migration-history integration lane; do not transplant partial files.
- #6 Stripe test checkout lifecycle is the common feature baseline, but it remains a draft and requires test credentials/identities and E2E acceptance.

### Baseline family B — main
- #13 visual system refresh and #12 admin workspace selector both branch from main SHA `8fd92113c97dc696362ac4c3c812270dd0c477bf`. They can be compared against one another and main; do not assume either includes the Stripe/application baseline.
- #35 PostHog wizard branch also targets main. It is a competing analytics implementation and must not be merged with #29. Select #29's consent-first architecture; port only compatible UI/analytics needs from #35 after review.
- #7 Bideford location policy source restoration targets main and is a security-sensitive migration-source recovery. Reconcile against #28's canonical migration inventory, not independently.
- #21 migration recovery targets the feature baseline but starts from a different base SHA; reconcile through #28's applied-ledger manifest.

### Dependent visual/PWA family
- #27 visual refresh targets the Stripe feature branch but GitHub currently reports it non-mergeable; #13 is its head lineage.
- #26 PWA branding targets the visual refresh branch and is also currently non-mergeable; #1 is the underlying PWA/branding source.
- The correct promotion order is main foundation → Stripe/application baseline → visual refresh → PWA branding, with security/migration changes reconciled against the canonical migration lane. This is a dependency map, not permission to merge any PR.

### Integration workspace policy
The integration workspace is a controlled assembly area. Feature code may be ported only after:
1. checking the exact source head and CI evidence;
2. comparing changed files against the workspace baseline;
3. reviewing overlapping route, package, migration and generated-type edits;
4. preserving one canonical implementation where branches compete;
5. running the relevant targeted tests after each port.

The initial-squad helper and tests from PR #36 are now present in this workspace at commits `193fca0b72055d4a3f61b056a72dfe0cb7ac81bb` and `25c6fa4c5d23b4592968c81824e8a7a8a09be539`. The workspace is not yet a complete runnable integration because it is deliberately not pretending that feature branches with different ancestry have been merged.

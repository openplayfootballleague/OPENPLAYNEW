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

# Open Play release acceptance readiness — 13 November 2026

## Status

The canonical integration candidate is PR #109 at the currently verified head commit `8a970a05a6d200cc9996df61305362d51f684c44`.

Exact-head GitHub Actions run [#43413249238](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/43413249238) completed successfully with all four jobs:
- Application build, Deno type checks, Stripe webhook signature tests, domain tests, migration-source/security configuration checks, and Cloudflare Worker dry-run.
- Clean Supabase migration replay and database security/role/lifecycle regression assertions.
- Chromium responsive-route, manifest and offline PWA checks.
- PostHog consent and network acceptance.

The earlier verified head `5a368326b7e6ceb95612864b53faff57a34b9418` and run [#43409054653](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/43409054653) are historical evidence, not the current head. The earlier referee payment-safety head `dc31eb4e61bdd8696184d454d3b2e5174b88f2c1` and run [#43408070272](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/43408070272) are also historical evidence. The current PR #109 head has its own fresh four-job passing run.

These automated checks are implementation-level CI and targeted browser/security checks. They are not the coordinated full end-to-end acceptance campaign described in the product backlog, and they do not prove that every agreed feature is complete.

This is a release-readiness assessment, not a production approval. PR #109 remains a draft. No production deployment, hosted migration, Stripe resource creation, secret mutation or payment was performed during this assessment.

## Verified external environment

### Supabase project

- Project: `OPENPLAYNEW` (`ghnrsysvrlgkjmdlwdmp`), region `eu-west-1`, status `ACTIVE_HEALTHY`.
- Hosted database currently records 99 migrations, latest `20261108194831_phase1_completion_bundle`.
- The candidate contains 38 additional forward-only migrations. They have passed isolated CI replay, but have not been applied to the hosted project.
- The hosted project currently has four active Edge Functions: `deliver-notifications`, `create-player-checkout`, `stripe-webhook`, and `public-gallery`.
- The candidate's `pay-referee-payout` and `referee-connect-webhook` functions are not deployed to this project. A live webhook round-trip cannot be claimed until a non-production/staging deployment exists and the test endpoint is configured.

### Stripe test mode

Read-only test-mode inspection of the Open Play Stripe account found:
- 0 connected accounts
- 0 Connect transfers
- 0 webhook endpoints

The Connect test onboarding, connected-balance transfer, and signed webhook delivery have therefore not yet been exercised end-to-end. The test account is empty; this is not evidence that the implementation failed.

## Supabase advisor review

The hosted project reports no health advisories.

Security advisories:
- 77 `SECURITY DEFINER` functions are executable by `authenticated`; the advisor reports these as warnings.
- A read-only database inspection found an explicit authorization-check marker in all 77 function bodies, including the finance-access guard in `get_admin_stripe_payments`. This is a static scan, not a substitute for the existing role-boundary regression suite or a full manual audit of every function.
- Three tables (`admin_context_preferences`, `gallery_items`, `location_admin_assignments`) have RLS enabled with no direct policies. Direct table privileges for both `anon` and `authenticated` are absent, so the current posture is deny-by-default; access is expected through guarded RPCs.

Performance advisories:
- 15 tables/actions have multiple permissive RLS policies.
- 7 foreign keys lack covering indexes.
- 52 indexes are currently unused in the empty/near-empty project.
- These are performance-review items, not evidence of a current data exposure. Do not remove indexes or combine policies without workload and regression evidence.

## Required acceptance before release

1. Obtain owner approval for a separately billed Supabase development/staging branch or another isolated staging project. Do not use production for the first live-function test.
2. Deploy the candidate referee Connect functions to that staging target only, after verifying their source SHA and required environment variables. Keep JWT verification enabled for user-facing payout calls; the webhook must use Stripe signature verification.
3. Configure a Stripe **test-mode Connect** webhook endpoint to the staging function URL for the exact events handled by the webhook. Store its signing secret in staging Supabase secrets; never commit or expose it.
4. Create a synthetic Stripe test connected account, complete the test onboarding flow, and verify account capability updates reach the application.
5. Run an authorised end-to-end £22 test transfer. Verify the payout row, immutable attempt/idempotency key, transfer ID, outbox state, connected account balance, and signed webhook receipt. Exercise duplicate delivery, 408/ambiguous response reconciliation, reversal-before-creation, and stale reversal scenarios.
6. Confirm the agreed payout policy: whether £22 is always the transfer amount or whether deductions and the £20 minimum-net policy may apply.
7. Complete manual acceptance on a physical iPhone/iPad and desktop browser, including login, registration, captain flows, admin workflows, privacy/analytics consent, and referee onboarding.
8. Obtain final owner review and explicitly approve the migration/deployment plan. Only then should PR #109 be marked ready for review and merged through the repository's protected process.

## Release decision

**Not ready for production release yet.** The integrated code and automated checks are green. The remaining blockers are staging-cost approval, staging deployment/configuration, Stripe test-mode end-to-end acceptance, payout-policy confirmation, physical-device/owner acceptance, and completion of the wider product feature inventory.

# Open Play — Stripe test checkout static review

**Date:** 8 November 2026  
**Reviewed source:** `feat/stripe-test-checkout-lifecycle`  
**Scope:** static review of `create-player-checkout`, `stripe-webhook`, and the checkout/payment migrations. No Stripe secrets were accessed, no requests were sent to Stripe, no payments were created, and no database writes were made.

## Findings

### 1. Expired/failed checkout cannot be retried — launch blocker

The checkout implementation does not complete the retry lifecycle described in PR #6.

Evidence:
- `payment_records.checkout_attempt` is added with default `0`.
- `create-player-checkout` uses `openplay-checkout-${record.id}-${record.checkout_attempt}` as its Stripe idempotency key, but does not increment `checkout_attempt`.
- `create_player_fixture_payment` returns an existing payment row without changing its status or incrementing the attempt.
- The webhook changes an expired session to `cancelled` and an asynchronous payment failure to `failed`.
- The Edge Function only creates Checkout sessions when the payment status is `pending` or `processing`; a later retry against a `cancelled` or `failed` row returns HTTP 409.

Result: after an expired or failed Checkout, the player cannot start a fresh attempt through this flow. The idempotency key also remains unchanged across attempts. This contradicts the PR description's claim that expired/failed attempts have distinct Stripe idempotency keys.

**Required fix:** introduce a server-authoritative checkout-attempt transition that atomically checks the payment state and any existing Stripe session, increments the attempt exactly once, and returns the new idempotency key. Define which states can be retried and how active/unexpired sessions are reused or expired. Do not simply reset status from the browser.

### 2. `charge.succeeded` does not mark the payment paid — reconciliation defect

The webhook explicitly treats `charge.succeeded` as a payment event and maps it to the payment record, but its handler only records Stripe fee, net amount and payment-intent ID. It does not set `status = 'paid'` or `paid_at`.

Result: if the Checkout Session completion event is absent, delayed, or not delivered successfully while `charge.succeeded` is processed, the payment record can remain pending/processing despite a successful charge.

**Required fix:** on a verified `charge.succeeded`, confirm the charge's payment intent and amount against the payment record, then apply a guarded paid transition and set `paid_at`. Add an isolated test where `charge.succeeded` is the only successful event received.

### 3. Checkout completion does not reconcile charged amount/currency — financial integrity gap

For `checkout.session.completed`, the webhook trusts `payment_status === 'paid'` and the payment-record metadata/client reference. It does not compare Stripe's `amount_total` and `currency` to the stored payment record's `amount_pence` and `currency` before marking the record paid.

**Required fix:** load the payment row and reject/hold the event unless the session ID, payment record, amount, currency and expected payment intent are consistent. Record the mismatch for finance review; do not mark it paid.

## Verification status

- Static source inspection only; no executable or end-to-end Stripe tests run.
- CI check-runs for the latest PR head were not present at the time of review.
- No test credentials or test identities were available to complete checkout acceptance.
- These findings should be fixed and regression-tested before PR #6 is considered mergeable or Stripe checkout is enabled, even in test mode.

## Safety

No source code was changed by this review. No secrets, production settings, database rows, payment records, webhook events, or deployments were modified.


### 4. No player-facing checkout entry point in PR #6 — feature not end-to-end
A fresh changed-file inventory of PR #6 shows the payment work adds the checkout Edge Function, webhook, SQL migrations and generated database types, but no player route/component that invokes `create-player-checkout` or displays a checkout action/payment history. The existing Player Hub source inspected in the PR branch displays a return-from-Checkout query message, but that alone does not start checkout or show the payment ledger.

**Required fix:** add the agreed player/captain-facing entry point and status/history UI, wire it to the Edge Function, and test permission boundaries. Confirm the intended payer model before exposing a payment action: the latest migration requires an active team captain, whereas the original RPC draft was member-scoped. The UI must match the final server-side policy rather than assume every player can pay.


## Follow-up implementation and CI — 8 November 2026
The Stripe test checkout PR now includes a captain-only Player Hub fixture checkout action, personal payment-history/status panel, and extracted pure settlement validators. Webhook processing now verifies checkout session identity and payment-record metadata; checks checkout amount, currency and known PaymentIntent; checks charge amount, currency, paid flag and PaymentIntent; and marks a matching `charge.succeeded` event paid with `paid_at` while retaining fee/net reconciliation. Mismatches are left unprocessed with a finance-review error.

Regression tests cover matching checkout settlement, wrong session ID, wrong payment-record metadata, amount mismatch, currency mismatch, matching charge-only settlement, and mismatched/unpaid charges.

Current-head PR #6 workflow run `42435790150` completed successfully: locked dependency install, Deno setup, Edge Function type-check, domain tests, TypeScript/build and Cloudflare Worker dry-run all passed. This does not constitute Stripe API or browser end-to-end acceptance.

Still open: atomic retry-attempt transition for expired/failed sessions; Stripe test secrets and test account/fixture setup; actual checkout/webhook/refund/fee tests; admin refund controls and payout reconciliation; browser acceptance. No live payments were used.


## Hosted Edge Function deployment check — 8 November 2026
Read-only Supabase function inventory and source retrieval confirms the hosted Open Play New project currently has:
- `create-player-checkout` version 1, `verify_jwt=true`.
- `stripe-webhook` version 5, `verify_jwt=false`.

The hosted sources are older than the current PR #6 branch changes: the deployed webhook does not yet contain the new settlement identity/amount/currency checks or the `charge.succeeded` paid-state transition; the deployed checkout function does not contain a retry-attempt repair. Do not mistake a passing GitHub CI build for a deployed fix. No function deployment was performed because the PR is still draft, test secrets/provider configuration are not available through the connected tools, and no test-mode end-to-end acceptance has been run. Existing `verify_jwt` settings were not changed.


## Latest regression and CI result — 8 November 2026
PR #6 current head `1b6b0fa412aed40f6a9c45ec05263a8a22ba82d3` passed workflow `42436207960`. The workflow completed all steps successfully: Edge Function type-check, domain tests, TypeScript/build and Cloudflare Worker dry-run. The settlement helper suite now has 12 tests, including missing amount on paid Checkout sessions, PaymentIntent metadata mapping and preservation of full/partial refund states. This is not a Stripe API integration test or browser acceptance run.

The remaining checkout retry transition still needs a safe atomic attempt increment and distinct idempotency key after an expired/failed session. No new migration was fabricated; no database schema was changed. The latest hosted Edge Function versions remain checkout v1 and webhook v5, so these branch fixes are not deployed.


## Retry lifecycle implementation — 8 November 2026
The earlier retry blocker has now been implemented on PR #6 without a new migration. The Edge Function reuses an existing open Checkout session, recognizes completed paid sessions as pending webhook confirmation, and uses an atomic compare-and-set update on `payment_records.checkout_attempt` and current status/session to claim exactly one new attempt after an expired or failed/cancelled session. It clears the old session/PaymentIntent references, increments the attempt once, and uses a distinct Stripe idempotency key. A failed attempt can safely be retried with the existing schema column.

Both Checkout Session and PaymentIntent metadata now include the attempt number. The webhook validates payment-record identity, attempt, session/PaymentIntent, amount and currency. It uses a compare-and-set update against the captured payment status, attempt, session id and last event timestamp so a retry cannot race with a delayed webhook. Events from prior attempts are acknowledged as stale without changing the current payment; late failures/successes cannot downgrade paid/refunded states.

PR #6 current code-bearing head `d15f48f59e3693c517a139ea0cb54920696a477c` passed CI run `42436764026`: Deno Edge Function type-check, TypeScript/Vite build, Cloudflare dry-run, and 67 total Vitest tests across 6 files (27 Stripe-specific tests). This is automated test/build evidence; the retry path has not yet been exercised against a real Stripe test account/session because test secrets and an approved disposable test identity are not configured.

The remaining Stripe blockers are test-mode end-to-end acceptance, admin refund controls, payout reconciliation, and deployment after review. Hosted functions remain checkout v1/webhook v5; branch fixes are not deployed.

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

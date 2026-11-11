# Referee Stripe Connect setup

## Implemented foundation

- Active referees can create or resume a UK connected account using Accounts v1 with controller properties (Express Dashboard), from the Referee workspace. The current branch uses Stripe-hosted onboarding; embedded onboarding remains outstanding.
- The connected account is mapped to the referee's internal user ID; bank details remain with Stripe.
- The account onboarding flow requests the transfers capability.
- Account status is synchronized from signed `account.updated` events.
- Match-report and milestone payout obligations have separate records and idempotency identities.
- Transfer attempts are reconciled into the payout ledger; ambiguous attempts must not be blindly retried.
- All current integration work is restricted to Stripe test mode.

## Agreed payout policy

- Each administrator-approved referee match report creates one £22 gross match-fee entitlement.
- The referee must receive at least £20 net. The first £2 of applicable deductions is within the referee allowance; Open Play funds any further top-up.
- Approval triggers an immediate transfer attempt to the eligible referee's connected Stripe balance. It must not wait for a finance administrator to press a payout button or for a periodic batch.
- A connected-balance transfer is distinct from the referee's subsequent bank payout. Stripe controls the connected account's bank payout schedule; the Open Play transfer should be attempted immediately after approval.
- A £50 milestone reward is separate from match fees. An administrator must approve the reward before an immediate transfer attempt is made.
- Correcting or resubmitting a match report must never create a second match-fee entitlement or a duplicate transfer.
- A failed transfer is retryable only after the failure is reconciled and the underlying issue is resolved. An ambiguous/processing transfer is not retryable until its outcome is established.

## Current implementation boundary

The current branch invokes the test-mode transfer workflow from the administrator client immediately after the approval RPC succeeds. This is a best-effort immediate trigger, not a durable server-side outbox: if the browser closes between approval and invocation, the payout remains pending and needs an administrator retry. A durable approval-triggered outbox/worker is still required for unattended reliability. The Edge Function resolves the payout obligation from the approved report, then uses the authenticated administrator's location-scoped database claim. The £50 milestone workflow remains separate and requires a global finance administrator.

The transfer/reconciliation foundations use attempt-specific Stripe idempotency keys and signed webhook confirmation. Ambiguous outcomes remain processing and must be reconciled before retry. A referee without an eligible connected account cannot receive a transfer; the entitlement remains visible for later action.

This is a branch implementation, **not a verified release**. CI, clean migration replay, Stripe test-mode event simulation and browser/device acceptance must pass before it can be marked complete. No live-mode transfer or hosted deployment has been performed.

## Required Supabase Edge Function secrets

Configure these in the Open Play New Supabase project's Edge Function secrets when the test integration is authorised:

- `STRIPE_SECRET_KEY`: Stripe **test-mode** secret key beginning `sk_test_`.
- `APP_ORIGIN`: exact application origin, without a trailing slash.
- `REFEREE_CONNECT_WEBHOOK_SECRET`: signing secret for the dedicated Connect webhook endpoint.
- `REFEREE_PAYOUT_CRON_SECRET`: required only by the current protected payout-worker endpoint; do not expose it to browser code.
- Standard Supabase Edge Function environment values: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`.

Do not place Stripe secret keys or webhook signing secrets in Vite variables, browser code, GitHub files or the public repository.

## Stripe Dashboard test-mode configuration

1. Enable Connect for the Open Play platform account.
2. Use UK domestic Accounts v1 connected accounts with controller properties: `controller.stripe_dashboard.type=express`, `controller.fees.payer=application`, and `controller.losses.payments=application`; request `capabilities.transfers`. This preserves separate platform charges and later transfers, which the current Accounts v2 preview does not support.
3. Create a dedicated test-mode webhook endpoint:
   `https://<project-ref>.supabase.co/functions/v1/referee-connect-webhook`
4. Subscribe only to the connected-account and transfer lifecycle events that the deployed handler explicitly verifies and processes. Confirm the exact event list against the handler before enabling the endpoint; do not assume an event is supported because it appears in an older checklist.
5. Copy the endpoint signing secret to `REFEREE_CONNECT_WEBHOOK_SECRET`.
6. Ensure the platform has sufficient **test-mode** available balance before attempting a transfer.
7. Confirm the platform's fee/loss responsibility configuration in the Stripe Dashboard before any real-money launch.

A referee is eligible for an Open Play transfer when the connected account is correctly linked, required verification is complete, and the Stripe transfers capability is active. `payouts_enabled` is a separate bank-payout status: it must not block a platform-to-connected-account transfer or be presented as proof that the transfer itself has succeeded.

## Acceptance requirements

- Report approval creates exactly one £22 gross entitlement and triggers an immediate transfer attempt when the referee account is eligible.
- An ineligible account leaves the entitlement safely pending with a clear reason; it must not lose or duplicate the entitlement.
- Stable idempotency prevents duplicate transfers on repeated approval, retries, worker replay or corrected report submission.
- A Stripe timeout/ambiguous response is reconciled before another attempt is permitted.
- Signed webhook processing is replay-safe, validates transfer identity, destination and amount, and cannot let stale events overwrite a newer successful attempt.
- A definitive transfer failure is visible to administrators and can be retried only after reconciliation.
- Milestone rewards require a separate administrator approval and cannot be triggered by match-report approval.
- Referees can see match-fee entitlement, connected-balance transfer and bank-payout status as distinct states.
- CI covers account readiness, role restrictions, amount calculation, immediate trigger, idempotency, failed/ambiguous transfer recovery, webhook replay/reversal and milestone approval without calling Stripe.
- Browser/device acceptance verifies the referee and finance/admin views.

## Release safety

- Keep the integration test-mode-only until all acceptance requirements pass.
- Do not add a live Stripe key, create live connected accounts, initiate live transfers, deploy migrations or enable unattended transfer processing without explicit release approval.
- Never claim that a transfer to a connected Stripe balance means the money has already reached the referee's bank.

# Referee Stripe Connect setup

## Implemented foundation

- Active referees can create or resume a UK Express connected-account onboarding link from the Referee workspace.
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

The existing Stripe Connect implementation provides onboarding, account readiness, payout records and transfer/reconciliation foundations. The current finance-controlled payout flow is **not yet the final agreed operating model**: the approval-to-immediate-transfer trigger, automatic retry/reconciliation policy and corresponding end-to-end acceptance tests must be completed before this policy can be marked implemented.

Do not describe the immediate-transfer requirement as live or complete until the trigger and its tests are merged and verified.

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
2. Use UK domestic connected accounts with the approved recipient/Express onboarding configuration.
3. Create a dedicated test-mode webhook endpoint:
   `https://<project-ref>.supabase.co/functions/v1/referee-connect-webhook`
4. Subscribe only to the connected-account and transfer lifecycle events that the deployed handler explicitly verifies and processes. Confirm the exact event list against the handler before enabling the endpoint; do not assume an event is supported because it appears in an older checklist.
5. Copy the endpoint signing secret to `REFEREE_CONNECT_WEBHOOK_SECRET`.
6. Ensure the platform has sufficient **test-mode** available balance before attempting a transfer.
7. Confirm the platform's fee/loss responsibility configuration in the Stripe Dashboard before any real-money launch.

A referee is eligible for an Open Play transfer only when the connected account is correctly linked, verification requirements are satisfied, and the Stripe transfers capability is active. Bank-payout readiness is a separate status and must be communicated separately; it must not be confused with the platform-to-connected-account transfer.

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

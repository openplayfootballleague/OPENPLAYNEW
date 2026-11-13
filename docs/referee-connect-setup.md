# Referee Stripe Connect setup

## Implemented foundation

- Active referees can create or resume a UK connected account using Accounts v1 with controller properties (Express Dashboard), from the Referee workspace. The current branch uses Stripe's embedded Account Onboarding component through Connect.js and Account Sessions. It requires the public `VITE_STRIPE_PUBLISHABLE_KEY` to be configured in the frontend build environment.
- The connected account is mapped to the referee's internal user ID; bank details remain with Stripe.
- The account onboarding flow requests the transfers capability.
- Account status is synchronized from signed `account.updated` events.
- Match-report and milestone payout obligations have separate records and idempotency identities.
- Approved match-fee entitlements are transactionally inserted into a private payout-transfer outbox; a Vault-backed `pg_cron` / `pg_net` dispatcher invokes the service-role worker every minute. The worker leases jobs with `SKIP LOCKED` and uses the same attempt-specific Stripe idempotency keys.
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

The current branch invokes the test-mode transfer workflow from the administrator client immediately after the approval RPC succeeds for low latency. Independently, the payout row's insert trigger creates a durable outbox job in the same database transaction as approval. The scheduled worker processes queued jobs without an open admin browser. The browser call and worker share the same payout status claim and Stripe idempotency key, so they cannot create separate transfer attempts for the same claimed attempt. The Edge Function resolves the payout obligation from the approved report, then uses the authenticated administrator's location-scoped database claim. The £50 milestone workflow remains separate and requires a global finance administrator.

The transfer/reconciliation foundations use attempt-specific Stripe idempotency keys and signed webhook confirmation. Ambiguous outcomes remain processing and must be reconciled before retry. A referee without an eligible connected account cannot receive a transfer; the entitlement remains visible for later action.

This is a branch implementation, **not a verified release**. CI, clean migration replay, Stripe test-mode event simulation and browser/device acceptance must pass before it can be marked complete. No live-mode transfer or hosted deployment has been performed.

## Required Supabase Edge Function secrets

Configure these in the Open Play New Supabase project's Edge Function secrets when the test integration is authorised:

- `STRIPE_SECRET_KEY`: Stripe **test-mode** secret key beginning `sk_test_`.
- `VITE_STRIPE_PUBLISHABLE_KEY`: Stripe **test-mode** publishable key beginning `pk_test_`, supplied only to the frontend build. This is public and must never contain a secret key.
- `APP_ORIGIN`: exact application origin, without a trailing slash.
- `REFEREE_CONNECT_WEBHOOK_SECRET`: signing secret for the dedicated Connect webhook endpoint.
- `REFEREE_PAYOUT_CRON_SECRET`: required by the protected payout queue worker and payout-transfer function; do not expose it to browser code.
- Standard Supabase Edge Function environment values: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`.

Add `open_play_supabase_url`, `open_play_service_role_key`, and `referee_payout_cron_secret` to Supabase Vault for the scheduled dispatcher. The dispatcher remains a no-op until all three Vault values and the Edge Function secrets are configured.

Do not place Stripe secret keys, Supabase service-role keys or webhook/cron signing secrets in Vite variables, browser code, GitHub files or the public repository.

## Stripe Dashboard test-mode configuration

The referee workspace loads the official Connect.js script from `https://connect-js.stripe.com/v1.0/connect.js` and mounts Stripe's `account-onboarding` embedded component. The server creates a fresh Account Session (`/v1/account_sessions`) for every initial or refreshed client-secret request. Do not expose the Account Session secret beyond the signed-in referee's browser session. Stripe's embedded components require the Stripe script and frame origins in any custom Content Security Policy; this application currently does not add a restrictive custom CSP.

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
- A Stripe timeout/ambiguous response is reconciled before another attempt is permitted. Expired leases are reconciled with the same Stripe idempotency key, without incrementing the payout attempt, and only inside a conservative 23-hour window. A 409 idempotency-in-progress or 429 rate-limit response remains `processing`; after the safe window, the job is held for explicit reconciliation rather than risking a duplicate transfer.
- Signed webhook processing is replay-safe, validates transfer identity, destination and amount, and cannot let stale events overwrite a newer successful attempt.
- A definitive transfer failure is visible to administrators and can be retried only after reconciliation.
- Milestone rewards require a separate administrator approval and cannot be triggered by match-report approval.
- Referees can see match-fee entitlement, connected-balance transfer and bank-payout status as distinct states.
- CI covers account readiness, role restrictions, amount calculation, transactional outbox enqueue, worker lease/release, idempotency, failed/ambiguous transfer recovery, webhook replay/reversal and milestone approval without calling Stripe.
- Browser/device acceptance verifies the referee and finance/admin views.

## Release safety

- Keep the integration test-mode-only until all acceptance requirements pass.
- Do not add a live Stripe key, create live connected accounts, initiate live transfers, deploy migrations or enable unattended transfer processing without explicit release approval.
- Never claim that a transfer to a connected Stripe balance means the money has already reached the referee's bank.

## Ambiguous transfer and webhook-ordering safeguards

- HTTP 408 is an ambiguous outcome: Stripe may have created the transfer even though the caller timed out. Keep the payout in `processing`, preserve the original attempt number and idempotency key, and reconcile before any new attempt.
- HTTP 409, 429, all 5xx responses, network failures, malformed responses and uncertain database confirmations are also non-definitive. Do not mark these payouts failed or issue a new idempotency key.
- Only definitive 4xx client rejections other than 408, 409 and 429 may be marked failed. A failed attempt is retryable only after its outcome is reconciled and the underlying cause is resolved.
- A `transfer.reversed` event that arrives before its matching `transfer.created` event is left unprocessed and returns a retryable webhook error. Stripe's retry can then reconcile it after the transfer is linked.
- A reversal for an older transfer attempt is retained in attempt history without changing a newer successful payout.
- The original `20261111192000_referee_connect_payouts.sql` migration remains immutable. These changes are delivered by the separate forward-only `20261113100800_referee_connect_transfer_reconciliation_corrections.sql` migration and matching canonical draft.
- CI tests the HTTP status classifier, approval-to-outbox transaction, unmatched reversal, stale reversal and clean migration replay. These are automated contract tests, not a Stripe API round trip.

The current approval RPC writes a £22 gross entitlement with zero deductions and £22 net, so its standard immediate transfer request is 2,200 pence. The wider documented payout policy permits deductions and a £20 minimum net amount; any future deduction feature must not silently change the agreed match-fee transfer amount without an explicit policy decision.

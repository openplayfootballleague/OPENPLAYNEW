# Referee Stripe Connect setup

## What is implemented

- Referees with an active approved membership can create or resume a Stripe Express onboarding link from the Referee workspace.
- The connected account is mapped to the referee's internal user ID; bank details remain with Stripe.
- Account status is synchronized from signed `account.updated` events and checked before a transfer.
- Finance administrators can transfer approved match-report fees and £50 milestone rewards.
- Each transfer uses an attempt-specific Stripe idempotency key.
- Match-report and milestone transfers are recorded only after Stripe confirms the transfer.
- Signed transfer-created and transfer-reversed events reconcile the database.
- Reversed transfers are retained in a private attempt history; stale reversal events cannot reverse a newer successful attempt.
- Failed transfers can be retried by finance administrators only when the referee's Connect account is eligible.
- Processing/ambiguous transfers are deliberately not retryable until reconciliation completes.

## Required Supabase Edge Function secrets

Configure these in the Open Play New Supabase project's Edge Function secrets:

- `STRIPE_SECRET_KEY`: Stripe **test-mode** secret key beginning `sk_test_`.
- `APP_ORIGIN`: exact deployed application origin, without a trailing slash (for example, `https://your-open-play-domain.example`).
- `REFEREE_CONNECT_WEBHOOK_SECRET`: signing secret for the dedicated Connect webhook endpoint.
- Standard Supabase Edge Function environment values: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`.

Do not place Stripe secret keys or webhook signing secrets in Vite variables, browser code, GitHub files or the public repository.

## Stripe Dashboard test-mode configuration

1. Enable Connect for the Open Play platform account and use Express connected accounts.
2. Create a test-mode webhook endpoint:
   `https://<project-ref>.supabase.co/functions/v1/referee-connect-webhook`
3. Subscribe to connected-account `account.updated` and platform `transfer.created` and `transfer.reversed` events.
4. Copy the endpoint signing secret to `REFEREE_CONNECT_WEBHOOK_SECRET`.
5. Ensure the platform has sufficient **test-mode** available balance before attempting a transfer.

The account onboarding flow uses GB individual Express accounts and requests the transfers capability. Referees must complete Stripe's verification and enable both transfers and bank payouts before they can be paid.

## Finance workflow

- Approve the referee's match report to create the match payout obligation.
- Confirm the referee's Connect status is enabled.
- In Admin → Referees, send the match payout or eligible milestone reward.
- Check the transfer reference and attempt history after confirmation.
- If Stripe definitively rejects a transfer, the payout becomes failed and can be retried after correcting the cause.
- If the transfer outcome is ambiguous or a transfer is processing, do not retry; wait for webhook reconciliation and inspect the attempt history.

## Acceptance and production gate

- CI tests the account-readiness gate, role restrictions, match payout, milestone payout, duplicate transfer confirmation, reversal/retry and out-of-order webhook safeguards without calling Stripe.
- Live-mode transfers are rejected by the Edge Functions.
- Do not add a live Stripe key or deploy live transfers until Connect onboarding, finance reconciliation and physical-device acceptance have been signed off.

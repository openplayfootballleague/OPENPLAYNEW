# Open Play referee Connect and immediate payment policy

## Agreed payout timing

Each referee report creates one £22 gross entitlement when an administrator approves that report. Open Play must initiate the corresponding Stripe Connect transfer immediately after approval, provided the referee has completed onboarding, the connected account is eligible to receive transfers, and sufficient platform funds are available.

“Immediately” means the platform creates the transfer to the referee's connected Stripe balance as part of the approval-triggered workflow. It does **not** promise an instant bank deposit. The connected account's subsequent bank payout is governed by Stripe's payout availability, schedule, bank processing and account requirements.

## Transfer amount and guarantee

- Gross allocation: £22.00 per approved referee report.
- Included deductions: up to £2.00.
- Referee minimum net entitlement: £20.00.
- Open Play top-up: max(0, actual deductions - £2.00).
- Transfer amount: £22.00 + Open Play top-up.
- The transfer must not be initiated until the final net amount is calculated and reconciled.
- The one-entitlement-per-report unique constraint and stable Stripe idempotency key prevent duplicate payment on retries.

## Stripe Connect direction for test implementation

The Stripe implementation planner was completed against the Open Play test account. The selected direction is a UK domestic marketplace-style recipient setup using Accounts v2, recipient transfer capability, Express dashboard access and embedded onboarding. The platform owns fees and losses for this selected marketplace configuration; that responsibility must be explicitly reviewed and accepted in Stripe Dashboard before connected accounts are created.

Use a separate platform charge and transfer flow: team fees are charged to Open Play; referee transfers are held until the match report is approved; then the transfer is initiated immediately. Do not use destination charges because the referee is not known/eligible at the point the team charge is taken and the transfer must be gated on report approval.

## Required server workflow

1. Admin approves a referee-submitted report.
2. The approval transaction creates exactly one payout entitlement for that report.
3. A server-side worker claims the entitlement with a lease/attempt token and verifies the referee's connected account and transfer capability.
4. If onboarding/capability is incomplete, retain a visible pending state and notify the referee to complete onboarding.
5. If eligible, create the Stripe transfer immediately, with a stable idempotency key derived from the payout entitlement ID and metadata linking the report and entitlement.
6. Verify the returned transfer ID and reconcile it through signed Stripe webhook events and a server-side retrieval check.
7. Mark the entitlement transferred only after authoritative provider confirmation. Never infer payment from a browser redirect or UI action.
8. If the platform balance is insufficient or Stripe rejects the transfer, retain a retryable failed/pending state and surface it to Finance/Admin. A retry must reuse the same entitlement and idempotency key; it must not create a second entitlement.
9. Show the referee the transfer state separately from the bank payout state. Do not describe a connected-balance transfer as a completed bank deposit.

## Safety and operational requirements

- Test mode only until explicit approval for production configuration and release.
- Never store or expose Stripe secret keys in the browser.
- Connected account IDs are server-managed and must not be accepted from client input as authoritative.
- Check the recipient transfer capability before each transfer attempt.
- Use an idempotency key per entitlement; enforce a unique Stripe transfer ID.
- Handle duplicate, delayed and out-of-order webhooks safely.
- Keep append-only audit records for approval, transfer attempts, failures, retries and reversals.
- Admin corrections to an approved report must not create another £22 entitlement or another transfer.
- Referee milestone rewards remain separate, require administrator confirmation, and follow the same immediate-transfer rule once approved.
- Payout cadence is immediate per approved report; do not batch referee transfers into a weekly run.

## Release gates still required

- Stripe confirms Open Play's test account is enabled for the selected Connect configuration and recipient transfers.
- The platform has reviewed and accepted platform-owned fee and loss responsibilities in Dashboard.
- Test onboarding, incomplete requirements, transfer capability pending/disabled, successful transfer, insufficient balance, retry, duplicate webhook, reversal and bank payout status.
- Legal/accounting review of contractor status, tax reporting, payment terms and negative-balance/liability responsibilities.
- No live accounts, live transfers or deployment until explicitly authorised.

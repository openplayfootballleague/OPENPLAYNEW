# Open Play New — team fixture-payment policy proposal

**Status:** Proposed operational policy — pending administrator review and approval  
**Implementation status:** Not implemented; no payment, fixture or finance behaviour is changed by this document  
**Scope:** Team-level fixture fees and the consequences of a team's missed payment deadline

This proposal records the payment rules discussed for Open Play. It is deliberately kept separate from the existing player-level Stripe checkout flow until the administrator review is complete and the team-payment model is agreed.

## 1. Payment deadline

- When a team fixture-payment request is issued, the system records its authoritative server timestamp and calculates a payment deadline exactly 24 hours later.
- The captain-facing matchday/payment view should display a live countdown to that deadline, including the exact deadline time, so the team can see how long remains.
- The server/database is authoritative. A client countdown is informational and must never decide whether a payment is on time.
- The payment request, deadline, payment timestamp and any subsequent state transition must be auditable.

## 2. Additional 12-hour grace period

- A team may still pay during the 12 hours immediately following the original 24-hour deadline.
- A payment received in this grace period is accepted, but the team receives one payment strike for that fixture.
- The strike must be recorded against the team with the fixture, payment request, original deadline and actual payment timestamp.
- Repeated webhook delivery, page refreshes or payment retries must not create duplicate strikes.

## 3. Missed final deadline

- If payment has not been received by the end of the additional 12-hour grace period (36 hours after the payment request), the fixture is cancelled under the proposed default rule.
- The team that missed payment remains liable for the match fee. Cancelling the fixture does not automatically waive that team's fee.
- If the opposing team has already paid, its payment is refunded.
- The cancellation, outstanding fee liability, opponent refund obligation and all refund outcomes must be separately recorded and visible to authorised finance/admin users.
- A refund must be treated as pending until the payment provider confirms its outcome; a failed or partial refund must remain visible for finance follow-up.

## 4. Administrator review and exceptional circumstances

- Exceptional circumstances must be referred to an administrator rather than handled through an informal captain-side override.
- The administrator should be able to review the fixture, payment timeline, team history, strike history and any evidence before deciding an exception.
- Any approved exception, deadline extension, cancellation reversal, fee adjustment or refund override must record the deciding administrator, timestamp, reason and before/after state.
- No automatic exception, deadline pause, strike removal, team removal or cancellation reversal is authorised by this proposal. The permitted decisions and their effect on the payment clock require administrator approval before implementation.
- Any proposed team removal/suspension consequence remains pending administrator clearance and is not part of the automatic 36-hour rule.

## 5. Required product behaviour after approval

1. Create a team-level fixture-payment record with immutable fee and deadline snapshots.
2. Show the captain the amount due, original 24-hour deadline, live countdown, grace-period state and any strike.
3. At 24 hours, transition the request into the grace period and clearly explain that a late payment incurs a strike.
4. At 36 hours, apply the approved cancellation workflow exactly once if no payment has been received and no administrator decision is holding the case.
5. Preserve the defaulting team's fee liability and create a separate refund obligation for an opponent who has already paid.
6. Reconcile Stripe events idempotently; never infer payment success from a browser redirect.
7. Provide administrators with an approval queue and a complete audit trail for exceptions, cancellations, liabilities and refunds.
8. Keep finance status distinct for payment due, paid, late-paid/strike, cancelled with fee due, refund pending, refunded, refund failed and administrator review.

## 6. Safety and accounting requirements

- Do not reuse the current per-player fixture-payment schema as if it already represents a team-level payment obligation. The existing Stripe checkout foundation is player-scoped and needs an explicit architecture decision before this policy is implemented.
- Never silently discard a fee liability when a fixture is cancelled.
- Do not report an opponent refund as complete until the provider confirms it.
- Protect payment actions with captain/finance/admin authorisation and server-side checks.
- Ensure retries, duplicate webhooks and concurrent administrator actions cannot create duplicate strikes, duplicate liabilities or duplicate refunds.
- Agree the finance/accounting retention treatment before implementing permanent payment records or erasure exceptions.

## 7. Approval checklist

| Decision | Status |
|---|---|
| 24-hour initial payment deadline | Discussed; awaiting administrator approval |
| Additional 12-hour grace period | Discussed; awaiting administrator approval |
| One strike for payment during grace period | Discussed; awaiting administrator approval |
| Cancellation after 36 hours unpaid | Discussed; awaiting administrator approval |
| Defaulting team's fee remains payable | Discussed; awaiting administrator approval |
| Refund paid opposing team | Discussed; awaiting administrator approval |
| Exceptional-case administrator review | Requested; workflow details require approval |
| Team removal/suspension consequence | Explicitly pending administrator clearance |
| Team-level Stripe and ledger architecture | Not yet designed or approved |

**Release rule:** This proposal is not production policy and must not be used to change payment collection, fixture status, strikes, team status or refunds until the administrator decisions and technical design are approved.

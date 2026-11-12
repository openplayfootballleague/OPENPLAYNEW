# Weather postponement acceptance checklist

Run this against a disposable local Supabase database and Stripe test mode only.

## Database and schedule

- [ ] A gameweek containing a completed, in-progress or separately cancelled fixture is excluded.
- [ ] A gameweek is unavailable to an administrator who cannot manage every affected fixture location.
- [ ] A valid whole-gameweek postponement moves all its fixtures to the replacement kickoff.
- [ ] Completed historical gameweeks keep their published week numbers.
- [ ] Unplayed gameweeks are renumbered in chronological kickoff order.
- [ ] Each fixture retains its stable `gameweek_id` while the display week number changes.
- [ ] Repeating the same postponement request is idempotent and does not create another payment cycle.

## Team payments and refunds

- [ ] Active Checkout sessions are expired and reconciled before the schedule changes.
- [ ] A completed paid Checkout is recorded before refund eligibility is evaluated.
- [ ] An unresolved Checkout or payment exception blocks automatic postponement.
- [ ] Paid team obligations create one refund obligation with the original PaymentIntent.
- [ ] Unpaid previous-cycle obligations receive one matching finance credit.
- [ ] Replacement cycles use the replacement kickoff with new 24-hour and 12-hour deadlines.
- [ ] A late payment from an old cycle is reconciled and refunded rather than charged as a new cycle.
- [ ] Refund status changes only after the signed Stripe test webhook or worker result is reconciled.

## Access, audit and notifications

- [ ] Only authenticated administrators with access to every affected location can apply the change.
- [ ] The reason, actor, original schedule, replacement schedule and finance outcomes are audited.
- [ ] Affected captains receive an in-app notification; provider channels respect saved preferences.
- [ ] The admin screen displays queued, completed and failed refund counts accurately.

Do not sign off until clean migration replay, SQL regression tests, build, browser/PWA acceptance and a complete test-mode Checkout → postponement → refund → signed-webhook round trip have passed. This checklist is not evidence that a live or hosted integration has been exercised.

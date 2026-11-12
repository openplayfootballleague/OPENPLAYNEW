# Weather postponement operations

## Scope

The Admin → Fixtures & Results workspace is for postponing an entire eligible gameweek after a weather or venue disruption. It is not a tool for cancelling individual completed fixtures or changing historical results.

The administrator must have permission for every fixture location in the gameweek. The database transaction rechecks location permissions and fixture eligibility when it applies the change.

## Workflow

1. Open Admin → Fixtures & Results and choose an eligible gameweek.
2. Enter the replacement kickoff and a reason of at least five characters.
3. Confirm the postponement.
4. The Edge Function validates the signed-in administrator and test-mode Stripe configuration. It reconciles active Checkout sessions before asking the database to apply the change.
5. The database preserves completed history, updates the affected fixtures and gameweek sequence, records an audit entry, queues refunds for paid team fees, and credits eligible unpaid charges.
6. The scheduled team-payment worker processes refund obligations. Refunds are not represented as complete until the provider result has been reconciled.

The replacement kickoff must be at least 36 hours in the future so the 24-hour payment deadline and 12-hour grace period can operate.

## Test-mode configuration

Before a controlled test environment can exercise the workflow, configure these server-side secrets there:

- `STRIPE_SECRET_KEY`: a Stripe test secret beginning `sk_test_`
- `APP_ORIGIN`: the exact allowed application origin
- `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY`
- `TEAM_PAYMENT_CRON_SECRET`: secret for the scheduled deadline/refund worker
- `TEAM_STRIPE_WEBHOOK_SECRET`: signing secret for the team Stripe webhook

The worker must be scheduled with the `x-team-payment-cron-secret` header. Stripe test webhooks must point to the `team-stripe-webhook` function.

## Release boundary

This repository change does not deploy functions, apply hosted migrations, configure hosted secrets, schedule production jobs, or initiate live refunds. Keep Stripe in test mode until clean migration replay, SQL regressions, browser acceptance, a real test-mode checkout/refund/webhook round trip, and human release review have all passed.

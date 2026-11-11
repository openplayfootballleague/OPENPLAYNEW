-- Prevent concurrent deliveries of the same unprocessed Stripe event from
-- applying the same state transition at the same time. Failed deliveries release
-- the lease; abandoned workers can be reclaimed after five minutes.
alter table public.stripe_webhook_events
  add column if not exists processing_started_at timestamptz;

create index if not exists stripe_webhook_events_unprocessed_lease_idx
  on public.stripe_webhook_events(processing_started_at)
  where processed_at is null;

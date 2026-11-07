-- Ensure Edge Functions using the service role can access the private payment tables.
revoke all on public.payment_records from anon, authenticated;
grant select on public.payment_records to authenticated;
grant select, insert, update, delete on public.payment_records to service_role;

revoke all on public.stripe_webhook_events from anon, authenticated;
grant select, insert, update, delete on public.stripe_webhook_events to service_role;

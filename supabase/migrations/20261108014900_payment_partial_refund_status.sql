-- Add the enum label in its own migration so PostgreSQL commits it before
-- later migrations define functions that reference the new value.
alter type public.payment_status add value if not exists 'partially_refunded';

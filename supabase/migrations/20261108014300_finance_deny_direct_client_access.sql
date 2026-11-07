-- Explicit deny-all RLS policy keeps the finance ledger private to guarded SECURITY DEFINER RPCs.
create policy finance_entries_no_direct_client_access
on public.finance_entries
for all
to anon, authenticated
using (false)
with check (false);
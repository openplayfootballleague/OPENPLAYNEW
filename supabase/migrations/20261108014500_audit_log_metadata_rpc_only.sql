drop policy if exists audit_log_admin_read on public.audit_log;
revoke select on public.audit_log from anon,authenticated;

create policy audit_log_no_direct_client_access
on public.audit_log
for all
to anon, authenticated
using (false)
with check (false);

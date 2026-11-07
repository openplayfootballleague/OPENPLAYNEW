create policy audit_log_no_direct_client_access on public.audit_log for all to anon, authenticated using (false) with check (false);

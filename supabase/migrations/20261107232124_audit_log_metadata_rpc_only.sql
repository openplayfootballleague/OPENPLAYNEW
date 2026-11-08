drop policy if exists audit_log_admin_read on public.audit_log;
revoke select on public.audit_log from anon,authenticated;
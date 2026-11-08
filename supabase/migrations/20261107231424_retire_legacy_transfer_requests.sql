-- Retire the initial permissive transfer table. The audited
-- player_transfer_requests RPC workflow is the sole supported path.
drop policy if exists transfer_requests_insert_self on public.transfer_requests;
drop policy if exists transfer_requests_admin_manage on public.transfer_requests;
revoke insert,update,delete on public.transfer_requests from public,anon,authenticated;
revoke all on public.transfer_requests from public,anon;
grant select on public.transfer_requests to authenticated;
comment on table public.transfer_requests is
  'Legacy unused transfer table. New requests must use player_transfer_requests and its validated RPC workflow. Direct writes are revoked.';

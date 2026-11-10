-- Retire legacy unscoped admin read RPCs. Current admin routes use the
-- contextual equivalents, which validate the selected assigned location.
revoke all on function public.admin_get_transfer_requests(text) from public,anon,authenticated;
revoke all on function public.get_admin_dashboard() from public,anon,authenticated;
revoke all on function public.get_admin_player_register(text,text,integer,integer) from public,anon,authenticated;
revoke all on function public.get_admin_team_sheets() from public,anon,authenticated;

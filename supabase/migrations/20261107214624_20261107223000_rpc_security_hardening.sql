-- Security hardening for exposed RPCs.
-- The auth trigger function is invoked by the trigger, never by API clients.
revoke all on function public.handle_new_auth_user() from public, anon, authenticated;

-- Internal authorization helpers are safe, narrowly scoped boolean checks.
-- Keep execute grants aligned with the RLS policies that call them.
revoke all on function public.has_finance_access() from public, anon;
grant execute on function public.has_finance_access() to authenticated;

-- Registration and membership RPCs are explicitly authenticated-only.
revoke all on function public.register_player(text, text, text, date) from public, anon;
grant execute on function public.register_player(text, text, text, date) to authenticated;

revoke all on function public.resolve_player_registration_review(uuid, text, text) from public, anon;
grant execute on function public.resolve_player_registration_review(uuid, text, text) to authenticated;

revoke all on function public.request_team_membership(uuid) from public, anon;
grant execute on function public.request_team_membership(uuid) to authenticated;

revoke all on function public.resolve_team_membership_request(uuid, text) from public, anon;
grant execute on function public.resolve_team_membership_request(uuid, text) to authenticated;

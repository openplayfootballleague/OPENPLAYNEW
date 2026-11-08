-- These legacy admin RPCs return unscoped cross-location data.
-- The current application uses the corresponding *_contextual RPCs instead.
-- Revoke client execution so location-scoped league_admin users cannot bypass
-- location context through SECURITY DEFINER endpoints.

revoke all on function public.get_admin_dashboard() from public, anon, authenticated;
revoke all on function public.get_admin_player_register(text, text, integer, integer) from public, anon, authenticated;
revoke all on function public.get_admin_team_sheets() from public, anon, authenticated;
revoke all on function public.admin_get_transfer_requests(text) from public, anon, authenticated;

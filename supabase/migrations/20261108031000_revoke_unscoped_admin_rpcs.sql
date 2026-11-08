-- These legacy admin RPCs return unscoped cross-location data.
-- The current application uses the corresponding *_contextual RPCs instead.
-- Revoke client execution so location-scoped league_admin users cannot bypass
-- location context through SECURITY DEFINER endpoints.

revoke all on function public.get_admin_dashboard() from public, anon, authenticated;
revoke all on function public.get_admin_player_register(text, text, integer, integer) from public, anon, authenticated;
revoke all on function public.get_admin_team_sheets() from public, anon, authenticated;
revoke all on function public.admin_get_transfer_requests(text) from public, anon, authenticated;

-- The table-returning function's OUT parameter is also named user_id.
-- Qualify the user_roles column so PL/pgSQL does not resolve it ambiguously.
create or replace function public.admin_list_location_assignments(p_location_id uuid default null)
returns table(
  assignment_id uuid,
  user_id uuid,
  location_id uuid,
  location_name text,
  assigned_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('admin', 'super_admin')
  ) then
    raise exception 'Global administrator permission required';
  end if;

  return query
  select a.id, a.user_id, a.location_id, l.name, a.created_at
  from public.location_admin_assignments a
  join public.locations l on l.id = a.location_id
  where p_location_id is null or a.location_id = p_location_id
  order by l.name, a.created_at desc;
end;
$$;

revoke all on function public.admin_list_location_assignments(uuid) from public, anon;
grant execute on function public.admin_list_location_assignments(uuid) to authenticated;

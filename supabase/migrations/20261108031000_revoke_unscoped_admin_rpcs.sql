-- These legacy admin RPCs return unscoped cross-location data.
-- The current application uses the corresponding *_contextual RPCs instead.
-- Revoke client execution so location-scoped league_admin users cannot bypass
-- location context through SECURITY DEFINER endpoints.

revoke all on function public.get_admin_dashboard() from public, anon, authenticated;
revoke all on function public.get_admin_player_register(text, text, integer, integer) from public, anon, authenticated;
revoke all on function public.get_admin_team_sheets() from public, anon, authenticated;
revoke all on function public.admin_get_transfer_requests(text) from public, anon, authenticated;

-- These table-returning/admin functions have output or parameter names that
-- overlap with user_roles columns. Qualify every role-table reference so
-- PL/pgSQL resolves the intended columns and the global-admin guard runs.

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
      and ur.role in ('admin','super_admin')
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

create or replace function public.admin_set_location_assignment(
  p_user_id uuid,
  p_location_id uuid,
  p_assigned boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('admin','super_admin')
  ) then
    raise exception 'Global administrator permission required';
  end if;

  if not exists (
    select 1
    from public.user_roles ur
    where ur.user_id = p_user_id
      and ur.role = 'league_admin'
  ) then
    raise exception 'The selected user must have the league_admin role';
  end if;

  if not exists (
    select 1 from public.locations l where l.id = p_location_id
  ) then
    raise exception 'Location not found';
  end if;

  if p_assigned then
    insert into public.location_admin_assignments(user_id,location_id,assigned_by)
    values (p_user_id,p_location_id,auth.uid())
    on conflict(user_id,location_id) do nothing;
  else
    delete from public.location_admin_assignments
    where user_id = p_user_id and location_id = p_location_id;
  end if;
end;
$$;

revoke all on function public.admin_list_location_assignments(uuid) from public, anon;
revoke all on function public.admin_set_location_assignment(uuid,uuid,boolean) from public, anon;
grant execute on function public.admin_list_location_assignments(uuid) to authenticated;
grant execute on function public.admin_set_location_assignment(uuid,uuid,boolean) to authenticated;

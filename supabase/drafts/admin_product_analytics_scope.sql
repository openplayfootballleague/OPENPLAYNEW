-- Return only the competition identifiers an administrator is permitted to report on.
-- Deliberately excludes all player, team, fixture and profile fields.
create or replace function public.get_admin_product_analytics_scope()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;

  if exists (
    select 1 from public.user_roles
    where user_id = v_actor and role = 'league_admin'
  ) and not exists (
    select 1 from public.location_admin_assignments
    where user_id = v_actor
  ) then
    raise exception 'No locations have been assigned to this administrator';
  end if;

  return jsonb_build_object(
    'locations', coalesce((
      select jsonb_agg(l.id order by l.name)
      from public.locations l
      where public.can_administer_location(l.id)
    ), '[]'::jsonb),
    'leagues', coalesce((
      select jsonb_agg(jsonb_build_object('id', l.id, 'location_id', l.location_id) order by l.name)
      from public.leagues l
      where public.can_administer_location(l.location_id)
    ), '[]'::jsonb),
    'seasons', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'league_id', s.league_id) order by s.created_at desc)
      from public.seasons s
      join public.leagues l on l.id = s.league_id
      where public.can_administer_location(l.location_id)
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_admin_product_analytics_scope() from public, anon;
grant execute on function public.get_admin_product_analytics_scope() to authenticated;

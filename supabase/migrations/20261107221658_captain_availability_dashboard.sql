-- Captain availability view: only active captains can see responses from their own squad.
-- Missing responses are returned explicitly so captains can follow up before matchday.
create or replace function public.get_captain_availability()
returns table(
  fixture_id uuid,
  season_team_id uuid,
  team_name text,
  gameweek integer,
  scheduled_at timestamptz,
  player_name text,
  is_available boolean,
  response_note text,
  responded_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if not exists(
    select 1 from public.team_memberships tm
    where tm.user_id=v_user_id and tm.is_captain=true and tm.status='active'
  ) then raise exception 'Active captain permission required'; end if;
  return query
  select f.id,st.id,st.name,f.gameweek,f.scheduled_at,p.full_name,fa.is_available,fa.response_note,fa.responded_at
  from public.team_memberships captain
  join public.season_teams st on st.id=captain.season_team_id
  join public.fixtures f on f.home_team_id=st.id or f.away_team_id=st.id
  join public.team_memberships squad on squad.season_team_id=st.id and squad.status='active'
  join public.players p on p.user_id=squad.user_id and p.registration_status='registered' and p.is_banned=false
  left join public.fixture_availability fa on fa.fixture_id=f.id and fa.user_id=squad.user_id
  where captain.user_id=v_user_id and captain.is_captain=true and captain.status='active'
    and f.status='scheduled'
  order by f.scheduled_at nulls last,f.gameweek,st.name,p.full_name;
end;
$$;
revoke all on function public.get_captain_availability() from public,anon;
grant execute on function public.get_captain_availability() to authenticated;

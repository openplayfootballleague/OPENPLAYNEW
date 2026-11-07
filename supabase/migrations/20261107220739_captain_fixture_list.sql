create or replace function public.get_captain_fixtures()
returns table(
  fixture_id uuid,
  season_team_id uuid,
  team_name text,
  opponent_name text,
  gameweek integer,
  scheduled_at timestamptz,
  competition_format text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_user_id uuid:=auth.uid();
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.team_memberships tm where tm.user_id=v_user_id and tm.is_captain=true and tm.status='active') then
    raise exception 'Active captain permission required';
  end if;
  return query
  select f.id,own.id,own.name,opp.name,f.gameweek,f.scheduled_at,l.format::text
  from public.team_memberships captain
  join public.season_teams own on own.id=captain.season_team_id
  join public.fixtures f on f.home_team_id=own.id or f.away_team_id=own.id
  join public.season_teams opp on opp.id=case when f.home_team_id=own.id then f.away_team_id else f.home_team_id end
  join public.seasons s on s.id=f.season_id
  join public.leagues l on l.id=s.league_id
  where captain.user_id=v_user_id and captain.is_captain=true and captain.status='active'
    and f.status='scheduled'
  order by f.scheduled_at nulls last,f.gameweek;
end;
$$;
revoke all on function public.get_captain_fixtures() from public,anon;
grant execute on function public.get_captain_fixtures() to authenticated;

create or replace function public.get_admin_team_sheets_contextual(
  p_location_id uuid default null,p_league_id uuid default null,p_season_id uuid default null
) returns table(team_sheet_id uuid,fixture_id uuid,season_team_id uuid,team_name text,opponent_name text,gameweek integer,scheduled_at timestamptz,competition_format public.competition_format,is_locked boolean,submitted_at timestamptz,players jsonb,roster jsonb)
language plpgsql stable security definer set search_path=''
as $$
declare v_location uuid:=p_location_id;v_league uuid:=p_league_id;v_season uuid:=p_season_id;v_league_location uuid;v_season_league uuid;
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if v_season is not null then
    select s.league_id into v_season_league from public.seasons s where s.id=v_season;
    if v_season_league is null then raise exception 'Selected season was not found'; end if;
    if v_league is not null and v_league<>v_season_league then raise exception 'Season does not belong to selected league'; end if;
    v_league:=v_season_league;
  end if;
  if v_league is not null then
    select l.location_id into v_league_location from public.leagues l where l.id=v_league;
    if v_league_location is null then raise exception 'Selected league was not found'; end if;
    if v_location is not null and v_location<>v_league_location then raise exception 'League does not belong to selected location'; end if;
    v_location:=v_league_location;
  end if;
  if v_location is not null and not exists(select 1 from public.locations where id=v_location) then raise exception 'Selected location was not found'; end if;
  return query
  select sh.id,sh.fixture_id,sh.season_team_id,st.name,opponent.name,f.gameweek,f.scheduled_at,l.format,sh.is_locked,sh.submitted_at,
    coalesce((select jsonb_agg(jsonb_build_object('membership_id',tm.id,'player_name',p.full_name,'role',tsp.role,'is_goalkeeper',tsp.is_goalkeeper,'squad_number_snapshot',tsp.squad_number_snapshot) order by case when tsp.role='starter' then 0 else 1 end,p.full_name) from public.fixture_team_sheet_players tsp join public.team_memberships tm on tm.user_id=tsp.user_id and tm.season_team_id=sh.season_team_id and tm.status='active' join public.players p on p.user_id=tsp.user_id where tsp.team_sheet_id=sh.id),'[]'::jsonb),
    coalesce((select jsonb_agg(jsonb_build_object('membership_id',tm.id,'player_name',p.full_name,'squad_number',tm.squad_number) order by p.full_name) from public.team_memberships tm join public.players p on p.user_id=tm.user_id where tm.season_team_id=sh.season_team_id and tm.status='active' and p.registration_status='registered' and p.is_banned=false),'[]'::jsonb)
  from public.fixture_team_sheets sh join public.fixtures f on f.id=sh.fixture_id join public.seasons se on se.id=f.season_id join public.leagues l on l.id=se.league_id join public.season_teams st on st.id=sh.season_team_id join public.season_teams opponent on opponent.id=case when f.home_team_id=sh.season_team_id then f.away_team_id else f.home_team_id end
  where (v_location is null or l.location_id=v_location) and (v_league is null or l.id=v_league) and (v_season is null or se.id=v_season)
  order by f.scheduled_at desc nulls last,f.gameweek desc,st.name;
end;
$$;
revoke all on function public.get_admin_team_sheets_contextual(uuid,uuid,uuid) from public,anon;
grant execute on function public.get_admin_team_sheets_contextual(uuid,uuid,uuid) to authenticated;

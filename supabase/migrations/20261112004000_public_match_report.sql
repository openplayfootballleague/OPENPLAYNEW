-- Public, privacy-filtered match report projection for player fixtures and Match Centre.
create or replace function public.get_public_match_report(p_fixture_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_fixture public.fixtures;
  v_season public.seasons;
  v_league public.leagues;
  v_home public.season_teams;
  v_away public.season_teams;
  v_location public.locations;
  v_result public.fixture_results;
  v_report_available boolean:=false;
  v_goals jsonb:='[]'::jsonb;
  v_lineups jsonb:='[]'::jsonb;
begin
  select * into v_fixture
  from public.fixtures
  where id=p_fixture_id;
  if not found then return null; end if;

  select * into v_season
  from public.seasons
  where id=v_fixture.season_id and is_public=true;
  if not found then return null; end if;

  select * into v_league
  from public.leagues
  where id=v_season.league_id and is_published=true;
  if not found then return null; end if;

  select * into v_home from public.season_teams where id=v_fixture.home_team_id;
  select * into v_away from public.season_teams where id=v_fixture.away_team_id;
  select * into v_location from public.locations where id=v_fixture.venue_id;

  select * into v_result
  from public.fixture_results
  where fixture_id=p_fixture_id and confirmed_at is not null;

  v_report_available:=found and v_fixture.status::text='completed';

  if v_report_available then
    select coalesce(jsonb_agg(jsonb_build_object(
      'season_team_id',g.season_team_id,
      'team_name',st.name,
      'competition_player_id',g.competition_player_id,
      'scorer_name',coalesce(cpi.display_name,'Unknown player'),
      'recorded_at',g.created_at
    ) order by g.created_at),'[]'::jsonb)
    into v_goals
    from public.fixture_goal_records g
    join public.season_teams st on st.id=g.season_team_id
    left join public.competition_player_identities cpi on cpi.id=g.competition_player_id
    where g.fixture_id=p_fixture_id and g.voided_at is null;

    select coalesce(jsonb_agg(jsonb_build_object(
      'season_team_id',st.id,
      'team_name',st.name,
      'players',coalesce((
        select jsonb_agg(jsonb_build_object(
          'competition_player_id',tsp.competition_player_id,
          'name',coalesce(cpi.display_name,'Player'),
          'role',tsp.role::text,
          'is_goalkeeper',tsp.is_goalkeeper,
          'squad_number',tsp.squad_number_snapshot,
          'did_appear',tsp.did_appear
        ) order by case when tsp.role::text='starter' then 0 else 1 end,
          tsp.squad_number_snapshot nulls last,cpi.display_name)
        from public.fixture_team_sheet_players tsp
        left join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
        where tsp.team_sheet_id=ts.id
      ),'[]'::jsonb)
    ) order by st.name),'[]'::jsonb)
    into v_lineups
    from public.fixture_team_sheets ts
    join public.season_teams st on st.id=ts.season_team_id
    where ts.fixture_id=p_fixture_id and ts.submitted_at is not null and ts.is_locked=true;
  end if;

  return jsonb_build_object(
    'fixture',jsonb_build_object(
      'id',v_fixture.id,
      'gameweek',v_fixture.gameweek,
      'scheduled_at',v_fixture.scheduled_at,
      'status',v_fixture.status::text
    ),
    'home_team',jsonb_build_object(
      'id',v_home.id,'name',v_home.name,'badge_path',v_home.badge_path,'instagram_url',v_home.instagram_url
    ),
    'away_team',jsonb_build_object(
      'id',v_away.id,'name',v_away.name,'badge_path',v_away.badge_path,'instagram_url',v_away.instagram_url
    ),
    'season_name',v_season.name,
    'competition_name',v_league.name,
    'venue',case when v_location.id is null then null else jsonb_build_object(
      'name',v_location.name,'address',v_location.address,'town',v_location.town,'region',v_location.region
    ) end,
    'result',case when v_report_available then jsonb_build_object(
      'home_score',v_result.home_score,'away_score',v_result.away_score,'confirmed_at',v_result.confirmed_at
    ) else null end,
    'report_available',v_report_available,
    'goals',v_goals,
    'lineups',v_lineups,
    'motm',null,
    'events','[]'::jsonb,
    'assists_available',false,
    'match_events_available',false,
    'motm_available',false
  );
end;
$$;

revoke all on function public.get_public_match_report(uuid) from public;
grant execute on function public.get_public_match_report(uuid) to anon,authenticated;

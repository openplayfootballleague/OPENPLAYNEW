-- Keep season-wide player rankings attached to the permanent competition identity,
-- while exposing the same performances split by the team that earned them.
create or replace function public.get_admin_season_player_club_statistics(p_season_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_season public.seasons;
begin
  if not public.can_administer_location((
    select l.location_id
    from public.seasons s
    join public.leagues l on l.id = s.league_id
    where s.id = p_season_id
  )) then
    raise exception 'You are not assigned to this location';
  end if;
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;

  select * into v_season
  from public.seasons
  where id = p_season_id;
  if not found then raise exception 'Season not found'; end if;

  return (
    with published_results as (
      select f.id, f.season_id, f.home_team_id, f.away_team_id,
        r.home_score, r.away_score
      from public.fixtures f
      join public.fixture_results r
        on r.fixture_id = f.id and r.confirmed_at is not null
      where f.season_id = p_season_id
        and f.status = 'completed'
    ),
    player_apps_by_club as (
      select
        cpi.id as competition_player_id,
        cpi.display_name as full_name,
        ts.season_team_id as team_id,
        st.name as team_name,
        count(distinct f.id)::integer as apps,
        count(distinct f.id) filter (where tsp.role = 'starter')::integer as starts,
        count(distinct f.id) filter (where tsp.role = 'substitute')::integer as subs,
        count(distinct f.id) filter (where tsp.is_goalkeeper)::integer as goalkeeper_apps,
        count(distinct f.id) filter (
          where tsp.is_goalkeeper and (
            (ts.season_team_id = f.home_team_id and pr.away_score = 0)
            or (ts.season_team_id = f.away_team_id and pr.home_score = 0)
          )
        )::integer as goalkeeper_clean_sheets
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities cpi
        on cpi.id = tsp.competition_player_id
       and cpi.counts_for_statistics is true
      join public.fixture_team_sheets ts
        on ts.id = tsp.team_sheet_id and ts.is_locked is true
      join public.fixtures f
        on f.id = ts.fixture_id and f.status = 'completed'
      join published_results pr on pr.id = f.id
      join public.season_teams st on st.id = ts.season_team_id
      where f.season_id = p_season_id and tsp.did_appear is true
      group by cpi.id, cpi.display_name, ts.season_team_id, st.name
    ),
    player_goals_by_club as (
      select
        g.competition_player_id,
        cpi.display_name as full_name,
        g.season_team_id as team_id,
        st.name as team_name,
        count(*)::integer as goals
      from public.fixture_goal_records g
      join public.competition_player_identities cpi
        on cpi.id = g.competition_player_id
       and cpi.counts_for_statistics is true
      join published_results pr on pr.id = g.fixture_id
      join public.season_teams st on st.id = g.season_team_id
      where g.voided_at is null
      group by g.competition_player_id, cpi.display_name, g.season_team_id, st.name
    ),
    club_totals as (
      select
        coalesce(a.competition_player_id, g.competition_player_id) as competition_player_id,
        coalesce(a.full_name, g.full_name) as full_name,
        coalesce(a.team_id, g.team_id) as team_id,
        coalesce(a.team_name, g.team_name) as team_name,
        coalesce(a.apps, 0)::integer as apps,
        coalesce(a.starts, 0)::integer as starts,
        coalesce(a.subs, 0)::integer as subs,
        coalesce(g.goals, 0)::integer as goals,
        coalesce(a.goalkeeper_apps, 0)::integer as goalkeeper_apps,
        coalesce(a.goalkeeper_clean_sheets, 0)::integer as goalkeeper_clean_sheets
      from player_apps_by_club a
      full join player_goals_by_club g
        on g.competition_player_id = a.competition_player_id
       and g.team_id = a.team_id
    )
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'competition_player_id', competition_player_id,
        'full_name', full_name,
        'team_id', team_id,
        'team_name', team_name,
        'apps', apps,
        'starts', starts,
        'subs', subs,
        'apps_display', starts || '(' || subs || ')',
        'goals', goals,
        'goalkeeper_apps', goalkeeper_apps,
        'goalkeeper_clean_sheets', goalkeeper_clean_sheets
      )
      order by full_name, team_name
    ), '[]'::jsonb)
    from club_totals
  );
end;
$function$;

revoke all on function public.get_admin_season_player_club_statistics(uuid) from public, anon;
grant execute on function public.get_admin_season_player_club_statistics(uuid) to authenticated;

comment on function public.get_admin_season_player_club_statistics(uuid) is
  'Returns verified season player statistics split by the team represented. Season leaderboard totals remain aggregated by permanent competition identity across all clubs.';

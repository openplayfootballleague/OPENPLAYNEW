-- Expose verified player-owned season and career statistics without
-- exposing another player's records or relying on current club membership.
create or replace function public.get_my_player_statistics(p_season_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_player public.players;
  v_account_status text;
  v_season public.seasons;
  v_identity public.competition_player_identities;
  v_season_stats jsonb;
  v_career_stats jsonb;
begin
  if v_actor is null then
    raise exception 'Sign in to view player statistics';
  end if;

  -- Fetch the composite player row and scalar profile status separately.
  -- PostgreSQL does not allow a row variable in a multi-target INTO list.
  select pl.* into v_player
  from public.players pl
  where pl.user_id = v_actor;

  if not found then
    raise exception 'An active registered player account is required';
  end if;

  select pr.account_retention_status into v_account_status
  from public.profiles pr
  where pr.id = v_actor;

  if not found
     or v_player.registration_status <> 'registered'
     or v_player.is_banned
     or v_account_status <> 'active' then
    raise exception 'An active registered player account is required';
  end if;

  select * into v_identity
  from public.competition_player_identities
  where id = v_player.competition_player_id;

  if not found or not v_identity.counts_for_statistics or v_identity.anonymised_at is not null then
    raise exception 'Player statistics are not currently enabled for this account';
  end if;

  select s.* into v_season
  from public.seasons s
  join public.leagues l on l.id = s.league_id
  where s.id = p_season_id
    and s.is_public is true
    and l.is_published is true;

  if not found then
    raise exception 'The selected public season is not available';
  end if;

  with published_results as (
    select f.id, f.season_id, f.home_team_id, f.away_team_id,
      r.home_score, r.away_score
    from public.fixtures f
    join public.fixture_results r
      on r.fixture_id = f.id and r.confirmed_at is not null
    where f.status = 'completed'
  ),
  appearances as (
    select
      f.id as fixture_id,
      f.season_id,
      ts.season_team_id,
      tsp.role,
      tsp.is_goalkeeper,
      case
        when tsp.is_goalkeeper
         and ((ts.season_team_id = f.home_team_id and pr.away_score = 0)
           or (ts.season_team_id = f.away_team_id and pr.home_score = 0))
        then true else false
      end as goalkeeper_clean_sheet
    from public.fixture_team_sheet_players tsp
    join public.fixture_team_sheets ts
      on ts.id = tsp.team_sheet_id and ts.is_locked is true
    join published_results pr
      on pr.id = ts.fixture_id
    join public.fixtures f
      on f.id = pr.id
    where tsp.competition_player_id = v_identity.id
      and tsp.did_appear is true
  ),
  appearance_totals as (
    select
      season_id,
      count(distinct fixture_id)::integer as appearances,
      count(distinct fixture_id) filter (where role = 'starter')::integer as starts,
      count(distinct fixture_id) filter (where role = 'substitute')::integer as substitute_appearances,
      count(distinct fixture_id) filter (where is_goalkeeper)::integer as goalkeeper_appearances,
      count(distinct fixture_id) filter (where goalkeeper_clean_sheet)::integer as goalkeeper_clean_sheets
    from appearances
    group by season_id
  ),
  goal_totals as (
    select f.season_id, count(*)::integer as goals
    from public.fixture_goal_records g
    join published_results pr on pr.id = g.fixture_id
    join public.fixtures f on f.id = pr.id
    where g.competition_player_id = v_identity.id
      and g.voided_at is null
    group by f.season_id
  )
  select
    jsonb_build_object(
      'appearances', coalesce(a.appearances, 0),
      'starts', coalesce(a.starts, 0),
      'substitute_appearances', coalesce(a.substitute_appearances, 0),
      'goals', coalesce(g.goals, 0),
      'goals_per_game', coalesce(round(coalesce(g.goals, 0)::numeric / nullif(a.appearances, 0), 2), 0),
      'goalkeeper_appearances', coalesce(a.goalkeeper_appearances, 0),
      'goalkeeper_clean_sheets', coalesce(a.goalkeeper_clean_sheets, 0)
    )
  into v_season_stats
  from (select 1) seed
  left join appearance_totals a on a.season_id = p_season_id
  left join goal_totals g on g.season_id = p_season_id;

  with published_results as (
    select f.id, f.season_id, f.home_team_id, f.away_team_id,
      r.home_score, r.away_score
    from public.fixtures f
    join public.fixture_results r
      on r.fixture_id = f.id and r.confirmed_at is not null
    where f.status = 'completed'
  ),
  appearances as (
    select
      f.id as fixture_id,
      tsp.role,
      tsp.is_goalkeeper,
      case
        when tsp.is_goalkeeper
         and ((ts.season_team_id = f.home_team_id and pr.away_score = 0)
           or (ts.season_team_id = f.away_team_id and pr.home_score = 0))
        then true else false
      end as goalkeeper_clean_sheet
    from public.fixture_team_sheet_players tsp
    join public.fixture_team_sheets ts
      on ts.id = tsp.team_sheet_id and ts.is_locked is true
    join published_results pr
      on pr.id = ts.fixture_id
    join public.fixtures f
      on f.id = pr.id
    where tsp.competition_player_id = v_identity.id
      and tsp.did_appear is true
  ),
  appearance_totals as (
    select
      count(distinct fixture_id)::integer as appearances,
      count(distinct fixture_id) filter (where role = 'starter')::integer as starts,
      count(distinct fixture_id) filter (where role = 'substitute')::integer as substitute_appearances,
      count(distinct fixture_id) filter (where is_goalkeeper)::integer as goalkeeper_appearances,
      count(distinct fixture_id) filter (where goalkeeper_clean_sheet)::integer as goalkeeper_clean_sheets
    from appearances
  ),
  goal_totals as (
    select count(*)::integer as goals
    from public.fixture_goal_records g
    join published_results pr on pr.id = g.fixture_id
    where g.competition_player_id = v_identity.id
      and g.voided_at is null
  )
  select jsonb_build_object(
    'appearances', coalesce(a.appearances, 0),
    'starts', coalesce(a.starts, 0),
    'substitute_appearances', coalesce(a.substitute_appearances, 0),
    'goals', coalesce(g.goals, 0),
    'goals_per_game', coalesce(round(coalesce(g.goals, 0)::numeric / nullif(a.appearances, 0), 2), 0),
    'goalkeeper_appearances', coalesce(a.goalkeeper_appearances, 0),
    'goalkeeper_clean_sheets', coalesce(a.goalkeeper_clean_sheets, 0)
  )
  into v_career_stats
  from appearance_totals a
  cross join goal_totals g;

  return jsonb_build_object(
    'season', jsonb_build_object(
      'id', v_season.id,
      'name', v_season.name,
      'stats', v_season_stats
    ),
    'career', v_career_stats
  );
end;
$function$;

revoke all on function public.get_my_player_statistics(uuid) from public, anon;
grant execute on function public.get_my_player_statistics(uuid) to authenticated;

comment on function public.get_my_player_statistics(uuid) is
  'Returns only the authenticated registered player own verified statistics for a public selected season and career, using locked appearances and confirmed results.';

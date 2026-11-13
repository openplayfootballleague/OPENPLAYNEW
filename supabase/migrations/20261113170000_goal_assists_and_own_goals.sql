-- Blueprint 7.5, 11.2, 12.2: assists, own goals and goal contributions.
-- Forward-only and non-destructive. Existing goal records keep their meaning
-- (is_own_goal=false, no assist). Statistics functions are recreated from their
-- deployed definitions with only these additions:
--   * own goals never count towards the scorer's goals (club or career),
--   * assists and goal_contributions (= goals + assists) are reported,
--   * Player Hub statistics include appearances_display in starts(substitutes) form.

-- 1. Goal record attributes ------------------------------------------------------------
alter table public.fixture_goal_records
  add column if not exists is_own_goal boolean not null default false,
  add column if not exists assist_competition_player_id uuid
    references public.competition_player_identities(id) on delete restrict;
alter table public.fixture_goal_records
  add constraint fixture_goal_records_no_assist_on_own_goal
    check (not (is_own_goal and assist_competition_player_id is not null)),
  add constraint fixture_goal_records_assist_not_scorer
    check (assist_competition_player_id is null or assist_competition_player_id <> competition_player_id);
create index if not exists fixture_goal_records_assist_active_idx
  on public.fixture_goal_records(assist_competition_player_id)
  where voided_at is null and assist_competition_player_id is not null;
comment on column public.fixture_goal_records.season_team_id is
  'Team credited with the goal. For an own goal this is the opponent of the scorer''s team.';
comment on column public.fixture_goal_records.is_own_goal is
  'Scored by a player of the opposing team; never counts towards that player''s goals.';

-- 2. Record goal events for a published result ----------------------------------------
-- p_events: [{"team_side":"home"|"away","scorer_competition_player_id":uuid,
--             "is_own_goal":bool,"assist_competition_player_id":uuid|null}]
-- team_side is the team credited with the goal. Replaces the fixture's active goal
-- records (prior records are voided with the reason, never deleted).
create or replace function public.admin_record_fixture_goal_events(
  p_fixture_id uuid,
  p_events jsonb,
  p_reason text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_fixture public.fixtures;
  v_result public.fixture_results;
  v_home_sheet uuid;
  v_away_sheet uuid;
  v_before jsonb;
  v_problem text;
  v_count integer;
begin
  if not public.can_administer_location((
    select l.location_id from public.fixtures f
    join public.seasons s on s.id = f.season_id join public.leagues l on l.id = s.league_id
    where f.id = p_fixture_id
  )) then raise exception 'You are not assigned to this location'; end if;
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_events is null or jsonb_typeof(p_events) <> 'array' then raise exception 'Goal events must be an array'; end if;
  if p_reason is null or length(btrim(p_reason)) < 5 then raise exception 'Enter a reason of at least 5 characters'; end if;

  select * into v_fixture from public.fixtures where id = p_fixture_id for update;
  if not found then raise exception 'Fixture not found'; end if;
  select * into v_result from public.fixture_results where fixture_id = p_fixture_id and confirmed_at is not null;
  if not found or v_fixture.status <> 'completed' then
    raise exception 'Goal events can only be recorded for a completed fixture with a confirmed result';
  end if;
  select id into v_home_sheet from public.fixture_team_sheets
    where fixture_id = p_fixture_id and season_team_id = v_fixture.home_team_id and is_locked;
  select id into v_away_sheet from public.fixture_team_sheets
    where fixture_id = p_fixture_id and season_team_id = v_fixture.away_team_id and is_locked;
  if v_home_sheet is null or v_away_sheet is null then raise exception 'Both team sheets must be locked'; end if;

  drop table if exists pg_temp.op_goal_events;
  create temporary table pg_temp.op_goal_events on commit drop as
  select e.team_side, e.scorer_competition_player_id, coalesce(e.is_own_goal, false) as is_own_goal,
         e.assist_competition_player_id
  from jsonb_to_recordset(p_events) as e(team_side text, scorer_competition_player_id uuid,
         is_own_goal boolean, assist_competition_player_id uuid);

  select case
    when exists (select 1 from pg_temp.op_goal_events where team_side is null or team_side not in ('home','away'))
      then 'Each goal must be credited to the home or away team'
    when exists (select 1 from pg_temp.op_goal_events where scorer_competition_player_id is null)
      then 'Each goal needs a scorer'
    when (select count(*) from pg_temp.op_goal_events where team_side = 'home') > v_result.home_score
      then 'Home goal events cannot exceed the home score'
    when (select count(*) from pg_temp.op_goal_events where team_side = 'away') > v_result.away_score
      then 'Away goal events cannot exceed the away score'
    when exists (select 1 from pg_temp.op_goal_events where is_own_goal and assist_competition_player_id is not null)
      then 'An own goal cannot have an assist'
    when exists (select 1 from pg_temp.op_goal_events where assist_competition_player_id = scorer_competition_player_id)
      then 'A player cannot assist their own goal'
    -- A normal goal's scorer appeared for the credited team; an own goal's scorer appeared for the opponent.
    when exists (
      select 1 from pg_temp.op_goal_events e
      where not exists (
        select 1 from public.fixture_team_sheet_players tsp
        where tsp.did_appear is true and tsp.competition_player_id = e.scorer_competition_player_id
          and tsp.team_sheet_id = case
            when (e.team_side = 'home') <> e.is_own_goal then v_home_sheet else v_away_sheet end))
      then 'Each scorer must have appeared for the correct team (own goals: for the opponent)'
    when exists (
      select 1 from pg_temp.op_goal_events e
      where e.assist_competition_player_id is not null and not exists (
        select 1 from public.fixture_team_sheet_players tsp
        where tsp.did_appear is true and tsp.competition_player_id = e.assist_competition_player_id
          and tsp.team_sheet_id = case when e.team_side = 'home' then v_home_sheet else v_away_sheet end))
      then 'Each assist must be by a player who appeared for the credited team'
    else null
  end into v_problem;
  if v_problem is not null then raise exception '%', v_problem; end if;

  select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'season_team_id', g.season_team_id,
      'competition_player_id', g.competition_player_id, 'is_own_goal', g.is_own_goal,
      'assist_competition_player_id', g.assist_competition_player_id)), '[]'::jsonb)
    into v_before
  from public.fixture_goal_records g where g.fixture_id = p_fixture_id and g.voided_at is null;

  update public.fixture_goal_records
  set voided_at = now(), voided_by = v_actor, void_reason = btrim(p_reason)
  where fixture_id = p_fixture_id and voided_at is null;

  insert into public.fixture_goal_records(fixture_id, season_team_id, scorer_user_id, created_by,
    competition_player_id, is_own_goal, assist_competition_player_id)
  select p_fixture_id,
    case when e.team_side = 'home' then v_fixture.home_team_id else v_fixture.away_team_id end,
    (select tsp.user_id from public.fixture_team_sheet_players tsp
      where tsp.competition_player_id = e.scorer_competition_player_id
        and tsp.team_sheet_id in (v_home_sheet, v_away_sheet) limit 1),
    v_actor, e.scorer_competition_player_id, e.is_own_goal, e.assist_competition_player_id
  from pg_temp.op_goal_events e;
  get diagnostics v_count = row_count;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, before_data, after_data, reason)
  values (v_actor, 'fixture.goal_events_recorded', 'fixture', p_fixture_id::text, v_before, p_events, btrim(p_reason));

  return jsonb_build_object('recorded', v_count,
    'unattributed_home', v_result.home_score - (select count(*) from pg_temp.op_goal_events where team_side = 'home'),
    'unattributed_away', v_result.away_score - (select count(*) from pg_temp.op_goal_events where team_side = 'away'));
end;
$$;
revoke all on function public.admin_record_fixture_goal_events(uuid, jsonb, text) from public, anon;
grant execute on function public.admin_record_fixture_goal_events(uuid, jsonb, text) to authenticated;

-- 3. Statistics (recreated from deployed definitions) ---------------------------------
CREATE OR REPLACE FUNCTION public.get_my_player_statistics(p_season_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    select f.season_id,
      count(*) filter (where g.competition_player_id = v_identity.id and g.is_own_goal is not true)::integer as goals,
      count(*) filter (where g.assist_competition_player_id = v_identity.id)::integer as assists
    from public.fixture_goal_records g
    join published_results pr on pr.id = g.fixture_id
    join public.fixtures f on f.id = pr.id
    where (g.competition_player_id = v_identity.id or g.assist_competition_player_id = v_identity.id)
      and g.voided_at is null
    group by f.season_id
  )
  select
    jsonb_build_object(
      'appearances', coalesce(a.appearances, 0),
      'starts', coalesce(a.starts, 0),
      'substitute_appearances', coalesce(a.substitute_appearances, 0),
      'appearances_display', coalesce(a.starts, 0) || '(' || coalesce(a.substitute_appearances, 0) || ')',
      'goals', coalesce(g.goals, 0),
      'assists', coalesce(g.assists, 0),
      'goal_contributions', coalesce(g.goals, 0) + coalesce(g.assists, 0),
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
    select
      count(*) filter (where g.competition_player_id = v_identity.id and g.is_own_goal is not true)::integer as goals,
      count(*) filter (where g.assist_competition_player_id = v_identity.id)::integer as assists
    from public.fixture_goal_records g
    join published_results pr on pr.id = g.fixture_id
    where (g.competition_player_id = v_identity.id or g.assist_competition_player_id = v_identity.id)
      and g.voided_at is null
  )
  select jsonb_build_object(
    'appearances', coalesce(a.appearances, 0),
    'starts', coalesce(a.starts, 0),
    'substitute_appearances', coalesce(a.substitute_appearances, 0),
    'appearances_display', coalesce(a.starts, 0) || '(' || coalesce(a.substitute_appearances, 0) || ')',
    'goals', coalesce(g.goals, 0),
    'assists', coalesce(g.assists, 0),
    'goal_contributions', coalesce(g.goals, 0) + coalesce(g.assists, 0),
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
CREATE OR REPLACE FUNCTION public.get_admin_season_statistics(p_season_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid:=auth.uid();
  v_season public.seasons;
begin
 if not public.can_administer_location((select l.location_id from public.seasons s join public.leagues l on l.id=s.league_id where s.id=p_season_id)) then raise exception 'You are not assigned to this location'; end if;
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_season from public.seasons where id=p_season_id;
  if not found then raise exception 'Season not found'; end if;

  return (
    with published_results as (
      select f.id,f.season_id,f.home_team_id,f.away_team_id,r.home_score,r.away_score
      from public.fixtures f
      join public.fixture_results r on r.fixture_id=f.id and r.confirmed_at is not null
      where f.status='completed' and f.is_title_final is not true
    ),
    team_matches as (
      select home_team_id as team_id,
        case when home_score>away_score then 1 else 0 end as wins,
        case when home_score=away_score then 1 else 0 end as draws,
        case when home_score<away_score then 1 else 0 end as losses,
        home_score as goals_for,away_score as goals_against,
        case when away_score=0 then 1 else 0 end as clean_sheet
      from published_results where season_id=p_season_id
      union all
      select away_team_id as team_id,
        case when away_score>home_score then 1 else 0 end,
        case when home_score=away_score then 1 else 0 end,
        case when away_score<home_score then 1 else 0 end,
        away_score,home_score,
        case when home_score=0 then 1 else 0 end
      from published_results where season_id=p_season_id
    ),
    team_totals as (
      select st.id as team_id,st.name,
        count(tm.team_id)::integer as played,
        coalesce(sum(tm.wins),0)::integer as wins,
        coalesce(sum(tm.draws),0)::integer as draws,
        coalesce(sum(tm.losses),0)::integer as losses,
        coalesce(sum(tm.goals_for),0)::integer as goals_for,
        coalesce(sum(tm.goals_against),0)::integer as goals_against,
        coalesce(sum(tm.clean_sheet),0)::integer as clean_sheets,
        (coalesce(sum(tm.wins),0)*3+coalesce(sum(tm.draws),0))::integer as points
      from public.season_teams st
      left join team_matches tm on tm.team_id=st.id
      where st.season_id=p_season_id
      group by st.id,st.name
    ),
    ranked_teams as (
      select rank() over(order by points desc)::integer as position,
        team_id,name,played,wins,draws,losses,goals_for,goals_against,
        (goals_for-goals_against)::integer as goal_difference,points,clean_sheets
      from team_totals
    ),
    player_apps as (
      select cpi.id as competition_player_id,cpi.display_name as full_name,
        count(distinct f.id)::integer as apps,
        count(distinct f.id) filter(where tsp.role='starter')::integer as starts,
        count(distinct f.id) filter(where tsp.role='substitute')::integer as subs,
        count(distinct f.id) filter(where tsp.is_goalkeeper)::integer as goalkeeper_apps,
        count(distinct f.id) filter(where tsp.is_goalkeeper and
          ((ts.season_team_id=f.home_team_id and pr.away_score=0) or
           (ts.season_team_id=f.away_team_id and pr.home_score=0)))::integer as goalkeeper_clean_sheets
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
        and cpi.counts_for_statistics is true
      join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true
      join public.fixtures f on f.id=ts.fixture_id and f.status='completed'
      join published_results pr on pr.id=f.id
      where f.season_id=p_season_id and tsp.did_appear is true
      group by cpi.id,cpi.display_name
    ),
    player_goals as (
      select g.competition_player_id,count(*)::integer as goals
      from public.fixture_goal_records g
      join public.competition_player_identities cpi on cpi.id=g.competition_player_id
        and cpi.counts_for_statistics is true
      join published_results pr on pr.id=g.fixture_id
      join public.fixtures f on f.id=g.fixture_id
      where f.season_id=p_season_id and g.voided_at is null and g.is_own_goal is not true
      group by g.competition_player_id
    ),
    season_summary as (
      select
        (select count(*)::integer from public.fixtures f where f.season_id=p_season_id and f.status<>'cancelled') as fixtures,
        (select count(*)::integer from published_results pr where pr.season_id=p_season_id) as published_results,
        coalesce((select sum(pr.home_score+pr.away_score)::integer from published_results pr where pr.season_id=p_season_id),0) as goals,
        coalesce((select count(*)::integer from published_results pr where pr.season_id=p_season_id and pr.home_score>pr.away_score),0) as home_wins,
        coalesce((select count(*)::integer from published_results pr where pr.season_id=p_season_id and pr.away_score>pr.home_score),0) as away_wins,
        coalesce((select count(*)::integer from published_results pr where pr.season_id=p_season_id and pr.home_score=pr.away_score),0) as draws,
        coalesce((select sum(rt.clean_sheets)::integer from ranked_teams rt),0) as team_clean_sheets
    ),
    season_history as (
      select s.id,s.name,s.season_number,
        count(pr.id)::integer as published_results,
        coalesce(sum(pr.home_score+pr.away_score),0)::integer as goals,
        coalesce(round(sum(pr.home_score+pr.away_score)::numeric/nullif(count(pr.id),0),2),0) as goals_per_match
      from public.seasons s
      left join published_results pr on pr.season_id=s.id
      where s.league_id=v_season.league_id and s.is_public=true
      group by s.id,s.name,s.season_number,s.created_at
      order by s.created_at
    )
    select jsonb_build_object(
      'season',jsonb_build_object('id',v_season.id,'name',v_season.name,'status',v_season.status,'is_public',v_season.is_public),
      'summary',(select jsonb_build_object(
        'fixtures',ss.fixtures,'published_results',ss.published_results,'goals',ss.goals,
        'goals_per_match',coalesce(round(ss.goals::numeric/nullif(ss.published_results,0),2),0),
        'home_wins',ss.home_wins,'away_wins',ss.away_wins,'draws',ss.draws,
        'team_clean_sheets',ss.team_clean_sheets
      ) from season_summary ss),
      'teams',coalesce((select jsonb_agg(to_jsonb(rt) order by rt.position,rt.name) from ranked_teams rt),'[]'::jsonb),
      'players',coalesce((
        select jsonb_agg(jsonb_build_object(
          'competition_player_id',pa.competition_player_id,'full_name',pa.full_name,'apps',pa.apps,
          'starts',pa.starts,'subs',pa.subs,'apps_display',pa.starts||'('||pa.subs||')',
          'goals',coalesce(pg.goals,0),
          'assists',(select count(*) from public.fixture_goal_records ga join published_results pra on pra.id=ga.fixture_id
            where pra.season_id=p_season_id and ga.voided_at is null and ga.assist_competition_player_id=pa.competition_player_id)::integer,
          'goal_contributions',coalesce(pg.goals,0)+(select count(*) from public.fixture_goal_records ga join published_results pra on pra.id=ga.fixture_id
            where pra.season_id=p_season_id and ga.voided_at is null and ga.assist_competition_player_id=pa.competition_player_id)::integer,
          'goalkeeper_apps',pa.goalkeeper_apps,
          'goalkeeper_clean_sheets',pa.goalkeeper_clean_sheets
        ) order by coalesce(pg.goals,0) desc,pa.apps desc,pa.full_name)
        from player_apps pa left join player_goals pg on pg.competition_player_id=pa.competition_player_id
      ),'[]'::jsonb),
      'history',coalesce((select jsonb_agg(to_jsonb(sh) order by sh.season_number nulls last,sh.name) from season_history sh),'[]'::jsonb)
    )
  );
end;
$function$;
CREATE OR REPLACE FUNCTION public.get_admin_season_player_club_statistics(p_season_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      where g.voided_at is null and g.is_own_goal is not true
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
        (select count(*) from public.fixture_goal_records ga
          join published_results pra on pra.id = ga.fixture_id
          where ga.voided_at is null
            and ga.assist_competition_player_id = coalesce(a.competition_player_id, g.competition_player_id)
            and ga.season_team_id = coalesce(a.team_id, g.team_id))::integer as assists,
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
        'assists', assists,
        'goal_contributions', goals + assists,
        'goalkeeper_apps', goalkeeper_apps,
        'goalkeeper_clean_sheets', goalkeeper_clean_sheets
      )
      order by full_name, team_name
    ), '[]'::jsonb)
    from club_totals
  );
end;
$function$;
revoke all on function public.get_my_player_statistics(uuid) from public, anon;
grant execute on function public.get_my_player_statistics(uuid) to authenticated;
revoke all on function public.get_admin_season_statistics(uuid) from public, anon;
grant execute on function public.get_admin_season_statistics(uuid) to authenticated;
revoke all on function public.get_admin_season_player_club_statistics(uuid) from public, anon;
grant execute on function public.get_admin_season_player_club_statistics(uuid) to authenticated;

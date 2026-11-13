-- Owner decision D7 (docs/owner-decisions-2026-11-13.md): points only; teams level on
-- points share a position; when two teams finish level on points in first place they
-- play a final, and the season cannot be completed until that final is decided.
-- Forward-only and non-destructive.

-- 1. Title-final fixtures --------------------------------------------------------------
alter table public.fixtures add column if not exists is_title_final boolean not null default false;
comment on column public.fixtures.is_title_final is
  'Title-deciding final between teams level on points in first place. Excluded from league points; player appearances and goals still count.';
create unique index if not exists fixtures_one_active_title_final_per_season
  on public.fixtures(season_id) where is_title_final and status <> 'cancelled';

-- 2. Internal standings helpers (not callable by clients) -----------------------------
create or replace function public.season_league_points(p_season_id uuid)
returns table(team_id uuid, points integer)
language sql stable security definer set search_path = ''
as $$
  with results as (
    select f.home_team_id, f.away_team_id, r.home_score, r.away_score
    from public.fixtures f
    join public.fixture_results r on r.fixture_id = f.id and r.confirmed_at is not null
    where f.season_id = p_season_id and f.status = 'completed' and f.is_title_final is not true
  ), team_points as (
    select home_team_id as team_id,
      case when home_score > away_score then 3 when home_score = away_score then 1 else 0 end as pts
    from results
    union all
    select away_team_id,
      case when away_score > home_score then 3 when home_score = away_score then 1 else 0 end
    from results
  )
  select st.id, coalesce(sum(tp.pts), 0)::integer
  from public.season_teams st
  left join team_points tp on tp.team_id = st.id
  where st.season_id = p_season_id and st.registration_status = 'approved'
  group by st.id;
$$;
revoke all on function public.season_league_points(uuid) from public, anon, authenticated;

create or replace function public.season_joint_leaders(p_season_id uuid)
returns uuid[]
language sql stable security definer set search_path = ''
as $$
  select coalesce(array_agg(team_id order by team_id), array[]::uuid[])
  from public.season_league_points(p_season_id)
  where points = (select max(points) from public.season_league_points(p_season_id))
    and (select max(points) from public.season_league_points(p_season_id)) > 0;
$$;
revoke all on function public.season_joint_leaders(uuid) from public, anon, authenticated;

-- 3. Create the title final -----------------------------------------------------------
create or replace function public.admin_create_title_final(
  p_season_id uuid,
  p_home_team_id uuid,
  p_away_team_id uuid,
  p_scheduled_at timestamptz,
  p_venue_id uuid default null,
  p_reason text default null
)
returns public.fixtures
language plpgsql security definer set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_season public.seasons;
  v_location_id uuid;
  v_leaders uuid[];
  v_fixture public.fixtures;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_season from public.seasons where id = p_season_id for update;
  if not found then raise exception 'Season not found'; end if;
  select l.location_id into v_location_id from public.leagues l where l.id = v_season.league_id;
  if not public.can_administer_location(v_location_id) then raise exception 'You are not assigned to this location'; end if;
  if v_season.status <> 'active' then raise exception 'A title final can only be arranged for an active season'; end if;
  if exists (
    select 1 from public.fixtures f
    where f.season_id = p_season_id and f.is_title_final is not true
      and f.status not in ('completed', 'cancelled')
  ) then raise exception 'All league fixtures must be completed or cancelled before a title final is arranged'; end if;
  if exists (
    select 1 from public.fixtures f
    left join public.fixture_results r on r.fixture_id = f.id and r.confirmed_at is not null
    where f.season_id = p_season_id and f.is_title_final is not true and f.status = 'completed' and r.fixture_id is null
  ) then raise exception 'Every completed league fixture needs a confirmed result before a title final is arranged'; end if;

  v_leaders := public.season_joint_leaders(p_season_id);
  if cardinality(v_leaders) < 2 then raise exception 'First place is not shared; no title final is required'; end if;
  if cardinality(v_leaders) > 2 then
    raise exception 'More than two teams are level on points in first place; the title-decider format for this case has not been defined by the owner';
  end if;
  if p_home_team_id = p_away_team_id
     or not (p_home_team_id = any(v_leaders) and p_away_team_id = any(v_leaders)) then
    raise exception 'The final must be between the two teams level on points in first place';
  end if;
  if p_scheduled_at is null then raise exception 'Choose the date and kick-off time of the final'; end if;
  if p_reason is null or length(btrim(p_reason)) < 5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  if p_venue_id is not null and not exists (
    select 1 from public.venues v join public.locations loc on loc.id = v.location_id
    where v.id = p_venue_id and v.is_active and loc.is_active and v.location_id = v_location_id
  ) then raise exception 'The selected venue must be active and belong to the season location'; end if;

  insert into public.fixtures(season_id, gameweek, fixture_number, home_team_id, away_team_id,
    venue_id, scheduled_at, status, notes, is_title_final)
  values (p_season_id,
    coalesce((select max(gameweek) from public.fixtures where season_id = p_season_id), 0) + 1,
    1, p_home_team_id, p_away_team_id, p_venue_id, p_scheduled_at, 'scheduled', 'Title final', true)
  returning * into v_fixture;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, after_data, reason)
  values (v_actor, 'season.title_final_created', 'fixture', v_fixture.id::text,
    jsonb_build_object('season_id', p_season_id, 'home_team_id', p_home_team_id,
      'away_team_id', p_away_team_id, 'scheduled_at', p_scheduled_at, 'venue_id', p_venue_id),
    btrim(p_reason));
  return v_fixture;
end;
$$;
revoke all on function public.admin_create_title_final(uuid, uuid, uuid, timestamptz, uuid, text) from public, anon;
grant execute on function public.admin_create_title_final(uuid, uuid, uuid, timestamptz, uuid, text) to authenticated;

-- 4. Season completion guard ----------------------------------------------------------
create or replace function public.guard_season_title_final()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_leaders uuid[];
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    v_leaders := public.season_joint_leaders(new.id);
    if cardinality(v_leaders) > 1 and not exists (
      select 1 from public.fixtures f
      join public.fixture_results r on r.fixture_id = f.id and r.confirmed_at is not null
      where f.season_id = new.id and f.is_title_final and f.status = 'completed'
        and r.home_score <> r.away_score
        and f.home_team_id = any(v_leaders) and f.away_team_id = any(v_leaders)
    ) then
      raise exception 'Teams are level on points in first place. Record a decisive title final result before completing the season.';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_season_title_final() from public, anon, authenticated;
drop trigger if exists guard_season_title_final on public.seasons;
create trigger guard_season_title_final
before update of status on public.seasons
for each row execute function public.guard_season_title_final();

-- 5. League standings exclude the title final ------------------------------------------
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
      where f.season_id=p_season_id and g.voided_at is null
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
          'goals',coalesce(pg.goals,0),'goalkeeper_apps',pa.goalkeeper_apps,
          'goalkeeper_clean_sheets',pa.goalkeeper_clean_sheets
        ) order by coalesce(pg.goals,0) desc,pa.apps desc,pa.full_name)
        from player_apps pa left join player_goals pg on pg.competition_player_id=pa.competition_player_id
      ),'[]'::jsonb),
      'history',coalesce((select jsonb_agg(to_jsonb(sh) order by sh.season_number nulls last,sh.name) from season_history sh),'[]'::jsonb)
    )
  );
end;
$function$

;
revoke all on function public.get_admin_season_statistics(uuid) from public, anon;
grant execute on function public.get_admin_season_statistics(uuid) to authenticated;

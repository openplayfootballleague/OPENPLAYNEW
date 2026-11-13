-- Competition spec: "Win/draw/loss points are configurable." Owner decision D7: points
-- only, shared positions, title final when level first.
-- Points are stored per SEASON (not per league) so a later change can never rewrite an
-- archived or completed season's table. They lock once a season has a published result.
-- Forward-only and non-destructive: defaults 3/1/0 preserve every existing table.

alter table public.seasons
  add column if not exists points_for_win smallint not null default 3,
  add column if not exists points_for_draw smallint not null default 1,
  add column if not exists points_for_loss smallint not null default 0;
alter table public.seasons
  add constraint seasons_points_rules_valid check (
    points_for_loss >= 0 and points_for_draw >= points_for_loss and points_for_win >= points_for_draw and points_for_win <= 10
  );
comment on column public.seasons.points_for_win is 'League points for a win. Locked once the season has a published result.';

create or replace function public.admin_set_season_points(
  p_season_id uuid,
  p_points_for_win integer,
  p_points_for_draw integer,
  p_points_for_loss integer,
  p_reason text
)
returns public.seasons
language plpgsql security definer set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_season public.seasons;
  v_location uuid;
  v_after public.seasons;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_season from public.seasons where id = p_season_id for update;
  if not found then raise exception 'Season not found'; end if;
  select l.location_id into v_location from public.leagues l where l.id = v_season.league_id;
  if not public.can_administer_location(v_location) then raise exception 'You are not assigned to this location'; end if;
  if p_reason is null or length(btrim(p_reason)) < 5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  if p_points_for_win is null or p_points_for_draw is null or p_points_for_loss is null
     or p_points_for_loss < 0 or p_points_for_draw < p_points_for_loss or p_points_for_win < p_points_for_draw or p_points_for_win > 10 then
    raise exception 'Points must satisfy win >= draw >= loss >= 0, with win at most 10';
  end if;
  if v_season.status in ('completed', 'archived') then
    raise exception 'Points cannot change for a completed or archived season';
  end if;
  if exists (
    select 1 from public.fixtures f
    join public.fixture_results r on r.fixture_id = f.id and r.confirmed_at is not null
    where f.season_id = p_season_id
  ) then
    raise exception 'Points are locked once a result has been published in this season';
  end if;

  update public.seasons
  set points_for_win = p_points_for_win, points_for_draw = p_points_for_draw, points_for_loss = p_points_for_loss
  where id = p_season_id
  returning * into v_after;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, before_data, after_data, reason)
  values (v_actor, 'season.points_rules_updated', 'season', p_season_id::text,
    jsonb_build_object('win', v_season.points_for_win, 'draw', v_season.points_for_draw, 'loss', v_season.points_for_loss),
    jsonb_build_object('win', v_after.points_for_win, 'draw', v_after.points_for_draw, 'loss', v_after.points_for_loss),
    btrim(p_reason));
  return v_after;
end;
$$;
revoke all on function public.admin_set_season_points(uuid, integer, integer, integer, text) from public, anon;
grant execute on function public.admin_set_season_points(uuid, integer, integer, integer, text) to authenticated;

-- Points used for the title-final guard (recreated from 20261113160000 with season rules).
CREATE OR REPLACE FUNCTION public.season_league_points(p_season_id uuid)
 RETURNS TABLE(team_id uuid, points integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with results as (
    select f.home_team_id, f.away_team_id, r.home_score, r.away_score,
      s.points_for_win as pw, s.points_for_draw as pd, s.points_for_loss as pl
    from public.fixtures f
    join public.fixture_results r on r.fixture_id = f.id and r.confirmed_at is not null
    join public.seasons s on s.id = f.season_id
    where f.season_id = p_season_id and f.status = 'completed' and f.is_title_final is not true
  ), team_points as (
    select home_team_id as team_id,
      case when home_score > away_score then pw when home_score = away_score then pd else pl end as pts
    from results
    union all
    select away_team_id,
      case when away_score > home_score then pw when home_score = away_score then pd else pl end
    from results
  )
  select st.id, coalesce(sum(tp.pts), 0)::integer
  from public.season_teams st
  left join team_points tp on tp.team_id = st.id
  where st.season_id = p_season_id and st.registration_status = 'approved'
  group by st.id;
$function$;
revoke all on function public.season_league_points(uuid) from public, anon, authenticated;

-- Admin season statistics (recreated from deployed definition with season rules).
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
        (coalesce(sum(tm.wins),0)*v_season.points_for_win+coalesce(sum(tm.draws),0)*v_season.points_for_draw+coalesce(sum(tm.losses),0)*v_season.points_for_loss)::integer as points
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
$function$

;
revoke all on function public.get_admin_season_statistics(uuid) from public, anon;
grant execute on function public.get_admin_season_statistics(uuid) to authenticated;

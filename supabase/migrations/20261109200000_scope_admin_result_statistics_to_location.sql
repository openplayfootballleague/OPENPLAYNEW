-- Reconcile three admin reporting/result RPCs with the deployed location boundary.
-- The original applied migration sources omitted these guards even though the
-- hosted project already enforces them. Replaying from a clean database must
-- reproduce the same restriction. Admin standings also use points-only ranks.
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
      where f.status='completed'
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
$function$;

CREATE OR REPLACE FUNCTION public.get_admin_fixture_scorer_options(p_fixture_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid:=auth.uid();
  v_fixture public.fixtures;
  v_home_sheet public.fixture_team_sheets;
  v_away_sheet public.fixture_team_sheets;
begin
  if not public.can_administer_location((
    select l.location_id
    from public.fixtures f
    join public.seasons s on s.id=f.season_id
    join public.leagues l on l.id=s.league_id
    where f.id=p_fixture_id
  )) then raise exception 'You are not assigned to this location'; end if;
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;

  select * into v_fixture from public.fixtures where id=p_fixture_id;
  if not found then raise exception 'Fixture not found'; end if;

  select * into v_home_sheet
  from public.fixture_team_sheets
  where fixture_id=p_fixture_id and season_team_id=v_fixture.home_team_id and is_locked=true;
  select * into v_away_sheet
  from public.fixture_team_sheets
  where fixture_id=p_fixture_id and season_team_id=v_fixture.away_team_id and is_locked=true;

  return jsonb_build_object(
    'fixture_id',p_fixture_id,
    'home_team_id',v_fixture.home_team_id,
    'home_team_name',(select name from public.season_teams where id=v_fixture.home_team_id),
    'away_team_id',v_fixture.away_team_id,
    'away_team_name',(select name from public.season_teams where id=v_fixture.away_team_id),
    'home_sheet_submitted',v_home_sheet.id is not null,
    'away_sheet_submitted',v_away_sheet.id is not null,
    'home_players',coalesce((
      select jsonb_agg(jsonb_build_object(
        'competition_player_id',tsp.competition_player_id,
        'full_name',cpi.display_name,
        'role',tsp.role,
        'is_goalkeeper',tsp.is_goalkeeper,
        'did_appear',tsp.did_appear
      ) order by case when tsp.role='starter' then 0 else 1 end,cpi.display_name)
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
      where tsp.team_sheet_id=v_home_sheet.id
    ),'[]'::jsonb),
    'away_players',coalesce((
      select jsonb_agg(jsonb_build_object(
        'competition_player_id',tsp.competition_player_id,
        'full_name',cpi.display_name,
        'role',tsp.role,
        'is_goalkeeper',tsp.is_goalkeeper,
        'did_appear',tsp.did_appear
      ) order by case when tsp.role='starter' then 0 else 1 end,cpi.display_name)
      from public.fixture_team_sheet_players tsp
      join public.competition_player_identities cpi on cpi.id=tsp.competition_player_id
      where tsp.team_sheet_id=v_away_sheet.id
    ),'[]'::jsonb)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_record_fixture_result_with_appearances(p_fixture_id uuid, p_home_score integer, p_away_score integer, p_home_substitute_appearances uuid[] DEFAULT '{}'::uuid[], p_away_substitute_appearances uuid[] DEFAULT '{}'::uuid[], p_home_scorers uuid[] DEFAULT '{}'::uuid[], p_away_scorers uuid[] DEFAULT '{}'::uuid[], p_reason text DEFAULT NULL::text)
 RETURNS fixture_results
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_actor uuid:=auth.uid();
 v_fixture public.fixtures;
 v_home_sheet public.fixture_team_sheets;
 v_away_sheet public.fixture_team_sheets;
 v_existing public.fixture_results;
 v_result public.fixture_results;
 v_before jsonb;
 v_had_result boolean:=false;
begin
 if not public.can_administer_location((
   select l.location_id
   from public.fixtures f
   join public.seasons s on s.id=f.season_id
   join public.leagues l on l.id=s.league_id
   where f.id=p_fixture_id
 )) then raise exception 'You are not assigned to this location'; end if;
 if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
 if p_home_score is null or p_away_score is null or p_home_score<0 or p_away_score<0 or p_home_score>32767 or p_away_score>32767 then raise exception 'Scores must be whole numbers between 0 and 32767'; end if;
 if cardinality(coalesce(p_home_scorers,'{}'::uuid[]))<>p_home_score then raise exception 'Select exactly one home-team goalscorer for every home goal'; end if;
 if cardinality(coalesce(p_away_scorers,'{}'::uuid[]))<>p_away_score then raise exception 'Select exactly one away-team goalscorer for every away goal'; end if;
 if exists(select 1 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) x where x is null) or exists(select 1 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) x where x is null) then raise exception 'Choose a goalscorer for every goal'; end if;
 if exists(select 1 from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) x where x is null) or exists(select 1 from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) x where x is null) then raise exception 'Choose valid substitute appearances'; end if;
 if cardinality(coalesce(p_home_substitute_appearances,'{}'::uuid[]))<>(select count(distinct x) from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) x) then raise exception 'A home substitute can only be selected once'; end if;
 if cardinality(coalesce(p_away_substitute_appearances,'{}'::uuid[]))<>(select count(distinct x) from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) x) then raise exception 'An away substitute can only be selected once'; end if;

 select * into v_fixture from public.fixtures where id=p_fixture_id for update;
 if not found then raise exception 'Fixture not found'; end if;
 if v_fixture.status in ('cancelled','postponed') then raise exception 'A cancelled or postponed fixture cannot receive a result'; end if;
 select * into v_home_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=v_fixture.home_team_id and is_locked=true;
 if not found then raise exception 'The home team must submit and lock its team sheet before a result can be published'; end if;
 select * into v_away_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=v_fixture.away_team_id and is_locked=true;
 if not found then raise exception 'The away team must submit and lock its team sheet before a result can be published'; end if;

 if exists(
   select 1 from unnest(coalesce(p_home_substitute_appearances,'{}'::uuid[])) selected(competition_player_id)
   where not exists(
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_home_sheet.id
       and tsp.competition_player_id=selected.competition_player_id
       and tsp.role='substitute'
   )
 ) then raise exception 'Home appearances may only include substitutes on the submitted home team sheet'; end if;
 if exists(
   select 1 from unnest(coalesce(p_away_substitute_appearances,'{}'::uuid[])) selected(competition_player_id)
   where not exists(
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_away_sheet.id
       and tsp.competition_player_id=selected.competition_player_id
       and tsp.role='substitute'
   )
 ) then raise exception 'Away appearances may only include substitutes on the submitted away team sheet'; end if;

 select * into v_existing from public.fixture_results where fixture_id=p_fixture_id;
 v_had_result:=found;
 if v_had_result then
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters to correct an existing result'; end if;
  select jsonb_build_object(
   'home_score',v_existing.home_score,
   'away_score',v_existing.away_score,
   'goals',coalesce((
     select jsonb_agg(jsonb_build_object('season_team_id',g.season_team_id,'competition_player_id',g.competition_player_id) order by g.created_at)
     from public.fixture_goal_records g
     where g.fixture_id=p_fixture_id and g.voided_at is null
   ),'[]'::jsonb),
   'home_appearances',coalesce((
     select jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id)
     from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_home_sheet.id and tsp.did_appear is true
   ),'[]'::jsonb),
   'away_appearances',coalesce((
     select jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id)
     from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_away_sheet.id and tsp.did_appear is true
   ),'[]'::jsonb)
  ) into v_before;
  update public.fixture_goal_records
  set voided_at=now(),voided_by=v_actor,void_reason=btrim(p_reason)
  where fixture_id=p_fixture_id and voided_at is null;
 else
  v_before:='{}'::jsonb;
 end if;

 update public.fixture_team_sheet_players tsp
 set did_appear=(tsp.role='starter' or tsp.competition_player_id=any(coalesce(p_home_substitute_appearances,'{}'::uuid[])))
 where tsp.team_sheet_id=v_home_sheet.id;
 update public.fixture_team_sheet_players tsp
 set did_appear=(tsp.role='starter' or tsp.competition_player_id=any(coalesce(p_away_substitute_appearances,'{}'::uuid[])))
 where tsp.team_sheet_id=v_away_sheet.id;

 if exists(
   select 1 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) scorer(competition_player_id)
   where not exists(
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_home_sheet.id
       and tsp.competition_player_id=scorer.competition_player_id
       and tsp.did_appear is true
   )
 ) then raise exception 'Every home goalscorer must be a player who appeared in the match'; end if;
 if exists(
   select 1 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) scorer(competition_player_id)
   where not exists(
     select 1 from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_away_sheet.id
       and tsp.competition_player_id=scorer.competition_player_id
       and tsp.did_appear is true
   )
 ) then raise exception 'Every away goalscorer must be a player who appeared in the match'; end if;

 insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by,updated_at)
 values(p_fixture_id,p_home_score,p_away_score,now(),v_actor,now())
 on conflict(fixture_id) do update
 set home_score=excluded.home_score,away_score=excluded.away_score,
     confirmed_at=excluded.confirmed_at,confirmed_by=excluded.confirmed_by,updated_at=now()
 returning * into v_result;

 insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,competition_player_id,created_by)
 select p_fixture_id,v_fixture.home_team_id,p.user_id,selected.competition_player_id,v_actor
 from unnest(coalesce(p_home_scorers,'{}'::uuid[])) selected(competition_player_id)
 join public.competition_player_identities cpi on cpi.id=selected.competition_player_id
 left join public.players p on p.competition_player_id=cpi.id;
 insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,competition_player_id,created_by)
 select p_fixture_id,v_fixture.away_team_id,p.user_id,selected.competition_player_id,v_actor
 from unnest(coalesce(p_away_scorers,'{}'::uuid[])) selected(competition_player_id)
 join public.competition_player_identities cpi on cpi.id=selected.competition_player_id
 left join public.players p on p.competition_player_id=cpi.id;

 update public.fixtures set status='completed',updated_at=now() where id=p_fixture_id;
 insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
 values(
  v_actor,
  case when v_had_result then 'fixture.result.corrected' else 'fixture.result.recorded' end,
  'fixture',
  p_fixture_id::text,
  nullif(btrim(p_reason),''),
  v_before,
  jsonb_build_object(
   'home_score',p_home_score,
   'away_score',p_away_score,
   'home_scorers',to_jsonb(coalesce(p_home_scorers,'{}'::uuid[])),
   'away_scorers',to_jsonb(coalesce(p_away_scorers,'{}'::uuid[])),
   'home_appearances',coalesce((
     select jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id)
     from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_home_sheet.id and tsp.did_appear is true
   ),'[]'::jsonb),
   'away_appearances',coalesce((
     select jsonb_agg(tsp.competition_player_id order by tsp.competition_player_id)
     from public.fixture_team_sheet_players tsp
     where tsp.team_sheet_id=v_away_sheet.id and tsp.did_appear is true
   ),'[]'::jsonb),
   'status','completed'
  )
 );
 return v_result;
end;
$function$;
-- Explicitly classify genuine players before including them in competition statistics.
alter table public.players
  add column if not exists is_genuine boolean not null default false;

create or replace function public.get_admin_player_register(
  p_search text default null,
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table(
  user_id uuid,full_name text,email text,phone text,registration_status text,
  is_banned boolean,is_genuine boolean,created_at timestamptz,
  preferred_position text,team_names text[]
)
language plpgsql stable security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_search text:=nullif(btrim(p_search),'');
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_status is not null and p_status not in ('all','pending_review','registered','rejected') then raise exception 'Invalid player registration filter'; end if;
  return query
  select p.user_id,p.full_name,p.email,p.phone,p.registration_status::text,p.is_banned,p.is_genuine,p.created_at,pr.preferred_position,
    coalesce(array_agg(distinct st.name) filter(where tm.status='active' and st.id is not null),'{}'::text[])
  from public.players p
  left join public.profiles pr on pr.id=p.user_id
  left join public.team_memberships tm on tm.user_id=p.user_id and tm.status='active'
  left join public.season_teams st on st.id=tm.season_team_id
  where (v_search is null or p.full_name ilike '%'||v_search||'%' or p.email ilike '%'||v_search||'%' or p.phone ilike '%'||v_search||'%')
    and (p_status is null or p_status='all' or p.registration_status::text=p_status)
  group by p.user_id,p.full_name,p.email,p.phone,p.registration_status,p.is_banned,p.is_genuine,p.created_at,pr.preferred_position
  order by p.full_name
  limit least(greatest(coalesce(p_limit,50),1),100)
  offset greatest(coalesce(p_offset,0),0);
end; $$;

create or replace function public.admin_set_player_genuine(
  p_user_id uuid,
  p_is_genuine boolean,
  p_reason text
)
returns public.players
language plpgsql security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_player public.players; v_before boolean;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  select * into v_player from public.players where user_id=p_user_id for update;
  if not found then raise exception 'Player not found'; end if;
  if p_is_genuine and (v_player.registration_status<>'registered' or v_player.is_banned) then
    raise exception 'Only registered, non-banned players can be classified as genuine';
  end if;
  v_before:=v_player.is_genuine;
  update public.players set is_genuine=p_is_genuine,updated_at=now() where user_id=p_user_id returning * into v_player;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'player.genuine_classification_changed','player',p_user_id::text,btrim(p_reason),
    jsonb_build_object('is_genuine',v_before),jsonb_build_object('is_genuine',p_is_genuine));
  return v_player;
end; $$;

create or replace function public.get_admin_season_statistics(p_season_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_season public.seasons;
begin
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
      select row_number() over(order by points desc,(goals_for-goals_against) desc,goals_for desc,name asc)::integer as position,
        team_id,name,played,wins,draws,losses,goals_for,goals_against,
        (goals_for-goals_against)::integer as goal_difference,points,clean_sheets
      from team_totals
    ),
    player_apps as (
      select p.user_id,p.full_name,
        count(distinct f.id)::integer as apps,
        count(distinct f.id) filter(where tsp.role='starter')::integer as starts,
        count(distinct f.id) filter(where tsp.role='substitute')::integer as subs,
        count(distinct f.id) filter(where tsp.is_goalkeeper)::integer as goalkeeper_apps,
        count(distinct f.id) filter(where tsp.is_goalkeeper and
          ((ts.season_team_id=f.home_team_id and pr.away_score=0) or
           (ts.season_team_id=f.away_team_id and pr.home_score=0)))::integer as goalkeeper_clean_sheets
      from public.fixture_team_sheet_players tsp
      join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true
      join public.fixtures f on f.id=ts.fixture_id and f.status='completed'
      join published_results pr on pr.id=f.id
      join public.players p on p.user_id=tsp.user_id
        and p.registration_status='registered' and p.is_banned=false and p.is_genuine=true
      where f.season_id=p_season_id
      group by p.user_id,p.full_name
    ),
    player_goals as (
      select g.scorer_user_id,count(*)::integer as goals
      from public.fixture_goal_records g
      join published_results pr on pr.id=g.fixture_id
      join public.fixtures f on f.id=g.fixture_id
      join public.players p on p.user_id=g.scorer_user_id and p.is_genuine=true and p.registration_status='registered' and p.is_banned=false
      where f.season_id=p_season_id and g.voided_at is null
      group by g.scorer_user_id
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
      'teams',coalesce((select jsonb_agg(to_jsonb(rt) order by rt.position) from ranked_teams rt),'[]'::jsonb),
      'players',coalesce((
        select jsonb_agg(jsonb_build_object(
          'user_id',pa.user_id,'full_name',pa.full_name,'apps',pa.apps,
          'starts',pa.starts,'subs',pa.subs,'apps_display',pa.starts||'('||pa.subs||')',
          'goals',coalesce(pg.goals,0),'goalkeeper_apps',pa.goalkeeper_apps,
          'goalkeeper_clean_sheets',pa.goalkeeper_clean_sheets
        ) order by coalesce(pg.goals,0) desc,pa.apps desc,pa.full_name)
        from player_apps pa left join player_goals pg on pg.scorer_user_id=pa.user_id
      ),'[]'::jsonb),
      'history',coalesce((select jsonb_agg(to_jsonb(sh) order by sh.season_number nulls last,sh.name) from season_history sh),'[]'::jsonb)
    )
  );
end;
$$;

revoke all on function public.admin_set_player_genuine(uuid,boolean,text) from public,anon;
grant execute on function public.admin_set_player_genuine(uuid,boolean,text) to authenticated;
revoke all on function public.get_admin_season_statistics(uuid) from public,anon;
grant execute on function public.get_admin_season_statistics(uuid) to authenticated;

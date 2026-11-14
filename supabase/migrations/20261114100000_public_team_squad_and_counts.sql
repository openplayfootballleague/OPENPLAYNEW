-- Team hub squad and directory counts (reference IMG_0533, IMG_0536).
-- Signed-in members only, following the Club Leaders precedent: anon must never execute a
-- SECURITY DEFINER function. Only published seasons (public season, published league, active
-- location) and approved teams are exposed. Names are competition display names; no contact
-- details, dates of birth or account identifiers are returned. Anonymised identities are not
-- listed; identities not yet eligible for statistics are listed with zero totals. Statistics count only completed
-- fixtures with a confirmed result, locked team sheets and non-voided goal records, matching
-- get_my_player_statistics.

create or replace function public.get_public_season_team_squad_counts(p_season_id uuid)
returns table(season_team_id uuid, registered_players bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in to view squad information' using errcode='42501';
  end if;
  if not exists(
    select 1 from public.seasons s
    join public.leagues l on l.id=s.league_id
    join public.locations loc on loc.id=l.location_id
    where s.id=p_season_id and s.is_public is true and l.is_published is true and loc.is_active is true
  ) then
    raise exception 'Published season not found' using errcode='P0002';
  end if;

  return query
  select st.id, count(tm.id)::bigint
  from public.season_teams st
  left join public.team_memberships tm
    on tm.season_team_id=st.id and tm.status='active'
    and exists(
      select 1 from public.players p
      where p.user_id=tm.user_id and p.registration_status='registered' and p.is_banned is false
    )
  where st.season_id=p_season_id and st.registration_status='approved'
  group by st.id;
end;
$$;
revoke all on function public.get_public_season_team_squad_counts(uuid) from public,anon;
grant execute on function public.get_public_season_team_squad_counts(uuid) to authenticated;

create or replace function public.get_public_team_squad(p_season_team_id uuid)
returns table(
  competition_player_id uuid,
  player_name text,
  squad_number smallint,
  is_captain boolean,
  appearances bigint,
  goals bigint,
  assists bigint,
  clean_sheets bigint,
  motm_awards bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_season_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in to view squad information' using errcode='42501';
  end if;
  select st.season_id into v_season_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id and s.is_public is true
  join public.leagues l on l.id=s.league_id and l.is_published is true
  join public.locations loc on loc.id=l.location_id and loc.is_active is true
  where st.id=p_season_team_id and st.registration_status='approved';
  if v_season_id is null then
    raise exception 'Published team not found' using errcode='P0002';
  end if;

  return query
  with squad as (
    select p.competition_player_id as player_id, cpi.display_name, tm.squad_number, tm.is_captain,
      cpi.counts_for_statistics as counts
    from public.team_memberships tm
    join public.players p on p.user_id=tm.user_id
      and p.registration_status='registered' and p.is_banned is false
    join public.competition_player_identities cpi on cpi.id=p.competition_player_id
      and cpi.anonymised_at is null
    where tm.season_team_id=p_season_team_id and tm.status='active'
  ),
  published as (
    select f.id, f.home_team_id, f.away_team_id, r.home_score, r.away_score
    from public.fixtures f
    join public.fixture_results r on r.fixture_id=f.id and r.confirmed_at is not null
    where f.season_id=v_season_id and f.status='completed'
      and p_season_team_id in (f.home_team_id,f.away_team_id)
  ),
  appearances as (
    select tsp.competition_player_id as player_id,
      count(distinct pub.id)::bigint as appearances,
      count(distinct pub.id) filter (
        where tsp.is_goalkeeper and (
          (pub.home_team_id=p_season_team_id and pub.away_score=0)
          or (pub.away_team_id=p_season_team_id and pub.home_score=0)
        )
      )::bigint as clean_sheets
    from published pub
    join public.fixture_team_sheets sh on sh.fixture_id=pub.id and sh.season_team_id=p_season_team_id and sh.is_locked is true
    join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=sh.id and tsp.did_appear is true
    group by tsp.competition_player_id
  ),
  goals as (
    select g.competition_player_id as player_id, count(*)::bigint as goals
    from public.fixture_goal_records g
    join published pub on pub.id=g.fixture_id
    where g.season_team_id=p_season_team_id and g.voided_at is null and g.is_own_goal is not true
    group by g.competition_player_id
  ),
  assists as (
    select g.assist_competition_player_id as player_id, count(*)::bigint as assists
    from public.fixture_goal_records g
    join published pub on pub.id=g.fixture_id
    where g.season_team_id=p_season_team_id and g.voided_at is null and g.assist_competition_player_id is not null
    group by g.assist_competition_player_id
  ),
  motm as (
    select n.competition_player_id as player_id, count(*)::bigint as awards
    from public.fixture_motm_nominations n
    join published pub on pub.id=n.fixture_id
    where n.season_team_id=p_season_team_id
    group by n.competition_player_id
  )
  -- Identities not yet eligible for statistics (identity review) are listed with zero totals.
  select s.player_id, s.display_name, s.squad_number, s.is_captain,
    case when s.counts then coalesce(a.appearances,0) else 0 end::bigint,
    case when s.counts then coalesce(go.goals,0) else 0 end::bigint,
    case when s.counts then coalesce(asx.assists,0) else 0 end::bigint,
    case when s.counts then coalesce(a.clean_sheets,0) else 0 end::bigint,
    case when s.counts then coalesce(m.awards,0) else 0 end::bigint
  from squad s
  left join appearances a on a.player_id=s.player_id
  left join goals go on go.player_id=s.player_id
  left join assists asx on asx.player_id=s.player_id
  left join motm m on m.player_id=s.player_id
  order by s.is_captain desc, s.squad_number nulls last, s.display_name;
end;
$$;
revoke all on function public.get_public_team_squad(uuid) from public,anon;
grant execute on function public.get_public_team_squad(uuid) to authenticated;

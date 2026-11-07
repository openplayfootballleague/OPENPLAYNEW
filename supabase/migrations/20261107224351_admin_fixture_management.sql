-- Fixture scheduling, result entry and controlled match-state transitions.
create or replace function public.get_admin_competition_setup()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  return jsonb_build_object(
    'locations',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'town',l.town,'region',l.region,'address',l.address,'is_active',l.is_active) order by l.name) from public.locations l),'[]'::jsonb),
    'leagues',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'location_id',l.location_id,'location_name',loc.name,'name',l.name,'format',l.format,'description',l.description,'is_published',l.is_published) order by loc.name,l.name) from public.leagues l join public.locations loc on loc.id=l.location_id),'[]'::jsonb),
    'seasons',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'league_id',s.league_id,'league_name',l.name,'location_name',loc.name,'name',s.name,'season_number',s.season_number,'starts_on',s.starts_on,'ends_on',s.ends_on,'registration_opens_at',s.registration_opens_at,'registration_closes_at',s.registration_closes_at,'status',s.status,'is_public',s.is_public) order by loc.name,l.name,s.created_at desc) from public.seasons s join public.leagues l on l.id=s.league_id join public.locations loc on loc.id=l.location_id),'[]'::jsonb),
    'season_teams',coalesce((select jsonb_agg(jsonb_build_object('id',st.id,'season_id',st.season_id,'season_name',s.name,'league_name',l.name,'location_name',loc.name,'name',st.name,'registration_status',st.registration_status,'primary_colour',st.primary_colour,'secondary_colour',st.secondary_colour,'member_count',(select count(*) from public.team_memberships tm where tm.season_team_id=st.id and tm.status='active'),'captain_name',(select p.full_name from public.team_memberships tm join public.players p on p.user_id=tm.user_id where tm.season_team_id=st.id and tm.status='active' and tm.is_captain limit 1)) order by loc.name,s.name,st.name) from public.season_teams st join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id join public.locations loc on loc.id=l.location_id),'[]'::jsonb),
    'registered_players',coalesce((select jsonb_agg(jsonb_build_object('user_id',p.user_id,'full_name',p.full_name,'email',p.email) order by p.full_name) from public.players p where p.registration_status='registered' and p.is_banned=false),'[]'::jsonb),
    'fixtures',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',f.id,'season_id',f.season_id,'season_name',s.name,'gameweek',f.gameweek,
        'fixture_number',f.fixture_number,'home_team_id',f.home_team_id,'away_team_id',f.away_team_id,
        'home_team_name',home_team.name,'away_team_name',away_team.name,
        'venue_id',f.venue_id,'venue_name',venue.name,'scheduled_at',f.scheduled_at,
        'status',f.status,'home_score',r.home_score,'away_score',r.away_score,'notes',f.notes
      ) order by f.scheduled_at desc nulls last,f.gameweek desc,f.fixture_number)
      from public.fixtures f
      join public.seasons s on s.id=f.season_id
      join public.season_teams home_team on home_team.id=f.home_team_id
      join public.season_teams away_team on away_team.id=f.away_team_id
      left join public.locations venue on venue.id=f.venue_id
      left join public.fixture_results r on r.fixture_id=f.id
    ),'[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_create_fixture(
  p_season_id uuid,
  p_gameweek integer,
  p_fixture_number integer,
  p_home_team_id uuid,
  p_away_team_id uuid,
  p_scheduled_at timestamptz default null,
  p_venue_id uuid default null,
  p_notes text default null
)
returns public.fixtures
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_season public.seasons;
  v_home public.season_teams;
  v_away public.season_teams;
  v_fixture public.fixtures;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_gameweek is null or p_gameweek<1 then raise exception 'Gameweek must be a positive number'; end if;
  if p_fixture_number is null or p_fixture_number<1 then raise exception 'Fixture number must be a positive number'; end if;
  if p_home_team_id=p_away_team_id then raise exception 'A team cannot play itself'; end if;
  select * into v_season from public.seasons where id=p_season_id;
  if not found then raise exception 'Choose an existing season'; end if;
  if v_season.status not in ('registration_open','active') then
    raise exception 'Fixtures can only be scheduled for a season that is open for registration or active';
  end if;
  select * into v_home from public.season_teams where id=p_home_team_id and season_id=p_season_id and registration_status='approved';
  if not found then raise exception 'Choose an approved home team from this season'; end if;
  select * into v_away from public.season_teams where id=p_away_team_id and season_id=p_season_id and registration_status='approved';
  if not found then raise exception 'Choose an approved away team from this season'; end if;
  if p_venue_id is not null and not exists(select 1 from public.locations where id=p_venue_id and is_active=true) then
    raise exception 'Choose an active venue/location';
  end if;

  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status,notes)
  values(p_season_id,p_gameweek,p_fixture_number,p_home_team_id,p_away_team_id,p_venue_id,p_scheduled_at,'scheduled',nullif(btrim(p_notes),''))
  returning * into v_fixture;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'fixture.created','fixture',v_fixture.id::text,
    jsonb_build_object('season_id',p_season_id,'gameweek',p_gameweek,'fixture_number',p_fixture_number,
      'home_team_id',p_home_team_id,'away_team_id',p_away_team_id,'scheduled_at',p_scheduled_at,'venue_id',p_venue_id));
  return v_fixture;
end;
$$;

create or replace function public.admin_record_fixture_result(
  p_fixture_id uuid,
  p_home_score integer,
  p_away_score integer,
  p_reason text default null
)
returns public.fixture_results
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_fixture public.fixtures;
  v_existing public.fixture_results;
  v_result public.fixture_results;
  v_before jsonb;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_home_score is null or p_away_score is null or p_home_score<0 or p_away_score<0 then
    raise exception 'Scores must be zero or greater';
  end if;
  select * into v_fixture from public.fixtures where id=p_fixture_id for update;
  if not found then raise exception 'Fixture not found'; end if;
  if v_fixture.status in ('cancelled','postponed') then raise exception 'A cancelled or postponed fixture cannot receive a result'; end if;
  select * into v_existing from public.fixture_results where fixture_id=p_fixture_id;
  if found then
    if p_reason is null or length(btrim(p_reason))<5 then
      raise exception 'Enter a reason of at least 5 characters to correct an existing result';
    end if;
    v_before:=jsonb_build_object('home_score',v_existing.home_score,'away_score',v_existing.away_score);
  else
    v_before:='{}'::jsonb;
  end if;

  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by,updated_at)
  values(p_fixture_id,p_home_score,p_away_score,now(),v_actor,now())
  on conflict(fixture_id) do update set
    home_score=excluded.home_score,away_score=excluded.away_score,
    confirmed_at=excluded.confirmed_at,confirmed_by=excluded.confirmed_by,updated_at=now()
  returning * into v_result;

  update public.fixtures set status='completed',updated_at=now() where id=p_fixture_id;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,case when v_existing.fixture_id is null then 'fixture.result.recorded' else 'fixture.result.corrected' end,
    'fixture',p_fixture_id::text,nullif(btrim(p_reason),''),v_before,
    jsonb_build_object('home_score',p_home_score,'away_score',p_away_score,'status','completed'));
  return v_result;
end;
$$;

create or replace function public.admin_set_fixture_status(
  p_fixture_id uuid,
  p_next_status public.fixture_status,
  p_reason text default null
)
returns public.fixtures
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_fixture public.fixtures;
  v_previous public.fixture_status;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_fixture from public.fixtures where id=p_fixture_id for update;
  if not found then raise exception 'Fixture not found'; end if;
  v_previous:=v_fixture.status;

  if not (
    (v_previous='scheduled' and p_next_status in ('in_progress','postponed','cancelled')) or
    (v_previous='in_progress' and p_next_status in ('postponed','cancelled')) or
    (v_previous='postponed' and p_next_status in ('scheduled','cancelled'))
  ) then
    raise exception 'Invalid fixture status transition from % to %',v_previous,p_next_status;
  end if;
  if p_next_status in ('postponed','cancelled') and (p_reason is null or length(btrim(p_reason))<5) then
    raise exception 'Enter a reason of at least 5 characters for postponing or cancelling a fixture';
  end if;

  update public.fixtures set status=p_next_status,updated_at=now()
  where id=p_fixture_id returning * into v_fixture;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'fixture.status_changed','fixture',p_fixture_id::text,nullif(btrim(p_reason),''),
    jsonb_build_object('status',v_previous),jsonb_build_object('status',p_next_status));
  return v_fixture;
end;
$$;

revoke all on function public.get_admin_competition_setup() from public,anon;
grant execute on function public.get_admin_competition_setup() to authenticated;
revoke all on function public.admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamptz,uuid,text) from public,anon;
grant execute on function public.admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamptz,uuid,text) to authenticated;
revoke all on function public.admin_record_fixture_result(uuid,integer,integer,text) from public,anon;
grant execute on function public.admin_record_fixture_result(uuid,integer,integer,text) to authenticated;
revoke all on function public.admin_set_fixture_status(uuid,public.fixture_status,text) from public,anon;
grant execute on function public.admin_set_fixture_status(uuid,public.fixture_status,text) to authenticated;

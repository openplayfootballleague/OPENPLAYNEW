-- Season matchday settings and safe round-robin fixture generation.
alter table public.seasons
  add column if not exists matchday_weekday smallint,
  add column if not exists matchday_start_time time,
  add column if not exists match_duration_minutes smallint,
  add column if not exists matchday_buffer_minutes smallint not null default 0,
  add column if not exists default_venue_id uuid,
  add column if not exists round_robin_mode text not null default 'double';

do $$
begin
  if not exists(select 1 from pg_constraint where conname='seasons_matchday_weekday_check' and conrelid='public.seasons'::regclass) then
    alter table public.seasons add constraint seasons_matchday_weekday_check
      check(matchday_weekday is null or matchday_weekday between 0 and 6);
  end if;
  if not exists(select 1 from pg_constraint where conname='seasons_matchday_configuration_check' and conrelid='public.seasons'::regclass) then
    alter table public.seasons add constraint seasons_matchday_configuration_check
      check(
        (matchday_weekday is null and matchday_start_time is null and match_duration_minutes is null)
        or
        (matchday_weekday is not null and matchday_start_time is not null and match_duration_minutes between 5 and 120)
      );
  end if;
  if not exists(select 1 from pg_constraint where conname='seasons_matchday_buffer_check' and conrelid='public.seasons'::regclass) then
    alter table public.seasons add constraint seasons_matchday_buffer_check
      check(matchday_buffer_minutes between 0 and 30);
  end if;
  if not exists(select 1 from pg_constraint where conname='seasons_round_robin_mode_check' and conrelid='public.seasons'::regclass) then
    alter table public.seasons add constraint seasons_round_robin_mode_check
      check(round_robin_mode in ('single','double'));
  end if;
  if not exists(select 1 from pg_constraint where conname='seasons_default_venue_id_fkey' and conrelid='public.seasons'::regclass) then
    alter table public.seasons add constraint seasons_default_venue_id_fkey
      foreign key(default_venue_id) references public.venues(id) on delete set null;
  end if;
end $$;

create index if not exists seasons_default_venue_id_idx on public.seasons(default_venue_id);

create or replace function public.admin_update_season_matchday_settings(
  p_season_id uuid,
  p_matchday_weekday smallint,
  p_matchday_start_time time,
  p_match_duration_minutes smallint,
  p_matchday_buffer_minutes smallint default 0,
  p_default_venue_id uuid default null,
  p_round_robin_mode text default 'double'
) returns public.seasons
language plpgsql security definer set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_season public.seasons;
  v_location_id uuid;
  v_venue public.venues;
  v_mode text:=coalesce(p_round_robin_mode,'double');
  v_buffer smallint:=coalesce(p_matchday_buffer_minutes,0);
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_season from public.seasons where id=p_season_id for update;
  if not found then raise exception 'Choose an existing season'; end if;
  select location_id into v_location_id from public.leagues where id=v_season.league_id;
  if not public.can_administer_location(v_location_id) then raise exception 'You are not assigned to this location'; end if;
  if v_season.status not in ('draft','registration_open','active') then
    raise exception 'Matchday settings cannot be changed for a completed or cancelled season';
  end if;
  if exists(select 1 from public.fixtures where season_id=p_season_id) then
    raise exception 'Matchday settings are locked after fixtures have been generated';
  end if;
  if p_matchday_weekday is not null and p_matchday_weekday not between 0 and 6 then
    raise exception 'Choose a valid matchday';
  end if;
  if (p_matchday_weekday is null and (p_matchday_start_time is not null or p_match_duration_minutes is not null))
     or (p_matchday_weekday is not null and (p_matchday_start_time is null or p_match_duration_minutes is null)) then
    raise exception 'Set the matchday, start time and match duration together';
  end if;
  if p_match_duration_minutes is not null and p_match_duration_minutes not between 5 and 120 then
    raise exception 'Match duration must be between 5 and 120 minutes';
  end if;
  if v_buffer not between 0 and 30 then raise exception 'The interval between fixtures must be between 0 and 30 minutes'; end if;
  if v_mode not in ('single','double') then raise exception 'Choose a single or double round-robin format'; end if;
  if p_default_venue_id is not null then
    select v.* into v_venue from public.venues v
      join public.locations loc on loc.id=v.location_id
      where v.id=p_default_venue_id and v.is_active=true and loc.is_active=true;
    if not found then raise exception 'Choose an active venue at an active location'; end if;
    if v_venue.location_id<>v_location_id then raise exception 'The default venue must belong to the season location'; end if;
    if p_matchday_weekday is not null and cardinality(v_venue.operating_days)>0
       and not (p_matchday_weekday=any(v_venue.operating_days)) then
      raise exception 'The selected venue is not operating on the configured matchday';
    end if;
    if p_matchday_start_time is not null and v_venue.opens_at is not null
       and p_matchday_start_time<v_venue.opens_at then
      raise exception 'The configured matchday starts before the venue opens';
    end if;
    if p_matchday_start_time is not null and v_venue.closes_at is not null
       and p_matchday_start_time>=v_venue.closes_at then
      raise exception 'The configured matchday starts after the venue closes';
    end if;
    if p_matchday_start_time is not null and p_match_duration_minutes is not null
       and p_matchday_start_time+make_interval(mins=>p_match_duration_minutes)<p_matchday_start_time then
      raise exception 'A match cannot extend past midnight';
    end if;
    if p_matchday_start_time is not null and p_match_duration_minutes is not null
       and v_venue.closes_at is not null
       and p_matchday_start_time+make_interval(mins=>p_match_duration_minutes)>v_venue.closes_at then
      raise exception 'The match duration extends beyond the venue closing time';
    end if;
  end if;

  update public.seasons set
    matchday_weekday=p_matchday_weekday,
    matchday_start_time=p_matchday_start_time,
    match_duration_minutes=p_match_duration_minutes,
    matchday_buffer_minutes=v_buffer,
    default_venue_id=p_default_venue_id,
    round_robin_mode=v_mode,
    updated_at=now()
  where id=p_season_id returning * into v_season;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'season.matchday_settings_updated','season',v_season.id::text,
    jsonb_build_object('matchday_weekday',v_season.matchday_weekday,'matchday_start_time',v_season.matchday_start_time,
      'match_duration_minutes',v_season.match_duration_minutes,'matchday_buffer_minutes',v_season.matchday_buffer_minutes,
      'default_venue_id',v_season.default_venue_id,'round_robin_mode',v_season.round_robin_mode));
  return v_season;
end;
$$;
revoke all on function public.admin_update_season_matchday_settings(uuid,smallint,time,smallint,smallint,uuid,text) from public,anon;
grant execute on function public.admin_update_season_matchday_settings(uuid,smallint,time,smallint,smallint,uuid,text) to authenticated;

create or replace function public.build_round_robin_fixture_schedule(
  p_season_id uuid,
  p_first_matchday_date date
) returns table(
  gameweek integer,
  fixture_number integer,
  home_team_id uuid,
  away_team_id uuid,
  scheduled_at timestamptz
)
language plpgsql stable security definer set search_path=''
as $
declare
  v_season public.seasons;
  v_location_id uuid;
  v_venue public.venues;
  v_team_ids uuid[];
  v_original_team_ids uuid[];
  v_team_count integer;
  v_padded_count integer;
  v_rounds_per_leg integer;
  v_legs integer;
  v_matches_per_round integer;
  v_slots_per_round integer;
  v_total_rounds integer;
  v_total_slot_minutes integer;
  v_last_end_time time;
  v_last_date date;
  v_day smallint;
  v_leg integer;
  v_round integer;
  v_slot integer;
  v_gameweek integer;
  v_fixture_number integer;
  v_home uuid;
  v_away uuid;
  v_last_team uuid;
  v_matchday_date date;
  v_local_start timestamp without time zone;
begin
  if p_first_matchday_date is null then raise exception 'Choose the first matchday date'; end if;
  select * into v_season from public.seasons where id=p_season_id for update;
  if not found then raise exception 'Choose an existing season'; end if;
  if v_season.status not in ('draft','registration_open','active') then
    raise exception 'Fixtures can only be generated for a season that is open for registration or active';
  end if;
  if v_season.matchday_weekday is null or v_season.matchday_start_time is null or v_season.match_duration_minutes is null then
    raise exception 'Save the season matchday, start time and match duration before generating fixtures';
  end if;
  if v_season.default_venue_id is null then raise exception 'Choose a default venue before generating fixtures'; end if;
  if extract(dow from p_first_matchday_date)::smallint<>v_season.matchday_weekday then
    raise exception 'The first matchday date does not match the configured weekday';
  end if;
  if v_season.starts_on is not null and p_first_matchday_date<v_season.starts_on then
    raise exception 'The first matchday is before the season start date';
  end if;
  select location_id into v_location_id from public.leagues where id=v_season.league_id;
  select v.* into v_venue from public.venues v
    join public.locations loc on loc.id=v.location_id
    where v.id=v_season.default_venue_id and v.is_active=true and loc.is_active=true;
  if not found then raise exception 'The season default venue is no longer active'; end if;
  if v_venue.location_id<>v_location_id then raise exception 'The default venue must belong to the season location'; end if;
  v_day:=extract(dow from p_first_matchday_date)::smallint;
  if cardinality(v_venue.operating_days)>0 and not (v_day=any(v_venue.operating_days)) then
    raise exception 'The venue is not operating on the configured matchday';
  end if;
  if v_venue.opens_at is not null and v_season.matchday_start_time<v_venue.opens_at then
    raise exception 'The configured matchday starts before the venue opens';
  end if;
  if v_venue.closes_at is not null and v_season.matchday_start_time>=v_venue.closes_at then
    raise exception 'The configured matchday starts after the venue closes';
  end if;

  select array_agg(st.id order by st.name,st.id) into v_team_ids
  from public.season_teams st
  where st.season_id=p_season_id and st.registration_status='approved';
  v_team_count:=coalesce(cardinality(v_team_ids),0);
  if v_team_count<2 then raise exception 'At least two approved teams are required to generate fixtures'; end if;
  v_original_team_ids:=v_team_ids;
  if mod(v_team_count,2)=1 then v_original_team_ids:=array_append(v_original_team_ids,null::uuid); end if;
  v_padded_count:=cardinality(v_original_team_ids);
  v_rounds_per_leg:=v_padded_count-1;
  v_legs:=case when v_season.round_robin_mode='double' then 2 else 1 end;
  v_slots_per_round:=v_padded_count/2;
  v_matches_per_round:=v_team_count/2;
  v_total_rounds:=v_rounds_per_leg*v_legs;
  v_total_slot_minutes:=v_matches_per_round*v_season.match_duration_minutes
    +(v_matches_per_round-1)*v_season.matchday_buffer_minutes;
  if v_total_slot_minutes>=1440 then raise exception 'The full gameweek schedule cannot exceed one day'; end if;
  v_last_end_time:=v_season.matchday_start_time+make_interval(mins=>v_total_slot_minutes);
  if v_last_end_time<v_season.matchday_start_time then raise exception 'The full gameweek schedule cannot extend past midnight'; end if;
  if v_venue.closes_at is not null and v_last_end_time>v_venue.closes_at then
    raise exception 'The full gameweek schedule does not fit within the venue operating hours';
  end if;
  v_last_date:=p_first_matchday_date+((v_total_rounds-1)*7);
  if v_season.ends_on is not null and v_last_date>v_season.ends_on then
    raise exception 'The generated schedule would extend beyond the season end date';
  end if;
  if exists(select 1 from public.fixtures where season_id=p_season_id) then
    raise exception 'Fixtures already exist for this season; generation will not overwrite them';
  end if;

  for v_leg in 1..v_legs loop
    v_team_ids:=v_original_team_ids;
    for v_round in 1..v_rounds_per_leg loop
      v_gameweek:=(v_leg-1)*v_rounds_per_leg+v_round;
      v_fixture_number:=0;
      for v_slot in 1..v_slots_per_round loop
        v_home:=v_team_ids[v_slot];
        v_away:=v_team_ids[v_padded_count-v_slot+1];
        if v_home is not null and v_away is not null then
          v_fixture_number:=v_fixture_number+1;
          if mod(v_round+v_slot,2)<>0 then
            v_last_team:=v_home; v_home:=v_away; v_away:=v_last_team;
          end if;
          if v_leg=2 then
            v_last_team:=v_home; v_home:=v_away; v_away:=v_last_team;
          end if;
          v_matchday_date:=p_first_matchday_date+((v_gameweek-1)*7);
          v_local_start:=v_matchday_date+v_season.matchday_start_time
            +make_interval(mins=>(v_fixture_number-1)*(v_season.match_duration_minutes+v_season.matchday_buffer_minutes));
          gameweek:=v_gameweek;
          fixture_number:=v_fixture_number;
          home_team_id:=v_home;
          away_team_id:=v_away;
          scheduled_at:=v_local_start at time zone 'Europe/London';
          return next;
        end if;
      end loop;
      if v_round<v_rounds_per_leg then
        v_last_team:=v_team_ids[v_padded_count];
        v_team_ids:=array[v_team_ids[1],v_last_team]||v_team_ids[2:v_padded_count-1];
      end if;
    end loop;
  end loop;
end;
$$;
revoke all on function public.build_round_robin_fixture_schedule(uuid,date) from public,anon,authenticated;

create or replace function public.round_robin_fixture_settings_hash(
  p_season_id uuid,
  p_first_matchday_date date
) returns text
language plpgsql stable security definer set search_path=''
as $
declare
  v_season public.seasons;
  v_venue public.venues;
  v_approved_teams text;
begin
  select * into v_season from public.seasons where id=p_season_id;
  if not found then raise exception 'Choose an existing season'; end if;
  select * into v_venue from public.venues where id=v_season.default_venue_id;
  if not found then raise exception 'Choose an active default venue'; end if;
  select string_agg(st.id::text||':'||st.name,',' order by st.name,st.id)
    into v_approved_teams
  from public.season_teams st
  where st.season_id=p_season_id and st.registration_status='approved';
  return md5(concat_ws('|',
    coalesce(v_season.matchday_weekday::text,''),
    coalesce(v_season.matchday_start_time::text,''),
    coalesce(v_season.match_duration_minutes::text,''),
    coalesce(v_season.matchday_buffer_minutes::text,''),
    coalesce(v_season.default_venue_id::text,''),
    coalesce(v_season.round_robin_mode,''),
    coalesce(v_season.starts_on::text,''),
    coalesce(v_season.ends_on::text,''),
    coalesce(v_venue.location_id::text,''),
    coalesce(v_venue.operating_days::text,''),
    coalesce(v_venue.opens_at::text,''),
    coalesce(v_venue.closes_at::text,''),
    coalesce(v_venue.is_active::text,''),
    coalesce(v_approved_teams,''),
    coalesce(p_first_matchday_date::text,'')
  ));
end;
$;
revoke all on function public.round_robin_fixture_settings_hash(uuid,date) from public,anon,authenticated;

create or replace function public.admin_preview_round_robin_fixtures(
  p_season_id uuid,
  p_first_matchday_date date
) returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_location_id uuid;
  v_season public.seasons;
  v_venue public.venues;
  v_fixture_count integer;
  v_round_count integer;
  v_last_date date;
  v_fixtures jsonb;
  v_settings_hash text;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_season from public.seasons where id=p_season_id;
  if not found then raise exception 'Choose an existing season'; end if;
  select location_id into v_location_id from public.leagues where id=v_season.league_id;
  if not public.can_administer_location(v_location_id) then raise exception 'You are not assigned to this location'; end if;
  select * into v_venue from public.venues where id=v_season.default_venue_id;
  v_settings_hash:=public.round_robin_fixture_settings_hash(p_season_id,p_first_matchday_date);
  with schedule as materialized (
    select * from public.build_round_robin_fixture_schedule(p_season_id,p_first_matchday_date)
  )
  select count(*),coalesce(max(gameweek),0),
    max((scheduled_at at time zone 'Europe/London')::date),
    jsonb_agg(jsonb_build_object(
      'gameweek',schedule.gameweek,'fixture_number',schedule.fixture_number,
      'home_team_id',schedule.home_team_id,'home_team_name',home_team.name,
      'away_team_id',schedule.away_team_id,'away_team_name',away_team.name,
      'scheduled_at',schedule.scheduled_at
    ) order by schedule.gameweek,schedule.fixture_number)
  into v_fixture_count,v_round_count,v_last_date,v_fixtures
  from schedule
  join public.season_teams home_team on home_team.id=schedule.home_team_id
  join public.season_teams away_team on away_team.id=schedule.away_team_id;

  return jsonb_build_object(
    'season_id',v_season.id,'season_name',v_season.name,
    'venue_id',v_venue.id,'venue_name',v_venue.name,
    'first_matchday_date',p_first_matchday_date,'last_matchday_date',v_last_date,
    'round_count',v_round_count,'fixture_count',v_fixture_count,'settings_hash',v_settings_hash,
    'fixtures',coalesce(v_fixtures,'[]'::jsonb)
  );
end;
$$;
revoke all on function public.admin_preview_round_robin_fixtures(uuid,date) from public,anon;
grant execute on function public.admin_preview_round_robin_fixtures(uuid,date) to authenticated;

create or replace function public.admin_generate_round_robin_fixtures(
  p_season_id uuid,
  p_first_matchday_date date,
  p_expected_settings_hash text
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_season public.seasons;
  v_location_id uuid;
  v_team_count integer;
  v_rounds_per_leg integer;
  v_legs integer;
  v_expected_fixtures integer;
  v_inserted integer;
  v_last_date date;
  v_settings_hash text;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_season from public.seasons where id=p_season_id for update;
  if not found then raise exception 'Choose an existing season'; end if;
  select location_id into v_location_id from public.leagues where id=v_season.league_id;
  if not public.can_administer_location(v_location_id) then raise exception 'You are not assigned to this location'; end if;
  v_settings_hash:=public.round_robin_fixture_settings_hash(p_season_id,p_first_matchday_date);
  if p_expected_settings_hash is null or p_expected_settings_hash<>v_settings_hash then
    raise exception 'Season matchday settings changed since preview; preview the schedule again';
  end if;
  if exists(select 1 from public.fixtures where season_id=p_season_id) then
    raise exception 'Fixtures already exist for this season; generation will not overwrite them';
  end if;
  select count(*) into v_team_count from public.season_teams
    where season_id=p_season_id and registration_status='approved';
  if v_team_count<2 then raise exception 'At least two approved teams are required to generate fixtures'; end if;
  v_rounds_per_leg:=case when mod(v_team_count,2)=0 then v_team_count-1 else v_team_count end;
  v_legs:=case when v_season.round_robin_mode='double' then 2 else 1 end;
  v_expected_fixtures:=(v_team_count*(v_team_count-1)/2)*v_legs;
  v_last_date:=p_first_matchday_date+((v_rounds_per_leg*v_legs-1)*7);

  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  select p_season_id,s.gameweek,s.fixture_number,s.home_team_id,s.away_team_id,v_season.default_venue_id,s.scheduled_at,'scheduled'
  from public.build_round_robin_fixture_schedule(p_season_id,p_first_matchday_date) s
  order by s.gameweek,s.fixture_number;
  get diagnostics v_inserted=row_count;
  if v_inserted<>v_expected_fixtures then
    raise exception 'Fixture generation count mismatch: expected %, created %',v_expected_fixtures,v_inserted;
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'fixtures.generated','season',p_season_id::text,
    jsonb_build_object('round_robin_mode',v_season.round_robin_mode,'fixture_count',v_inserted,
      'round_count',v_rounds_per_leg*v_legs,'first_matchday_date',p_first_matchday_date,
      'last_matchday_date',v_last_date,'venue_id',v_season.default_venue_id));
  return jsonb_build_object('season_id',p_season_id,'season_name',v_season.name,
    'fixture_count',v_inserted,'round_count',v_rounds_per_leg*v_legs,'settings_hash',v_settings_hash,
    'first_matchday_date',p_first_matchday_date,'last_matchday_date',v_last_date);
end;
$$;
revoke all on function public.admin_generate_round_robin_fixtures(uuid,date,text) from public,anon;
grant execute on function public.admin_generate_round_robin_fixtures(uuid,date,text) to authenticated;

-- Manual fixture creation inherits the season's configured venue and checks full match duration.
create or replace function public.admin_create_fixture(
  p_season_id uuid,
  p_gameweek integer,
  p_fixture_number integer,
  p_home_team_id uuid,
  p_away_team_id uuid,
  p_scheduled_at timestamptz default null,
  p_venue_id uuid default null,
  p_notes text default null
) returns public.fixtures
language plpgsql security definer set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_season public.seasons;
  v_home public.season_teams;
  v_away public.season_teams;
  v_fixture public.fixtures;
  v_venue public.venues;
  v_location_id uuid;
  v_local_scheduled timestamp without time zone;
  v_day smallint;
  v_match_end_time time;
begin
  select l.location_id into v_location_id
  from public.seasons s join public.leagues l on l.id=s.league_id
  where s.id=p_season_id;
  if not public.can_administer_location(v_location_id) then raise exception 'You are not assigned to this location'; end if;
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

  p_venue_id:=coalesce(p_venue_id,v_season.default_venue_id);
  if p_venue_id is not null then
    select v.* into v_venue from public.venues v
    join public.locations loc on loc.id=v.location_id
    where v.id=p_venue_id and v.is_active=true and loc.is_active=true;
    if not found then raise exception 'Choose an active venue at an active location'; end if;
    if v_venue.location_id<>v_location_id then raise exception 'The selected venue must belong to the season location'; end if;
    if p_scheduled_at is not null then
      v_local_scheduled:=p_scheduled_at at time zone 'Europe/London';
      if v_season.starts_on is not null and v_local_scheduled::date<v_season.starts_on then
        raise exception 'The fixture is before the season start date';
      end if;
      if v_season.ends_on is not null and v_local_scheduled::date>v_season.ends_on then
        raise exception 'The fixture is after the season end date';
      end if;
      v_day:=extract(dow from v_local_scheduled)::smallint;
      if cardinality(v_venue.operating_days)>0 and not (v_day=any(v_venue.operating_days)) then
        raise exception 'The selected venue is not operating on the scheduled day';
      end if;
      if v_venue.opens_at is not null and v_local_scheduled::time<v_venue.opens_at then
        raise exception 'The scheduled time is before the selected venue opens';
      end if;
      if v_venue.closes_at is not null and v_local_scheduled::time>=v_venue.closes_at then
        raise exception 'The scheduled time is after the selected venue closes';
      end if;
      v_match_end_time:=v_local_scheduled::time+make_interval(mins=>coalesce(v_season.match_duration_minutes,0));
      if v_match_end_time<v_local_scheduled::time then raise exception 'A fixture cannot extend past midnight'; end if;
      if v_venue.closes_at is not null and v_match_end_time>v_venue.closes_at then
        raise exception 'The full match duration extends beyond the selected venue closing time';
      end if;
    end if;
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
revoke all on function public.admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamptz,uuid,text) from public,anon;
grant execute on function public.admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamptz,uuid,text) to authenticated;

create or replace function public.get_admin_competition_setup()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if exists(select 1 from public.user_roles where user_id=v_actor and role='league_admin')
     and not exists(select 1 from public.location_admin_assignments where user_id=v_actor) then
    raise exception 'No locations have been assigned to this administrator';
  end if;

  return jsonb_build_object(
    'locations',coalesce((
      select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'town',l.town,'region',l.region,'address',l.address,'is_active',l.is_active) order by l.name)
      from public.locations l where public.can_administer_location(l.id)
    ),'[]'::jsonb),
    'venues',coalesce((
      select jsonb_agg(jsonb_build_object('id',v.id,'location_id',v.location_id,'location_name',loc.name,'name',v.name,'address',v.address,'operating_days',v.operating_days,'opens_at',v.opens_at,'closes_at',v.closes_at,'is_active',v.is_active) order by loc.name,v.name)
      from public.venues v join public.locations loc on loc.id=v.location_id
      where public.can_administer_location(v.location_id)
    ),'[]'::jsonb),
    'leagues',coalesce((
      select jsonb_agg(jsonb_build_object('id',l.id,'location_id',l.location_id,'location_name',loc.name,'name',l.name,'format',l.format,'description',l.description,'is_published',l.is_published) order by loc.name,l.name)
      from public.leagues l join public.locations loc on loc.id=l.location_id
      where public.can_administer_location(l.location_id)
    ),'[]'::jsonb),
    'seasons',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',s.id,'league_id',s.league_id,'location_id',l.location_id,'league_name',l.name,
        'location_name',loc.name,'name',s.name,'season_number',s.season_number,
        'starts_on',s.starts_on,'ends_on',s.ends_on,
        'registration_opens_at',s.registration_opens_at,'registration_closes_at',s.registration_closes_at,
        'status',s.status,'recruitment_status',s.recruitment_status,
        'recruitment_opened_at',s.recruitment_opened_at,'recruitment_closed_at',s.recruitment_closed_at,
        'matchday_weekday',s.matchday_weekday,'matchday_start_time',s.matchday_start_time,
        'match_duration_minutes',s.match_duration_minutes,'matchday_buffer_minutes',s.matchday_buffer_minutes,
        'default_venue_id',s.default_venue_id,'round_robin_mode',s.round_robin_mode,
        'is_public',s.is_public
      ) order by loc.name,l.name,s.created_at desc)
      from public.seasons s join public.leagues l on l.id=s.league_id join public.locations loc on loc.id=l.location_id
      where public.can_administer_location(l.location_id)
    ),'[]'::jsonb),
    'season_teams',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',st.id,'season_id',st.season_id,'season_name',s.name,'league_name',l.name,
        'location_name',loc.name,'name',st.name,'registration_status',st.registration_status,
        'primary_colour',st.primary_colour,'secondary_colour',st.secondary_colour,
        'member_count',(select count(*) from public.team_memberships tm where tm.season_team_id=st.id and tm.status='active'),
        'captain_name',(select p.full_name from public.team_memberships tm join public.players p on p.user_id=tm.user_id where tm.season_team_id=st.id and tm.status='active' and tm.is_captain limit 1)
      ) order by loc.name,s.name,st.name)
      from public.season_teams st join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id join public.locations loc on loc.id=l.location_id
      where public.can_administer_location(l.location_id)
    ),'[]'::jsonb),
    'registered_players',coalesce((
      select jsonb_agg(jsonb_build_object('user_id',p.user_id,'full_name',p.full_name,'email',p.email) order by p.full_name)
      from public.players p
      where p.registration_status='registered' and p.is_banned=false
        and exists(select 1 from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id
          where tm.user_id=p.user_id and tm.status='active' and public.can_administer_location(l.location_id))
    ),'[]'::jsonb),
    'fixtures',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',f.id,'season_id',f.season_id,'season_name',s.name,'gameweek',f.gameweek,'fixture_number',f.fixture_number,
        'home_team_id',f.home_team_id,'away_team_id',f.away_team_id,'home_team_name',ht.name,'away_team_name',at.name,
        'venue_id',f.venue_id,'venue_name',venue.name,'scheduled_at',f.scheduled_at,'status',f.status,
        'home_score',r.home_score,'away_score',r.away_score,'notes',f.notes
      ) order by f.scheduled_at desc nulls last,f.gameweek desc,f.fixture_number)
      from public.fixtures f join public.seasons s on s.id=f.season_id join public.leagues l on l.id=s.league_id
      join public.season_teams ht on ht.id=f.home_team_id join public.season_teams at on at.id=f.away_team_id
      left join public.venues venue on venue.id=f.venue_id left join public.fixture_results r on r.fixture_id=f.id
      where public.can_administer_location(l.location_id)
    ),'[]'::jsonb)
  );
end;
$$;
revoke all on function public.get_admin_competition_setup() from public,anon;
grant execute on function public.get_admin_competition_setup() to authenticated;


-- Multiple named venues per location, with explicit operating days and hours.
create table public.venues (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 120),
  address text,
  operating_days smallint[] not null default '{}'::smallint[],
  opens_at time without time zone,
  closes_at time without time zone,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint venues_operating_days_valid check (operating_days <@ array[0,1,2,3,4,5,6]::smallint[]),
  constraint venues_opening_hours_valid check (
    (opens_at is null and closes_at is null)
    or (opens_at is not null and closes_at is not null and opens_at < closes_at)
  )
);

create unique index venues_location_name_unique on public.venues(location_id, lower(name));
create index venues_location_active_idx on public.venues(location_id,is_active);

-- Preserve every existing fixture venue reference by creating one default venue
-- per existing location with the same UUID as the location.
insert into public.venues(id,location_id,name,address,is_active)
select l.id,l.id,coalesce(nullif(btrim(l.name),''),'Main venue'),l.address,l.is_active
from public.locations l
on conflict (id) do nothing;

create or replace function public.set_venue_updated_at()
returns trigger language plpgsql set search_path=''
as $$
begin
  new.updated_at:=now();
  return new;
end;
$$;
revoke all on function public.set_venue_updated_at() from public,anon,authenticated;

create trigger venues_set_updated_at
before update on public.venues
for each row execute function public.set_venue_updated_at();

create or replace function public.create_default_venue_for_location()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  insert into public.venues(id,location_id,name,address,is_active)
  values(new.id,new.id,coalesce(nullif(btrim(new.name),''),'Main venue'),new.address,new.is_active)
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function public.create_default_venue_for_location() from public,anon,authenticated;

create trigger locations_create_default_venue
after insert on public.locations
for each row execute function public.create_default_venue_for_location();

alter table public.fixtures drop constraint if exists fixtures_venue_id_fkey;
alter table public.fixtures
  add constraint fixtures_venue_id_fkey
  foreign key (venue_id) references public.venues(id) on delete set null;

alter table public.venues enable row level security;
drop policy if exists venues_select_active_or_admin on public.venues;
drop policy if exists venues_public_read on public.venues;
drop policy if exists venues_admin_read on public.venues;
create policy venues_public_read on public.venues
for select to anon,authenticated using (
  is_active=true and exists(select 1 from public.locations l where l.id=location_id and l.is_active=true)
);
create policy venues_admin_read on public.venues
for select to authenticated using (public.can_administer_location(location_id));
revoke all on public.venues from public,anon,authenticated;
grant select on public.venues to anon,authenticated;

create or replace function public.admin_create_venue(
  p_location_id uuid,
  p_name text,
  p_address text default null,
  p_operating_days smallint[] default '{}'::smallint[],
  p_opens_at time without time zone default null,
  p_closes_at time without time zone default null,
  p_is_active boolean default false
) returns public.venues
language plpgsql security definer set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_days smallint[];
  v_venue public.venues;
  v_name text:=nullif(btrim(p_name),'');
  v_address text:=nullif(btrim(p_address),'');
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if not public.can_administer_location(p_location_id) then raise exception 'You are not assigned to this location'; end if;
  if v_name is null or char_length(v_name)<2 or char_length(v_name)>120 then raise exception 'Venue name must be between 2 and 120 characters'; end if;
  if v_address is not null and char_length(v_address)>255 then raise exception 'Venue address cannot exceed 255 characters'; end if;
  if exists(select 1 from unnest(coalesce(p_operating_days,'{}'::smallint[])) d where d<0 or d>6) then
    raise exception 'Operating days must use Sunday 0 through Saturday 6';
  end if;
  if (p_opens_at is null)<>(p_closes_at is null) or (p_opens_at is not null and p_opens_at>=p_closes_at) then
    raise exception 'Opening and closing times must both be set, with closing later than opening';
  end if;
  select coalesce(array_agg(distinct d order by d),'{}'::smallint[]) into v_days
  from unnest(coalesce(p_operating_days,'{}'::smallint[])) d;
  insert into public.venues(location_id,name,address,operating_days,opens_at,closes_at,is_active)
  values(p_location_id,v_name,v_address,v_days,p_opens_at,p_closes_at,coalesce(p_is_active,false))
  returning * into v_venue;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'venue.created','venue',v_venue.id::text,
    jsonb_build_object('location_id',v_venue.location_id,'name',v_venue.name,'operating_days',v_venue.operating_days,'opens_at',v_venue.opens_at,'closes_at',v_venue.closes_at,'is_active',v_venue.is_active));
  return v_venue;
exception when unique_violation then
  raise exception 'A venue with that name already exists at this location';
end;
$$;
revoke all on function public.admin_create_venue(uuid,text,text,smallint[],time without time zone,time without time zone,boolean) from public,anon;
grant execute on function public.admin_create_venue(uuid,text,text,smallint[],time without time zone,time without time zone,boolean) to authenticated;

create or replace function public.admin_update_venue(
  p_venue_id uuid,
  p_name text,
  p_address text default null,
  p_operating_days smallint[] default '{}'::smallint[],
  p_opens_at time without time zone default null,
  p_closes_at time without time zone default null,
  p_is_active boolean default false
) returns public.venues
language plpgsql security definer set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_venue public.venues;
  v_before jsonb;
  v_days smallint[];
  v_name text:=nullif(btrim(p_name),'');
  v_address text:=nullif(btrim(p_address),'');
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_venue from public.venues where id=p_venue_id for update;
  if not found then raise exception 'Venue not found'; end if;
  if not public.can_administer_location(v_venue.location_id) then raise exception 'You are not assigned to this location'; end if;
  if v_name is null or char_length(v_name)<2 or char_length(v_name)>120 then raise exception 'Venue name must be between 2 and 120 characters'; end if;
  if v_address is not null and char_length(v_address)>255 then raise exception 'Venue address cannot exceed 255 characters'; end if;
  if exists(select 1 from unnest(coalesce(p_operating_days,'{}'::smallint[])) d where d<0 or d>6) then
    raise exception 'Operating days must use Sunday 0 through Saturday 6';
  end if;
  if (p_opens_at is null)<>(p_closes_at is null) or (p_opens_at is not null and p_opens_at>=p_closes_at) then
    raise exception 'Opening and closing times must both be set, with closing later than opening';
  end if;
  select coalesce(array_agg(distinct d order by d),'{}'::smallint[]) into v_days
  from unnest(coalesce(p_operating_days,'{}'::smallint[])) d;
  v_before:=jsonb_build_object('name',v_venue.name,'address',v_venue.address,'operating_days',v_venue.operating_days,'opens_at',v_venue.opens_at,'closes_at',v_venue.closes_at,'is_active',v_venue.is_active);
  update public.venues
  set name=v_name,address=v_address,operating_days=v_days,opens_at=p_opens_at,closes_at=p_closes_at,is_active=coalesce(p_is_active,false)
  where id=p_venue_id returning * into v_venue;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data)
  values(v_actor,'venue.updated','venue',v_venue.id::text,v_before,
    jsonb_build_object('name',v_venue.name,'address',v_venue.address,'operating_days',v_venue.operating_days,'opens_at',v_venue.opens_at,'closes_at',v_venue.closes_at,'is_active',v_venue.is_active));
  return v_venue;
exception when unique_violation then
  raise exception 'A venue with that name already exists at this location';
end;
$$;
revoke all on function public.admin_update_venue(uuid,text,text,smallint[],time without time zone,time without time zone,boolean) from public,anon;
grant execute on function public.admin_update_venue(uuid,text,text,smallint[],time without time zone,time without time zone,boolean) to authenticated;

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

  if p_venue_id is not null then
    select v.* into v_venue from public.venues v
    join public.locations loc on loc.id=v.location_id
    where v.id=p_venue_id and v.is_active=true and loc.is_active=true;
    if not found then raise exception 'Choose an active venue at an active location'; end if;
    if v_venue.location_id<>v_location_id then raise exception 'The selected venue must belong to the season location'; end if;
    if p_scheduled_at is not null then
      v_local_scheduled:=p_scheduled_at at time zone 'Europe/London';
      v_day:=extract(dow from v_local_scheduled)::smallint;
      if cardinality(v_venue.operating_days)>0 and not (v_day=any(v_venue.operating_days)) then
        raise exception 'The selected venue is not operating on the scheduled day';
      end if;
      if v_venue.opens_at is not null and (v_local_scheduled::time<v_venue.opens_at or v_local_scheduled::time>=v_venue.closes_at) then
        raise exception 'The scheduled time is outside the selected venue operating hours';
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

create or replace function public.get_admin_contextual_fixtures(
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null
) returns table(
  id uuid,season_id uuid,season_name text,gameweek integer,fixture_number integer,
  home_team_id uuid,away_team_id uuid,home_team_name text,away_team_name text,
  venue_id uuid,venue_name text,scheduled_at timestamptz,status text,
  home_score integer,away_score integer,notes text
)
language plpgsql stable security definer set search_path=''
as $$
declare
  v_location uuid:=p_location_id;
  v_league uuid:=p_league_id;
  v_season uuid:=p_season_id;
  v_league_location uuid;
  v_season_league uuid;
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if v_season is not null then
    select s.league_id into v_season_league from public.seasons s where s.id=v_season;
    if v_season_league is null then raise exception 'Selected season was not found'; end if;
    if v_league is not null and v_league<>v_season_league then raise exception 'Season does not belong to selected league'; end if;
    v_league:=v_season_league;
  end if;
  if v_league is not null then
    select l.location_id into v_league_location from public.leagues l where l.id=v_league;
    if v_league_location is null then raise exception 'Selected league was not found'; end if;
    if v_location is not null and v_location<>v_league_location then raise exception 'League does not belong to selected location'; end if;
    v_location:=v_league_location;
  end if;
  perform public.assert_admin_location_context(v_location);
  return query
  select f.id,f.season_id,se.name,f.gameweek,f.fixture_number,f.home_team_id,f.away_team_id,
    ht.name,at.name,f.venue_id,venue.name,f.scheduled_at,f.status::text,r.home_score::integer,r.away_score::integer,f.notes
  from public.fixtures f
  join public.seasons se on se.id=f.season_id
  join public.leagues l on l.id=se.league_id
  join public.season_teams ht on ht.id=f.home_team_id
  join public.season_teams at on at.id=f.away_team_id
  left join public.venues venue on venue.id=f.venue_id
  left join public.fixture_results r on r.fixture_id=f.id
  where (v_location is null or l.location_id=v_location)
    and (v_league is null or l.id=v_league)
    and (v_season is null or se.id=v_season)
  order by f.scheduled_at desc nulls last,f.gameweek desc,f.fixture_number;
end;
$$;
revoke all on function public.get_admin_contextual_fixtures(uuid,uuid,uuid) from public,anon;
grant execute on function public.get_admin_contextual_fixtures(uuid,uuid,uuid) to authenticated;

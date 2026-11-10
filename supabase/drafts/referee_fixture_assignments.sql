-- Referee fixture appointments. Every change is append-only history; only active
-- assignments are considered current. One lead and one assistant may be appointed.
create table public.referee_fixture_assignments (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.fixtures(id) on delete restrict,
  referee_user_id uuid not null references auth.users(id) on delete restrict,
  assignment_role text not null check (assignment_role in ('lead','assistant')),
  assigned_by uuid not null references auth.users(id) on delete restrict,
  assigned_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users(id) on delete restrict,
  cancellation_reason text,
  constraint referee_assignment_cancellation_state check (
    (cancelled_at is null and cancelled_by is null and cancellation_reason is null)
    or
    (cancelled_at is not null and cancelled_by is not null
      and cancellation_reason is not null and length(btrim(cancellation_reason)) between 5 and 500)
  )
);
create unique index referee_fixture_one_active_role
  on public.referee_fixture_assignments(fixture_id,assignment_role)
  where cancelled_at is null;
create unique index referee_fixture_one_active_official
  on public.referee_fixture_assignments(fixture_id,referee_user_id)
  where cancelled_at is null;
create index referee_assignments_user_active
  on public.referee_fixture_assignments(referee_user_id,assigned_at desc)
  where cancelled_at is null;
create index referee_assignments_fixture_history
  on public.referee_fixture_assignments(fixture_id,assigned_at desc);

alter table public.referee_fixture_assignments enable row level security;
revoke all on public.referee_fixture_assignments from public,anon,authenticated;

create or replace function public.admin_assign_referee_to_fixture(
  p_fixture_id uuid,
  p_referee_user_id uuid,
  p_assignment_role text
)
returns public.referee_fixture_assignments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_fixture public.fixtures;
  v_assignment public.referee_fixture_assignments;
  v_location_id uuid;
  v_local_start timestamp;
  v_weekday integer;
  v_local_time text;
  v_availability jsonb;
  v_application public.referee_applications;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if p_assignment_role is null or p_assignment_role not in ('lead','assistant') then
    raise exception 'Assignment role must be lead or assistant';
  end if;

  select * into v_fixture
  from public.fixtures
  where id=p_fixture_id
  for update;
  if not found then raise exception 'Fixture not found'; end if;
  if v_fixture.status <> 'scheduled' or v_fixture.scheduled_at is null
     or v_fixture.scheduled_at <= now() then
    raise exception 'Only future scheduled fixtures can receive referee appointments';
  end if;

  select coalesce(v_fixture.venue_id,l.location_id)
    into v_location_id
  from public.seasons s
  join public.leagues l on l.id=s.league_id
  where s.id=v_fixture.season_id;
  if v_location_id is null then raise exception 'Fixture location could not be resolved'; end if;
  if not public.can_administer_location(v_location_id) then
    raise exception 'You are not assigned to this fixture location';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_referee_user_id::text,0)
  );

  select application.* into v_application
  from public.referee_memberships membership
  join public.referee_applications application on application.id=membership.application_id
  where membership.user_id=p_referee_user_id
    and membership.status='active'
    and v_location_id=any(application.preferred_location_ids);
  if not found then
    raise exception 'Choose an active referee who has selected this fixture location';
  end if;

  v_local_start:=v_fixture.scheduled_at at time zone 'Europe/London';
  v_weekday:=extract(isodow from v_local_start)::integer;
  v_local_time:=to_char(v_local_start,'HH24:MI');
  v_availability:=v_application.availability;
  if not exists (
    select 1
    from jsonb_array_elements(v_availability) slot
    where (slot->>'weekday')::integer=v_weekday
      and v_local_time >= slot->>'start_time'
      and v_local_time < slot->>'end_time'
  ) then
    raise exception 'The referee has not declared availability for this fixture time';
  end if;

  -- Until fixture duration is configured, prevent double-booking at the same
  -- kickoff instant. This is deliberately conservative and does not guess duration.
  if exists (
    select 1
    from public.referee_fixture_assignments existing
    join public.fixtures other_fixture on other_fixture.id=existing.fixture_id
    where existing.referee_user_id=p_referee_user_id
      and existing.cancelled_at is null
      and other_fixture.scheduled_at=v_fixture.scheduled_at
      and other_fixture.status in ('scheduled','in_progress')
      and other_fixture.id<>v_fixture.id
  ) then
    raise exception 'This referee already has an appointment at the same kickoff time';
  end if;

  insert into public.referee_fixture_assignments(
    fixture_id,referee_user_id,assignment_role,assigned_by
  ) values(p_fixture_id,p_referee_user_id,p_assignment_role,v_actor)
  returning * into v_assignment;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason)
  values(v_actor,'referee.fixture_assigned','referee_fixture_assignment',v_assignment.id::text,
    jsonb_build_object('fixture_id',p_fixture_id,'referee_user_id',p_referee_user_id,
      'assignment_role',p_assignment_role,'location_id',v_location_id),
    'Referee appointment created by location administrator');

  perform public.enqueue_notification_event(
    p_referee_user_id,
    'referee.fixture_assigned',
    jsonb_build_object('assignment_id',v_assignment.id,'fixture_id',p_fixture_id,
      'assignment_role',p_assignment_role,'scheduled_at',v_fixture.scheduled_at,
      'location_id',v_location_id)
  );
  return v_assignment;
end;
$$;
revoke all on function public.admin_assign_referee_to_fixture(uuid,uuid,text) from public,anon;
grant execute on function public.admin_assign_referee_to_fixture(uuid,uuid,text) to authenticated;

create or replace function public.admin_cancel_referee_fixture_assignment(
  p_assignment_id uuid,
  p_reason text
)
returns public.referee_fixture_assignments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_assignment public.referee_fixture_assignments;
  v_fixture public.fixtures;
  v_location_id uuid;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if length(btrim(coalesce(p_reason,''))) not between 5 and 500 then
    raise exception 'A cancellation reason of 5 to 500 characters is required';
  end if;
  select assignment,fixture
    into v_assignment,v_fixture
  from public.referee_fixture_assignments assignment
  join public.fixtures fixture on fixture.id=assignment.fixture_id
  where assignment.id=p_assignment_id
  for update of assignment;
  if not found then raise exception 'Referee appointment not found'; end if;
  if v_assignment.cancelled_at is not null then
    raise exception 'This referee appointment has already been cancelled';
  end if;
  select coalesce(v_fixture.venue_id,league.location_id) into v_location_id
  from public.seasons season
  join public.leagues league on league.id=season.league_id
  where season.id=v_fixture.season_id;
  if not public.can_administer_location(v_location_id) then
    raise exception 'You are not assigned to this fixture location';
  end if;

  update public.referee_fixture_assignments
  set cancelled_at=now(),cancelled_by=v_actor,cancellation_reason=btrim(p_reason)
  where id=p_assignment_id
  returning * into v_assignment;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason)
  values(v_actor,'referee.fixture_assignment_cancelled','referee_fixture_assignment',v_assignment.id::text,
    jsonb_build_object('cancelled_at',null),
    jsonb_build_object('fixture_id',v_assignment.fixture_id,'referee_user_id',v_assignment.referee_user_id),
    btrim(p_reason));

  perform public.enqueue_notification_event(
    v_assignment.referee_user_id,'referee.fixture_assignment_cancelled',
    jsonb_build_object('assignment_id',v_assignment.id,'fixture_id',v_assignment.fixture_id,
      'reason',btrim(p_reason))
  );
  return v_assignment;
end;
$$;
revoke all on function public.admin_cancel_referee_fixture_assignment(uuid,text) from public,anon;
grant execute on function public.admin_cancel_referee_fixture_assignment(uuid,text) to authenticated;

create or replace function public.get_my_referee_assignments()
returns table(
  assignment_id uuid,
  fixture_id uuid,
  assignment_role text,
  assigned_at timestamptz,
  scheduled_at timestamptz,
  gameweek integer,
  fixture_number integer,
  home_team_name text,
  away_team_name text,
  venue_name text,
  fixture_status public.fixture_status
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.referee_memberships where user_id=v_user and status='active') then
    raise exception 'An active referee membership is required';
  end if;
  return query
  select assignment.id,fixture.id,assignment.assignment_role,assignment.assigned_at,
    fixture.scheduled_at,fixture.gameweek,fixture.fixture_number,home_team.name,away_team.name,
    venue.name,fixture.status
  from public.referee_fixture_assignments assignment
  join public.fixtures fixture on fixture.id=assignment.fixture_id
  join public.season_teams home_team on home_team.id=fixture.home_team_id
  join public.season_teams away_team on away_team.id=fixture.away_team_id
  left join public.locations venue on venue.id=fixture.venue_id
  where assignment.referee_user_id=v_user
    and assignment.cancelled_at is null
  order by fixture.scheduled_at,fixture.gameweek,fixture.fixture_number;
end;
$$;
revoke all on function public.get_my_referee_assignments() from public,anon;
grant execute on function public.get_my_referee_assignments() to authenticated;

create or replace function public.admin_list_referee_appointments(
  p_location_id uuid default null,
  p_include_cancelled boolean default false
)
returns table(
  assignment_id uuid,
  fixture_id uuid,
  referee_user_id uuid,
  referee_name text,
  referee_email text,
  assignment_role text,
  assigned_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  scheduled_at timestamptz,
  gameweek integer,
  fixture_number integer,
  location_id uuid,
  location_name text,
  home_team_name text,
  away_team_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  return query
  select assignment.id,fixture.id,assignment.referee_user_id,
    coalesce(player.full_name,'Open Play referee'),account.email::text,
    assignment.assignment_role,assignment.assigned_at,assignment.cancelled_at,
    assignment.cancellation_reason,fixture.scheduled_at,fixture.gameweek,
    fixture.fixture_number,location.id,location.name,home_team.name,away_team.name
  from public.referee_fixture_assignments assignment
  join public.fixtures fixture on fixture.id=assignment.fixture_id
  join public.seasons season on season.id=fixture.season_id
  join public.leagues league on league.id=season.league_id
  join public.locations location on location.id=coalesce(fixture.venue_id,league.location_id)
  join auth.users account on account.id=assignment.referee_user_id
  left join public.players player on player.user_id=assignment.referee_user_id
  join public.season_teams home_team on home_team.id=fixture.home_team_id
  join public.season_teams away_team on away_team.id=fixture.away_team_id
  where (p_location_id is null or location.id=p_location_id)
    and public.can_administer_location(location.id)
    and (p_include_cancelled or assignment.cancelled_at is null)
  order by fixture.scheduled_at,fixture.gameweek,fixture.fixture_number,assignment.assignment_role;
end;
$$;
revoke all on function public.admin_list_referee_appointments(uuid,boolean) from public,anon;
grant execute on function public.admin_list_referee_appointments(uuid,boolean) to authenticated;


create or replace function public.admin_list_referee_assignment_fixtures()
returns table(
  fixture_id uuid,
  scheduled_at timestamptz,
  gameweek integer,
  fixture_number integer,
  home_team_name text,
  away_team_name text,
  location_id uuid,
  location_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  return query
  select fixture.id,fixture.scheduled_at,fixture.gameweek,fixture.fixture_number,
    home_team.name,away_team.name,location.id,location.name
  from public.fixtures fixture
  join public.seasons season on season.id=fixture.season_id
  join public.leagues league on league.id=season.league_id
  join public.locations location on location.id=coalesce(fixture.venue_id,league.location_id)
  join public.season_teams home_team on home_team.id=fixture.home_team_id
  join public.season_teams away_team on away_team.id=fixture.away_team_id
  where fixture.status='scheduled'
    and fixture.scheduled_at>now()
    and public.can_administer_location(location.id)
  order by fixture.scheduled_at,fixture.gameweek,fixture.fixture_number;
end;
$$;
revoke all on function public.admin_list_referee_assignment_fixtures() from public,anon;
grant execute on function public.admin_list_referee_assignment_fixtures() to authenticated;

create or replace function public.admin_list_referee_assignment_candidates(p_location_id uuid default null)
returns table(
  referee_user_id uuid,
  referee_name text,
  referee_email text,
  preferred_location_ids uuid[],
  availability jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_location_id is not null and not public.can_administer_location(p_location_id) then
    raise exception 'You are not assigned to this referee location';
  end if;
  return query
  select membership.user_id,coalesce(player.full_name,'Open Play referee'),
    account.email::text,application.preferred_location_ids,application.availability
  from public.referee_memberships membership
  join public.referee_applications application on application.id=membership.application_id
  join auth.users account on account.id=membership.user_id
  left join public.players player on player.user_id=membership.user_id
  where membership.status='active'
    and (p_location_id is null or p_location_id=any(application.preferred_location_ids))
    and (
      p_location_id is not null
      or exists(select 1 from unnest(application.preferred_location_ids) preferred(location_id)
        where public.can_administer_location(preferred.location_id))
    )
  order by player.full_name,account.email;
end;
$$;
revoke all on function public.admin_list_referee_assignment_candidates(uuid) from public,anon;
grant execute on function public.admin_list_referee_assignment_candidates(uuid) to authenticated;

-- Manual, audited season recruitment activation. No scheduled jobs or future memberships.
alter table public.seasons
  add column if not exists recruitment_status text not null default 'closed'
    check (recruitment_status in ('closed','open','closed_after_opening')),
  add column if not exists recruitment_opened_at timestamptz,
  add column if not exists recruitment_opened_by uuid references auth.users(id) on delete set null,
  add column if not exists recruitment_closed_at timestamptz,
  add column if not exists recruitment_closed_by uuid references auth.users(id) on delete set null;

-- Preserve existing live registration windows while closing every other season.
update public.seasons
set recruitment_status=case when status='registration_open' then 'open' else 'closed' end
where recruitment_status='closed';

-- Keep the existing location-scoped Admin setup payload in sync with the
-- persisted recruitment state so the dashboard never guesses from dates.
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
  if exists(
    select 1 from public.user_roles
    where user_id=v_actor and role='league_admin'
  ) and not exists(
    select 1 from public.location_admin_assignments where user_id=v_actor
  ) then
    raise exception 'No locations have been assigned to this administrator';
  end if;

  return jsonb_build_object(
    'locations',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',l.id,'name',l.name,'town',l.town,'region',l.region,
        'address',l.address,'is_active',l.is_active
      ) order by l.name)
      from public.locations l where public.can_administer_location(l.id)
    ),'[]'::jsonb),
    'leagues',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',l.id,'location_id',l.location_id,'location_name',loc.name,
        'name',l.name,'format',l.format,'description',l.description,
        'is_published',l.is_published
      ) order by loc.name,l.name)
      from public.leagues l join public.locations loc on loc.id=l.location_id
      where public.can_administer_location(l.location_id)
    ),'[]'::jsonb),
    'seasons',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',s.id,'league_id',s.league_id,'league_name',l.name,
        'location_name',loc.name,'name',s.name,'season_number',s.season_number,
        'starts_on',s.starts_on,'ends_on',s.ends_on,
        'registration_opens_at',s.registration_opens_at,
        'registration_closes_at',s.registration_closes_at,
        'status',s.status,'recruitment_status',s.recruitment_status,
        'recruitment_opened_at',s.recruitment_opened_at,
        'recruitment_closed_at',s.recruitment_closed_at,
        'is_public',s.is_public
      ) order by loc.name,l.name,s.created_at desc)
      from public.seasons s
      join public.leagues l on l.id=s.league_id
      join public.locations loc on loc.id=l.location_id
      where public.can_administer_location(l.location_id)
    ),'[]'::jsonb),
    'season_teams',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',st.id,'season_id',st.season_id,'season_name',s.name,
        'league_name',l.name,'location_name',loc.name,'name',st.name,
        'registration_status',st.registration_status,
        'primary_colour',st.primary_colour,'secondary_colour',st.secondary_colour,
        'member_count',(select count(*) from public.team_memberships tm
          where tm.season_team_id=st.id and tm.status='active'),
        'captain_name',(select p.full_name from public.team_memberships tm
          join public.players p on p.user_id=tm.user_id
          where tm.season_team_id=st.id and tm.status='active'
            and tm.is_captain limit 1)
      ) order by loc.name,s.name,st.name)
      from public.season_teams st
      join public.seasons s on s.id=st.season_id
      join public.leagues l on l.id=s.league_id
      join public.locations loc on loc.id=l.location_id
      where public.can_administer_location(l.location_id)
    ),'[]'::jsonb),
    'registered_players',coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id',p.user_id,'full_name',p.full_name,'email',p.email
      ) order by p.full_name)
      from public.players p
      where p.registration_status='registered' and p.is_banned=false
        and exists(
          select 1 from public.team_memberships tm
          join public.season_teams st on st.id=tm.season_team_id
          join public.seasons s on s.id=st.season_id
          join public.leagues l on l.id=s.league_id
          where tm.user_id=p.user_id and tm.status='active'
            and public.can_administer_location(l.location_id)
        )
    ),'[]'::jsonb),
    'fixtures',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',f.id,'season_id',f.season_id,'season_name',s.name,
        'gameweek',f.gameweek,'fixture_number',f.fixture_number,
        'home_team_id',f.home_team_id,'away_team_id',f.away_team_id,
        'home_team_name',ht.name,'away_team_name',at.name,
        'venue_id',f.venue_id,'venue_name',venue.name,
        'scheduled_at',f.scheduled_at,'status',f.status,
        'home_score',r.home_score,'away_score',r.away_score,'notes',f.notes
      ) order by f.scheduled_at desc nulls last,f.gameweek desc,f.fixture_number)
      from public.fixtures f
      join public.seasons s on s.id=f.season_id
      join public.leagues l on l.id=s.league_id
      join public.season_teams ht on ht.id=f.home_team_id
      join public.season_teams at on at.id=f.away_team_id
      left join public.locations venue on venue.id=f.venue_id
      left join public.fixture_results r on r.fixture_id=f.id
      where public.can_administer_location(l.location_id)
    ),'[]'::jsonb)
  );
end;
$$;
revoke all on function public.get_admin_competition_setup() from public,anon;
grant execute on function public.get_admin_competition_setup() to authenticated;


alter table public.seasons
  drop constraint if exists seasons_recruitment_open_actor_check;
alter table public.seasons
  add constraint seasons_recruitment_open_actor_check
  check ((recruitment_opened_at is null)=(recruitment_opened_by is null));

create or replace function public.enforce_season_recruitment_open()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_season_id uuid;
  v_state text;
  v_competition_status text;
begin
  if tg_table_name='season_teams' then
    if new.registration_status::text<>'pending' then return new; end if;
    v_season_id:=new.season_id;
  elsif tg_table_name='season_registrations' then
    if new.status::text<>'pending' then return new; end if;
    v_season_id:=new.season_id;
  else
    if new.status::text not in ('pending','active') then return new; end if;
    select s.recruitment_status,s.status::text
      into v_state,v_competition_status
    from public.season_teams st
    join public.seasons s on s.id=st.season_id
    where st.id=new.season_team_id;
    if not found then return new; end if;
    if v_competition_status='draft' then
      raise exception 'Future season memberships cannot be created before Admin opens recruitment'
        using errcode='55000';
    end if;
    return new;
  end if;

  select s.recruitment_status,s.status::text
    into v_state,v_competition_status
  from public.seasons s where s.id=v_season_id;

  if not found or v_state is distinct from 'open'
     or v_competition_status is distinct from 'registration_open' then
    raise exception 'Season recruitment is closed. Admin must activate this season after the previous season has finished.'
      using errcode='55000';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_season_recruitment_open() from public,anon,authenticated;

drop trigger if exists enforce_season_team_recruitment_open on public.season_teams;
create trigger enforce_season_team_recruitment_open
before insert or update of registration_status,season_id on public.season_teams
for each row execute function public.enforce_season_recruitment_open();

drop trigger if exists enforce_season_player_recruitment_open on public.season_registrations;
create trigger enforce_season_player_recruitment_open
before insert or update of status,season_id on public.season_registrations
for each row execute function public.enforce_season_recruitment_open();

drop trigger if exists enforce_future_season_membership_recruitment_open on public.team_memberships;
create trigger enforce_future_season_membership_recruitment_open
before insert or update of status,season_team_id on public.team_memberships
for each row execute function public.enforce_season_recruitment_open();

create or replace function public.guard_season_recruitment_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status::text='draft' and new.status::text='registration_open'
     and (new.recruitment_status<>'open'
       or new.recruitment_opened_at is null
       or new.recruitment_opened_by is null) then
    raise exception 'Use the audited manual recruitment activation action after the previous season has finished'
      using errcode='55000';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_season_recruitment_transition() from public,anon,authenticated;
drop trigger if exists guard_season_recruitment_transition on public.seasons;
create trigger guard_season_recruitment_transition
before update of status on public.seasons
for each row execute function public.guard_season_recruitment_transition();

create or replace function public.admin_publish_upcoming_season(
  p_season_id uuid,
  p_reason text
)
returns public.seasons
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_before public.seasons;
  v_location_id uuid;
  v_after public.seasons;
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_reason is null or length(btrim(p_reason))<5 or length(btrim(p_reason))>500 then
    raise exception 'Enter a reason between 5 and 500 characters' using errcode='22023';
  end if;

  select s.* into v_before
  from public.seasons s where s.id=p_season_id for update;
  if not found then raise exception 'Season not found' using errcode='P0002'; end if;
  select l.location_id into v_location_id
  from public.leagues l where l.id=v_before.league_id;
  if not public.can_administer_location(v_location_id) then
    raise exception 'Location administrator permission required' using errcode='42501';
  end if;
  if v_before.status::text<>'draft' or v_before.recruitment_status<>'closed' then
    raise exception 'Only a closed upcoming season can be published as coming soon' using errcode='55000';
  end if;

  update public.seasons
  set is_public=true,updated_at=now()
  where id=p_season_id returning * into v_after;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'season.upcoming.published','season',p_season_id::text,btrim(p_reason),
    jsonb_build_object('is_public',v_before.is_public,'recruitment_status',v_before.recruitment_status),
    jsonb_build_object('is_public',v_after.is_public,'recruitment_status',v_after.recruitment_status));

  return v_after;
end;
$$;
revoke all on function public.admin_publish_upcoming_season(uuid,text) from public,anon;
grant execute on function public.admin_publish_upcoming_season(uuid,text) to authenticated;

create or replace function public.admin_open_season_recruitment(
  p_season_id uuid,
  p_reason text
)
returns public.seasons
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_season public.seasons;
  v_previous public.seasons;
  v_location_id uuid;
  v_last_fixture public.fixtures;
  v_result_exists boolean;
  v_opened public.seasons;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;
  if p_season_id is null then
    raise exception 'A season is required' using errcode='22023';
  end if;
  if p_reason is null or length(btrim(p_reason))<5 or length(btrim(p_reason))>500 then
    raise exception 'Enter a reason between 5 and 500 characters' using errcode='22023';
  end if;

  select s.* into v_season
  from public.seasons s
  where s.id=p_season_id
  for update;

  if not found then raise exception 'Season not found' using errcode='P0002'; end if;
  select l.location_id into v_location_id
  from public.leagues l where l.id=v_season.league_id;
  if not public.can_administer_location(v_location_id) then
    raise exception 'Location administrator permission required' using errcode='42501';
  end if;
  if v_season.status::text<>'draft' or v_season.recruitment_status<>'closed' then
    raise exception 'Only a closed upcoming season can be activated for recruitment' using errcode='55000';
  end if;

  select prev.* into v_previous
  from public.seasons prev
  where prev.league_id=v_season.league_id
    and prev.id<>v_season.id
    and (
      (v_season.season_number is not null and prev.season_number is not null
        and prev.season_number<v_season.season_number)
      or
      (v_season.season_number is null and v_season.starts_on is not null
        and prev.starts_on is not null and prev.starts_on<v_season.starts_on)
    )
  order by
    case when v_season.season_number is not null and prev.season_number is not null then 0 else 1 end,
    prev.season_number desc nulls last,
    prev.starts_on desc nulls last,
    prev.created_at desc
  limit 1;

  if found then
    select f.* into v_last_fixture
    from public.fixtures f
    where f.season_id=v_previous.id
    order by f.scheduled_at desc nulls last,f.gameweek desc,f.fixture_number desc,f.created_at desc
    limit 1;

    if not found or v_last_fixture.status::text<>'completed' then
      raise exception 'The previous season final fixture has not been completed' using errcode='55000';
    end if;

    select exists(select 1 from public.fixture_results r where r.fixture_id=v_last_fixture.id)
      into v_result_exists;
    if not v_result_exists then
      raise exception 'The previous season final fixture has no published result' using errcode='55000';
    end if;
  end if;

  update public.seasons
  set status='registration_open',
      is_public=true,
      recruitment_status='open',
      recruitment_opened_at=now(),
      recruitment_opened_by=v_actor,
      recruitment_closed_at=null,
      recruitment_closed_by=null,
      updated_at=now()
  where id=p_season_id
  returning * into v_opened;

  insert into public.audit_log(
    actor_user_id,action,entity_type,entity_id,reason,before_data,after_data
  ) values (
    v_actor,'season.recruitment.opened','season',p_season_id::text,btrim(p_reason),
    jsonb_build_object('competition_status',v_season.status,'recruitment_status',v_season.recruitment_status),
    jsonb_build_object('competition_status',v_opened.status,'recruitment_status',v_opened.recruitment_status,
      'previous_season_id',v_previous.id,'previous_final_fixture_id',v_last_fixture.id)
  );

  return v_opened;
end;
$$;
revoke all on function public.admin_open_season_recruitment(uuid,text) from public,anon;
grant execute on function public.admin_open_season_recruitment(uuid,text) to authenticated;

create or replace function public.admin_close_season_recruitment(
  p_season_id uuid,
  p_reason text
)
returns public.seasons
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_location_id uuid;
  v_before public.seasons;
  v_after public.seasons;
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_reason is null or length(btrim(p_reason))<5 or length(btrim(p_reason))>500 then
    raise exception 'Enter a reason between 5 and 500 characters' using errcode='22023';
  end if;

  select s.* into v_before
  from public.seasons s where s.id=p_season_id for update;
  if not found then raise exception 'Season not found' using errcode='P0002'; end if;
  select l.location_id into v_location_id
  from public.leagues l where l.id=v_before.league_id;
  if not public.can_administer_location(v_location_id) then
    raise exception 'Location administrator permission required' using errcode='42501';
  end if;
  if v_before.recruitment_status<>'open' then
    raise exception 'Season recruitment is not open' using errcode='55000';
  end if;

  update public.seasons
  set recruitment_status='closed_after_opening',
      recruitment_closed_at=now(),
      recruitment_closed_by=v_actor,
      updated_at=now()
  where id=p_season_id returning * into v_after;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'season.recruitment.closed','season',p_season_id::text,btrim(p_reason),
    jsonb_build_object('recruitment_status',v_before.recruitment_status),
    jsonb_build_object('recruitment_status',v_after.recruitment_status));

  return v_after;
end;
$$;
revoke all on function public.admin_close_season_recruitment(uuid,text) from public,anon;
grant execute on function public.admin_close_season_recruitment(uuid,text) to authenticated;


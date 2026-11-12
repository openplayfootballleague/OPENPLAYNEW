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
  else
    if new.status::text<>'pending' then return new; end if;
    v_season_id:=new.season_id;
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

create or replace function public.guard_season_recruitment_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $
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
$;
revoke all on function public.guard_season_recruitment_transition() from public,anon,authenticated;
drop trigger if exists guard_season_recruitment_transition on public.seasons;
create trigger guard_season_recruitment_transition
before update of status on public.seasons
for each row execute function public.guard_season_recruitment_transition();

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

  select s,l.location_id
    into v_season,v_location_id
  from public.seasons s
  join public.leagues l on l.id=s.league_id
  where s.id=p_season_id
  for update of s;

  if not found then raise exception 'Season not found' using errcode='P0002'; end if;
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

  select s,l.location_id into v_before,v_location_id
  from public.seasons s join public.leagues l on l.id=s.league_id
  where s.id=p_season_id for update of s;
  if not found then raise exception 'Season not found' using errcode='P0002'; end if;
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

create or replace function public.get_public_season_recruitment_status(p_season_id uuid)
returns table(
  season_id uuid,
  season_name text,
  competition_status text,
  recruitment_status text,
  starts_on date
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id,s.name,s.status::text,s.recruitment_status,s.starts_on
  from public.seasons s
  join public.leagues l on l.id=s.league_id
  join public.locations loc on loc.id=l.location_id
  where s.id=p_season_id and s.is_public is true and loc.is_active is true
  limit 1;
$$;
revoke all on function public.get_public_season_recruitment_status(uuid) from public;
grant execute on function public.get_public_season_recruitment_status(uuid) to anon,authenticated;

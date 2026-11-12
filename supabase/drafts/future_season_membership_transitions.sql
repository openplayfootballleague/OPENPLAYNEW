-- Future-season memberships are approved separately from current membership.
-- They remain non-active until every fixture in the previous location season has
-- a completed, confirmed result. This keeps future registration from granting
-- premature match-sheet, captain or payment permissions.

alter table public.team_memberships
  add column if not exists future_approved_at timestamptz,
  add column if not exists activation_after_season_id uuid references public.seasons(id) on delete restrict,
  add column if not exists future_activated_at timestamptz,
  add column if not exists future_conflict_reason text;

alter table public.team_memberships
  drop constraint if exists team_memberships_future_activation_fields_check;

alter table public.team_memberships
  add constraint team_memberships_future_activation_fields_check
  check (
    (future_approved_at is null and activation_after_season_id is null and future_activated_at is null)
    or
    (future_approved_at is not null and activation_after_season_id is not null)
  );

create index if not exists team_memberships_future_activation_idx
  on public.team_memberships(activation_after_season_id, user_id)
  where future_approved_at is not null and future_activated_at is null and status='pending';

create unique index if not exists team_memberships_one_approved_captain_per_team_idx
  on public.team_memberships(season_team_id)
  where is_captain=true and (status='active' or future_approved_at is not null);

create or replace function public.is_season_final_gameweek_confirmed(p_season_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_status public.season_status;
  v_has_fixtures boolean;
begin
  select s.status into v_status
  from public.seasons s
  where s.id=p_season_id;

  if not found then
    return false;
  end if;

  select exists(select 1 from public.fixtures f where f.season_id=p_season_id)
  into v_has_fixtures;

  if not v_has_fixtures then
    return v_status in ('completed','archived');
  end if;

  return not exists(
    select 1
    from public.fixtures f
    left join public.fixture_results r on r.fixture_id=f.id
    where f.season_id=p_season_id
      and f.status<>'cancelled'
      and (f.status<>'completed' or r.fixture_id is null or r.confirmed_at is null)
  );
end;
$$;

revoke all on function public.is_season_final_gameweek_confirmed(uuid) from public,anon,authenticated;

create or replace function public.get_membership_transition_barrier(
  p_location_id uuid,
  p_target_season_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_target public.seasons;
  v_barrier uuid;
begin
  select * into v_target
  from public.seasons s
  where s.id=p_target_season_id;

  if not found then
    raise exception 'Target season was not found';
  end if;

  select s.id into v_barrier
  from public.seasons s
  join public.leagues l on l.id=s.league_id
  where l.location_id=p_location_id
    and s.id<>p_target_season_id
    and s.status<>'draft'
    and (
      (v_target.starts_on is not null
        and ((s.starts_on is not null and s.starts_on<v_target.starts_on)
          or (s.starts_on is null and s.created_at<v_target.created_at)))
      or
      (v_target.starts_on is null and s.created_at<v_target.created_at)
    )
    and not public.is_season_final_gameweek_confirmed(s.id)
  order by s.starts_on desc nulls last,s.season_number desc nulls last,s.created_at desc
  limit 1;

  return v_barrier;
end;
$$;

revoke all on function public.get_membership_transition_barrier(uuid,uuid) from public,anon,authenticated;

create or replace function public.finalize_previous_location_memberships(
  p_user_id uuid,p_location_id uuid,p_target_season_id uuid,p_actor uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_changed integer:=0;
  v_previous_transition_flag text;
begin
  v_previous_transition_flag:=current_setting('app.future_membership_transition',true);
  perform set_config('app.future_membership_transition','1',true);

  with transitioned as (
    update public.team_memberships tm
    set status='left',left_at=coalesce(tm.left_at,now()),
        joined_at=coalesce(tm.joined_at,tm.created_at),updated_at=now()
    from public.season_teams st
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where tm.season_team_id=st.id and tm.user_id=p_user_id and tm.status='active'
      and l.location_id=p_location_id and s.id<>p_target_season_id
      and s.starts_on<=(select target_season.starts_on from public.seasons target_season where target_season.id=p_target_season_id)
      and public.is_season_final_gameweek_confirmed(s.id)
    returning tm.id,tm.season_team_id,tm.user_id
  )
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  select coalesce(p_actor,auth.uid()),'team.membership.season_transitioned','team_membership',
    transitioned.id::text,'Previous location season completed with confirmed results',
    jsonb_build_object('status','active'),
    jsonb_build_object('status','left','season_team_id',transitioned.season_team_id)
  from transitioned;

  get diagnostics v_changed=row_count;
  perform set_config('app.future_membership_transition',coalesce(v_previous_transition_flag,'0'),true);
  return v_changed;
end;
$$;

revoke all on function public.finalize_previous_location_memberships(uuid,uuid,uuid,uuid) from public,anon,authenticated;

create or replace function public.enforce_one_active_club_per_player_per_location()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_location_id uuid;
  v_league_id uuid;
  v_club_id uuid;
  v_target_season_id uuid;
  v_latest_source_membership_id uuid;
  v_latest_source_team_id uuid;
  v_latest_source_season_id uuid;
  v_has_active_same_club boolean:=false;
  v_transfer_request public.player_transfer_requests;
begin
  if tg_op='UPDATE' and new.season_team_id is distinct from old.season_team_id then
    raise exception 'Membership history cannot be moved between clubs; use the player transfer workflow';
  end if;

  if new.status<>'active' then
    return new;
  end if;

  select l.location_id,s.league_id,st.team_id,s.id
    into v_location_id,v_league_id,v_club_id,v_target_season_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=new.season_team_id;

  if v_location_id is null then
    raise exception 'Membership team must belong to a location';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.user_id::text||':'||v_location_id::text,0)
  );

  select exists(
    select 1
    from public.team_memberships active_membership
    join public.season_teams active_team on active_team.id=active_membership.season_team_id
    join public.seasons active_season on active_season.id=active_team.season_id
    join public.leagues active_league on active_league.id=active_season.league_id
    where active_membership.user_id=new.user_id
      and active_membership.status='active'
      and active_league.location_id=v_location_id
      and active_team.team_id=v_club_id
      and active_membership.id is distinct from new.id
  ) into v_has_active_same_club;

  if exists(
    select 1
    from public.team_memberships active_membership
    join public.season_teams active_team on active_team.id=active_membership.season_team_id
    join public.seasons active_season on active_season.id=active_team.season_id
    join public.leagues active_league on active_league.id=active_season.league_id
    where active_membership.user_id=new.user_id
      and active_membership.status='active'
      and active_league.location_id=v_location_id
      and active_team.team_id is distinct from v_club_id
      and active_membership.id is distinct from new.id
  ) then
    raise exception 'You must leave your existing club before joining another club in the same area';
  end if;

  select source_membership.id,source_team.team_id,source_season.id
    into v_latest_source_membership_id,v_latest_source_team_id,v_latest_source_season_id
  from public.team_memberships source_membership
  join public.season_teams source_team on source_team.id=source_membership.season_team_id
  join public.seasons source_season on source_season.id=source_team.season_id
  join public.leagues source_league on source_league.id=source_season.league_id
  where source_membership.user_id=new.user_id
    and source_membership.status='left'
    and source_membership.voluntarily_left_at is not null
    and source_league.location_id=v_location_id
  order by source_membership.voluntarily_left_at desc
  limit 1;

  if new.transfer_request_id is not null then
    select * into v_transfer_request
    from public.player_transfer_requests r
    where r.id=new.transfer_request_id
      and r.user_id=new.user_id
      and r.league_id=v_league_id
      and r.destination_season_team_id=new.season_team_id
      and r.source_membership_id=v_latest_source_membership_id
      and r.status='approved';

    if not found then
      raise exception 'A transfer-linked membership requires the latest matching approved transfer request';
    end if;
  elsif new.future_approved_at is null
    and v_latest_source_team_id is not null
    and v_latest_source_team_id is distinct from v_club_id
    and v_latest_source_season_id=v_target_season_id
    and not v_has_active_same_club then
    raise exception 'A player who voluntarily left a different club must join through an approved transfer request';
  end if;

  if exists(
    select 1
    from public.player_transfer_requests r
    where r.user_id=new.user_id
      and r.league_id=v_league_id
      and r.status='pending'
  ) then
    raise exception 'Resolve or cancel pending transfer requests before activating another club membership';
  end if;

  return new;
end;
$$;

drop trigger if exists team_memberships_one_active_club_per_league on public.team_memberships;
create trigger team_memberships_one_active_club_per_location
before insert or update of status,season_team_id,user_id
on public.team_memberships
for each row
execute function public.enforce_one_active_club_per_player_per_location();

revoke all on function public.enforce_one_active_club_per_player_per_location() from public,anon,authenticated;

create or replace function public.enforce_location_season_membership_rules()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_location_id uuid;
  v_season_id uuid;
begin
  if new.status<>'active' and new.future_approved_at is null then
    return new;
  end if;

  select l.location_id,s.id
    into v_location_id,v_season_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=new.season_team_id;

  if v_location_id is null then
    raise exception 'Membership team must belong to a location';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.user_id::text||':'||v_location_id::text,0)
  );

  if exists(
    select 1
    from public.team_memberships other_membership
    join public.season_teams other_team on other_team.id=other_membership.season_team_id
    join public.seasons other_season on other_season.id=other_team.season_id
    join public.leagues other_league on other_league.id=other_season.league_id
    where other_membership.user_id=new.user_id
      and other_league.location_id=v_location_id
      and other_season.id=v_season_id
      and other_team.team_id is distinct from (
        select st.team_id from public.season_teams st where st.id=new.season_team_id
      )
      and (
        other_membership.status='active'
        or other_membership.future_approved_at is not null
      )
      and other_membership.id is distinct from new.id
  ) then
    raise exception 'You can only join one club in the same area for a season. Leave your existing club first.';
  end if;

  if new.is_captain and exists(
    select 1
    from public.team_memberships other_membership
    join public.season_teams other_team on other_team.id=other_membership.season_team_id
    join public.seasons other_season on other_season.id=other_team.season_id
    join public.leagues other_league on other_league.id=other_season.league_id
    where other_membership.user_id=new.user_id
      and other_membership.is_captain=true
      and other_league.location_id=v_location_id
      and other_season.id=v_season_id
      and (
        other_membership.status='active'
        or other_membership.future_approved_at is not null
      )
      and other_membership.id is distinct from new.id
  ) then
    raise exception 'You can only hold one captaincy in the same area for a season';
  end if;

  return new;
end;
$$;

drop trigger if exists team_memberships_location_season_rules on public.team_memberships;
create trigger team_memberships_location_season_rules
before insert or update of status,season_team_id,user_id,is_captain,future_approved_at
on public.team_memberships
for each row
execute function public.enforce_location_season_membership_rules();

revoke all on function public.enforce_location_season_membership_rules() from public,anon,authenticated;

create or replace function public.activate_future_memberships_for_season(
  p_completed_season_id uuid,p_actor uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_location_id uuid;
  v_future record;
  v_next_barrier uuid;
  v_conflict boolean;
  v_activated integer:=0;
begin
  if not public.is_season_final_gameweek_confirmed(p_completed_season_id) then return 0; end if;

  select l.location_id into v_location_id
  from public.seasons s join public.leagues l on l.id=s.league_id
  where s.id=p_completed_season_id;
  if v_location_id is null then return 0; end if;

  for v_future in
    select tm.id,tm.user_id,tm.season_team_id,tm.is_captain,st.team_id,
      st.name as team_name,s.id as target_season_id,s.league_id as target_league_id,
      s.name as target_season_name
    from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where tm.status='pending' and tm.future_approved_at is not null
      and tm.future_activated_at is null and tm.activation_after_season_id=p_completed_season_id
      and l.location_id=v_location_id
    order by tm.user_id,tm.id
  loop
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_future.user_id::text||':'||v_future.target_league_id::text,0));
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_future.user_id::text||':'||v_location_id::text,0));

    v_next_barrier:=public.get_membership_transition_barrier(v_location_id,v_future.target_season_id);
    if v_next_barrier is not null then
      update public.team_memberships set activation_after_season_id=v_next_barrier,
        future_conflict_reason=null,updated_at=now()
      where id=v_future.id and status='pending';
      continue;
    end if;

    select exists(
      select 1 from public.team_memberships other_membership
      join public.season_teams other_team on other_team.id=other_membership.season_team_id
      join public.seasons other_season on other_season.id=other_team.season_id
      join public.leagues other_league on other_league.id=other_season.league_id
      where other_membership.user_id=v_future.user_id and other_membership.status='active'
        and other_league.location_id=v_location_id and other_season.id=v_future.target_season_id
        and other_team.team_id is distinct from v_future.team_id
    ) into v_conflict;

    if v_conflict then
      update public.team_memberships
      set future_conflict_reason='You are already active with another club in this area for this season. Leave that club before this membership can activate.',
          updated_at=now()
      where id=v_future.id and status='pending';
      continue;
    end if;

    perform public.finalize_previous_location_memberships(
      v_future.user_id,v_location_id,v_future.target_season_id,coalesce(p_actor,auth.uid())
    );

    if exists(
      select 1 from public.team_memberships other_membership
      join public.season_teams other_team on other_team.id=other_membership.season_team_id
      join public.seasons other_season on other_season.id=other_team.season_id
      join public.leagues other_league on other_league.id=other_season.league_id
      where other_membership.user_id=v_future.user_id and other_membership.status='active'
        and other_league.location_id=v_location_id and other_team.team_id is distinct from v_future.team_id
    ) then
      update public.team_memberships
      set future_conflict_reason='You must leave your existing club in this area before this future membership can activate.',
          updated_at=now()
      where id=v_future.id and status='pending';
      continue;
    end if;

    update public.team_memberships
    set status='active',joined_at=now(),left_at=null,future_activated_at=now(),
        future_conflict_reason=null,updated_at=now()
    where id=v_future.id and status='pending'
      and future_approved_at is not null and future_activated_at is null;

    if found then
      insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
      values(coalesce(p_actor,auth.uid()),'team.membership.future_activated','team_membership',v_future.id::text,
        'Previous location season completed with confirmed results',
        jsonb_build_object('status','pending','activation_after_season_id',p_completed_season_id),
        jsonb_build_object('status','active','season_team_id',v_future.season_team_id,'future_activated_at',now()));
      if v_future.is_captain then
        perform public.enqueue_notification_event(v_future.user_id,'team.future_captain_activated',
          jsonb_build_object('season_team_id',v_future.season_team_id,'team_name',v_future.team_name,
            'season_name',v_future.target_season_name,'changed_at',now()));
      end if;
      v_activated:=v_activated+1;
    end if;
  end loop;
  return v_activated;
end;
$$;

revoke all on function public.activate_future_memberships_for_season(uuid,uuid) from public,anon,authenticated;

create or replace function public.activate_future_memberships_after_result()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_season_id uuid;
begin
  if new.confirmed_at is null then
    return new;
  end if;

  select f.season_id into v_season_id
  from public.fixtures f
  where f.id=new.fixture_id;

  if v_season_id is not null then
    perform public.activate_future_memberships_for_season(v_season_id,new.confirmed_by);
  end if;

  return new;
end;
$$;

revoke all on function public.activate_future_memberships_after_result() from public,anon,authenticated;

drop trigger if exists fixture_results_activate_future_memberships on public.fixture_results;
create trigger fixture_results_activate_future_memberships
after insert or update of confirmed_at
on public.fixture_results
for each row
execute function public.activate_future_memberships_after_result();

create or replace function public.activate_future_memberships_after_fixture_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status='completed' then
    perform public.activate_future_memberships_for_season(new.season_id,auth.uid());
  end if;
  return new;
end;
$$;

revoke all on function public.activate_future_memberships_after_fixture_completion() from public,anon,authenticated;

drop trigger if exists fixtures_activate_future_memberships on public.fixtures;
create trigger fixtures_activate_future_memberships
after update of status
on public.fixtures
for each row
when (new.status='completed')
execute function public.activate_future_memberships_after_fixture_completion();

create or replace function public.retry_future_memberships_after_departure()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_location_id uuid;
  v_barrier_id uuid;
begin
  if pg_catalog.pg_trigger_depth()>1
     or coalesce(current_setting('app.future_membership_transition',true),'0')='1'
     or old.status<>'active'
     or new.status<>'left' then
    return new;
  end if;

  select l.location_id into v_location_id
  from public.team_memberships tm
  join public.season_teams st on st.id=tm.season_team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where tm.id=new.id;

  if v_location_id is null then
    return new;
  end if;

  for v_barrier_id in
    select distinct future_membership.activation_after_season_id
    from public.team_memberships future_membership
    join public.season_teams future_team on future_team.id=future_membership.season_team_id
    join public.seasons future_season on future_season.id=future_team.season_id
    join public.leagues future_league on future_league.id=future_season.league_id
    where future_membership.user_id=new.user_id
      and future_membership.status='pending'
      and future_membership.future_approved_at is not null
      and future_membership.future_activated_at is null
      and future_membership.activation_after_season_id is not null
      and future_league.location_id=v_location_id
  loop
    perform public.activate_future_memberships_for_season(v_barrier_id,auth.uid());
  end loop;

  return new;
end;
$$;

revoke all on function public.retry_future_memberships_after_departure() from public,anon,authenticated;

drop trigger if exists team_memberships_retry_future_after_departure on public.team_memberships;
create trigger team_memberships_retry_future_after_departure
after update of status
on public.team_memberships
for each row
when (old.status='active' and new.status='left')
execute function public.retry_future_memberships_after_departure();

create or replace function public.request_team_membership(p_season_team_id uuid)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid:=auth.uid();
  v_player public.players;
  v_team public.season_teams;
  v_season public.seasons;
  v_location_id uuid;
  v_lock_location_id uuid;
  v_lock_league_id uuid;
  v_membership public.team_memberships;
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  select * into v_team from public.season_teams where id=p_season_team_id;
  if not found or v_team.registration_status<>'approved' then
    raise exception 'This team is not currently accepting player requests';
  end if;
  select * into v_season from public.seasons where id=v_team.season_id;
  if not found or v_season.status<>'registration_open' then
    raise exception 'This team is not currently accepting player requests';
  end if;

  v_lock_league_id:=v_season.league_id;
  select l.location_id into v_lock_location_id from public.leagues l where l.id=v_lock_league_id;
  if v_lock_location_id is null then raise exception 'This team does not belong to an active location'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text||':'||v_lock_league_id::text,0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text||':'||v_lock_location_id::text,0));

  select * into v_team from public.season_teams where id=p_season_team_id for share;
  if not found or v_team.registration_status<>'approved' then
    raise exception 'This team is not currently accepting player requests';
  end if;
  select s.* into v_season from public.seasons s where s.id=v_team.season_id for share;
  if not found or v_season.status<>'registration_open' then
    raise exception 'This team is not currently accepting player requests';
  end if;
  select l.location_id into v_location_id from public.leagues l where l.id=v_season.league_id;
  if v_season.league_id is distinct from v_lock_league_id or v_location_id is distinct from v_lock_location_id then
    raise exception 'The destination competition changed while the request was being prepared. Please retry';
  end if;

  select * into v_player from public.players where user_id=v_user for share;
  if not found or v_player.registration_status<>'registered' or v_player.is_banned then
    raise exception 'An approved, eligible player registration is required before joining a team';
  end if;

  if exists(
    select 1
    from public.team_memberships tm
    join public.season_teams other_team on other_team.id=tm.season_team_id
    join public.seasons other_season on other_season.id=other_team.season_id
    join public.leagues other_league on other_league.id=other_season.league_id
    where tm.user_id=v_user and tm.status='active'
      and other_league.location_id=v_location_id
      and other_season.id=v_season.id
      and other_team.team_id is distinct from v_team.team_id
  ) then
    raise exception 'You must leave your existing club before joining another club in the same area for this season';
  end if;

  if exists(
    select 1
    from public.team_memberships tm
    join public.season_teams other_team on other_team.id=tm.season_team_id
    join public.seasons other_season on other_season.id=other_team.season_id
    join public.leagues other_league on other_league.id=other_season.league_id
    where tm.user_id=v_user and tm.status='pending'
      and tm.future_approved_at is not null and tm.future_activated_at is null
      and other_league.location_id=v_location_id
      and other_season.id=v_season.id
      and other_team.team_id is distinct from v_team.team_id
  ) then
    raise exception 'You already have an approved future membership with another club in this area for this season';
  end if;

  if exists(
    select 1
    from public.team_memberships tm
    join public.season_teams other_team on other_team.id=tm.season_team_id
    join public.seasons other_season on other_season.id=other_team.season_id
    join public.leagues other_league on other_league.id=other_season.league_id
    where tm.user_id=v_user and tm.status='pending'
      and tm.future_approved_at is null
      and other_league.location_id=v_location_id
      and other_season.id=v_season.id
  ) then
    raise exception 'You already have a pending team request in this area for this season';
  end if;

  if exists(
    select 1 from public.player_transfer_requests r
    where r.user_id=v_user and r.league_id=v_season.league_id and r.status='pending'
  ) then
    raise exception 'Cancel or resolve your pending transfer request before requesting to join a team';
  end if;

  if exists(
    select 1
    from (
      select source_team.team_id
      from public.team_memberships source_membership
      join public.season_teams source_team on source_team.id=source_membership.season_team_id
      join public.seasons source_season on source_season.id=source_team.season_id
      join public.leagues source_league on source_league.id=source_season.league_id
      where source_membership.user_id=v_user
        and source_membership.status='left'
        and source_membership.voluntarily_left_at is not null
        and source_league.location_id=v_location_id
        and source_season.id=v_season.id
      order by source_membership.voluntarily_left_at desc
      limit 1
    ) latest_departure
    where latest_departure.team_id is distinct from v_team.team_id
  ) then
    raise exception 'Use the player transfer workflow after voluntarily leaving a different club in this season';
  end if;

  insert into public.team_memberships(season_team_id,user_id,status)
  values(p_season_team_id,v_user,'pending')
  on conflict(season_team_id,user_id) do update
    set status='pending',left_at=null,joined_at=null,is_captain=false,
        transfer_request_id=null,voluntarily_left_at=null,
        future_approved_at=null,activation_after_season_id=null,
        future_activated_at=null,future_conflict_reason=null,updated_at=now()
    where public.team_memberships.status in ('left','rejected')
  returning * into v_membership;

  if v_membership.id is null then raise exception 'A membership or request already exists for this team'; end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id)
  values(v_user,'team.membership.requested','team_membership',v_membership.id::text);

  return v_membership;
end;
$$;

revoke all on function public.request_team_membership(uuid) from public,anon;
grant execute on function public.request_team_membership(uuid) to authenticated;

create or replace function public.resolve_team_membership_request(
  p_membership_id uuid,p_decision text
)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_membership public.team_memberships;
  v_team public.season_teams;
  v_season public.seasons;
  v_player public.players;
  v_location_id uuid;
  v_lock_location_id uuid;
  v_lock_league_id uuid;
  v_barrier_id uuid;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  select * into v_membership
  from public.team_memberships
  where id=p_membership_id and status='pending' and future_approved_at is null;
  if not found then raise exception 'No pending team request exists'; end if;

  select * into v_team from public.season_teams where id=v_membership.season_team_id;
  if not found then raise exception 'The destination team no longer exists'; end if;
  select * into v_season from public.seasons where id=v_team.season_id;
  if not found then raise exception 'The destination season no longer exists'; end if;

  v_lock_league_id:=v_season.league_id;
  select l.location_id into v_lock_location_id from public.leagues l where l.id=v_lock_league_id;
  if v_lock_location_id is null then raise exception 'The destination team has no location'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_membership.user_id::text||':'||v_lock_league_id::text,0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_membership.user_id::text||':'||v_lock_location_id::text,0));

  select * into v_membership
  from public.team_memberships
  where id=p_membership_id and status='pending' and future_approved_at is null
  for update;
  if not found then raise exception 'This team request has already been resolved'; end if;

  select * into v_team from public.season_teams where id=v_membership.season_team_id for share;
  select * into v_season from public.seasons where id=v_team.season_id for share;
  select l.location_id into v_location_id from public.leagues l where l.id=v_season.league_id;
  if v_season.league_id is distinct from v_lock_league_id or v_location_id is distinct from v_lock_location_id then
    raise exception 'The destination competition changed while the request was being resolved. Please retry';
  end if;

  if not public.is_active_team_captain(v_membership.season_team_id)
     and not public.can_administer_location(v_location_id) then
    raise exception 'Captain or assigned location administrator permission required';
  end if;

  if p_decision='approved' then
    if v_team.registration_status<>'approved' then raise exception 'Only approved teams can accept players'; end if;
    if v_season.status not in ('registration_open','active') then raise exception 'Membership approvals are closed for this season'; end if;

    select * into v_player from public.players where user_id=v_membership.user_id for share;
    if not found or v_player.registration_status<>'registered' or v_player.is_banned then
      raise exception 'Only registered, eligible players can join a team';
    end if;

    if v_membership.transfer_request_id is not null then
      raise exception 'Transfer-linked memberships must be resolved through the player transfer workflow';
    end if;
    if exists(
      select 1 from public.player_transfer_requests r
      where r.user_id=v_membership.user_id and r.league_id=v_season.league_id and r.status='pending'
    ) then
      raise exception 'This player has a pending transfer request in this league';
    end if;
    if exists(
      select 1
      from public.team_memberships source_membership
      join public.season_teams source_team on source_team.id=source_membership.season_team_id
      join public.seasons source_season on source_season.id=source_team.season_id
      join public.leagues source_league on source_league.id=source_season.league_id
      where source_membership.user_id=v_membership.user_id
        and source_membership.status='left'
        and source_membership.voluntarily_left_at is not null
        and source_league.location_id=v_location_id
        and source_season.id=v_season.id
        and source_team.team_id is distinct from v_team.team_id
    ) then
      raise exception 'Use the player transfer workflow after voluntarily leaving a different club in this season';
    end if;
    if exists(
      select 1 from public.team_memberships tm
      join public.season_teams other_team on other_team.id=tm.season_team_id
      join public.seasons other_season on other_season.id=other_team.season_id
      where tm.user_id=v_membership.user_id and tm.status='active'
        and other_season.league_id=v_season.league_id
        and other_team.season_id=v_season.id
        and other_team.team_id <> v_team.team_id
        and tm.id is distinct from v_membership.id
    ) then
      raise exception 'The player must leave their existing club before joining another club in the same area for this season';
    end if;

    v_barrier_id:=public.get_membership_transition_barrier(v_location_id,v_season.id);
    if v_barrier_id is null then
      perform public.finalize_previous_location_memberships(v_membership.user_id,v_location_id,v_season.id,v_actor);
      update public.team_memberships
      set status='active',joined_at=now(),left_at=null,is_captain=false,
          future_approved_at=null,activation_after_season_id=null,
          future_activated_at=null,future_conflict_reason=null,updated_at=now()
      where id=p_membership_id returning * into v_membership;
      insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
      values(v_actor,'team.membership.approved','team_membership',p_membership_id::text,
        jsonb_build_object('status','active','season_team_id',v_membership.season_team_id));
    else
      update public.team_memberships
      set status='pending',joined_at=null,left_at=null,is_captain=false,
          future_approved_at=now(),activation_after_season_id=v_barrier_id,
          future_activated_at=null,future_conflict_reason=null,updated_at=now()
      where id=p_membership_id returning * into v_membership;
      insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
      values(v_actor,'team.membership.future_approved','team_membership',p_membership_id::text,
        jsonb_build_object('status','pending','future_approved_at',v_membership.future_approved_at,
          'activation_after_season_id',v_barrier_id));
    end if;
  else
    update public.team_memberships
    set status='rejected',left_at=now(),future_approved_at=null,
        activation_after_season_id=null,future_activated_at=null,
        future_conflict_reason=null,updated_at=now()
    where id=p_membership_id returning * into v_membership;
    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
    values(v_actor,'team.membership.rejected','team_membership',p_membership_id::text,
      jsonb_build_object('status','rejected'));
  end if;
  return v_membership;
end;
$$;

revoke all on function public.resolve_team_membership_request(uuid,text) from public,anon;
grant execute on function public.resolve_team_membership_request(uuid,text) to authenticated;

create or replace function public.get_my_future_captain_requests()
returns table(
  membership_id uuid,
  season_team_id uuid,
  team_name text,
  season_id uuid,
  season_name text,
  player_name text,
  requested_at timestamptz,
  activation_after_season_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select request_membership.id,
    request_membership.season_team_id,
    destination_team.name,
    destination_season.id,
    destination_season.name,
    player.full_name,
    request_membership.created_at,
    barrier_season.name
  from public.team_memberships future_captain
  join public.season_teams destination_team on destination_team.id=future_captain.season_team_id
  join public.seasons destination_season on destination_season.id=destination_team.season_id
  join public.leagues destination_league on destination_league.id=destination_season.league_id
  join public.team_memberships request_membership
    on request_membership.season_team_id=future_captain.season_team_id
  join public.players player on player.user_id=request_membership.user_id
  join public.players future_captain_player on future_captain_player.user_id=future_captain.user_id
  left join public.seasons barrier_season on barrier_season.id=future_captain.activation_after_season_id
  where auth.uid() is not null
    and future_captain.user_id=auth.uid()
    and future_captain.is_captain=true
    and future_captain.status='pending'
    and future_captain.future_approved_at is not null
    and future_captain.future_activated_at is null
    and future_captain.future_conflict_reason is null
    and future_captain_player.registration_status='registered'
    and future_captain_player.is_banned=false
    and destination_team.registration_status='approved'
    and destination_season.status in ('registration_open','active')
    and request_membership.status='pending'
    and request_membership.future_approved_at is null
    and request_membership.transfer_request_id is null
    and player.registration_status='registered'
    and player.is_banned=false
  order by destination_season.starts_on,destination_team.name,player.full_name;
$$;

revoke all on function public.get_my_future_captain_requests() from public,anon;
grant execute on function public.get_my_future_captain_requests() to authenticated;

create or replace function public.resolve_future_team_membership_request(
  p_membership_id uuid,p_decision text
)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_membership public.team_memberships;
  v_team public.season_teams;
  v_season public.seasons;
  v_player public.players;
  v_location_id uuid;
  v_lock_location_id uuid;
  v_lock_league_id uuid;
  v_barrier_id uuid;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  select * into v_membership
  from public.team_memberships
  where id=p_membership_id and status='pending'
    and future_approved_at is null and transfer_request_id is null;
  if not found then raise exception 'No pending future-team request exists'; end if;

  select * into v_team from public.season_teams where id=v_membership.season_team_id;
  if not found then raise exception 'The future team no longer exists'; end if;
  select * into v_season from public.seasons where id=v_team.season_id;
  if not found then raise exception 'The future season no longer exists'; end if;

  v_lock_league_id:=v_season.league_id;
  select l.location_id into v_lock_location_id from public.leagues l where l.id=v_lock_league_id;
  if v_lock_location_id is null then raise exception 'The future team has no location'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_membership.user_id::text||':'||v_lock_league_id::text,0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_membership.user_id::text||':'||v_lock_location_id::text,0));

  select * into v_membership
  from public.team_memberships
  where id=p_membership_id and status='pending'
    and future_approved_at is null and transfer_request_id is null
  for update;
  if not found then raise exception 'This future-team request has already been resolved'; end if;

  select * into v_team from public.season_teams where id=v_membership.season_team_id for share;
  select * into v_season from public.seasons where id=v_team.season_id for share;
  select l.location_id into v_location_id from public.leagues l where l.id=v_season.league_id;
  if v_season.league_id is distinct from v_lock_league_id or v_location_id is distinct from v_lock_location_id then
    raise exception 'The future competition changed while the request was being resolved. Please retry';
  end if;

  if not exists(
    select 1 from public.team_memberships future_captain
    join public.players captain_player on captain_player.user_id=future_captain.user_id
    where future_captain.season_team_id=v_membership.season_team_id
      and future_captain.user_id=v_actor
      and future_captain.is_captain=true
      and future_captain.status='pending'
      and future_captain.future_approved_at is not null
      and future_captain.future_activated_at is null
      and future_captain.future_conflict_reason is null
      and captain_player.registration_status='registered'
      and captain_player.is_banned=false
  ) then
    raise exception 'Approved future captain permission required for this team';
  end if;

  if p_decision='approved' then
    if v_team.registration_status<>'approved' or v_season.status not in ('registration_open','active') then
      raise exception 'This future team is no longer accepting player memberships';
    end if;
    select * into v_player from public.players where user_id=v_membership.user_id for share;
    if not found or v_player.registration_status<>'registered' or v_player.is_banned then
      raise exception 'Only registered, eligible players can join a team';
    end if;
    if exists(
      select 1 from public.player_transfer_requests r
      where r.user_id=v_membership.user_id and r.league_id=v_season.league_id and r.status='pending'
    ) then
      raise exception 'This player has a pending transfer request in this league';
    end if;
    if exists(
      select 1
      from public.team_memberships source_membership
      join public.season_teams source_team on source_team.id=source_membership.season_team_id
      join public.seasons source_season on source_season.id=source_team.season_id
      join public.leagues source_league on source_league.id=source_season.league_id
      where source_membership.user_id=v_membership.user_id
        and source_membership.status='left'
        and source_membership.voluntarily_left_at is not null
        and source_league.location_id=v_location_id
        and source_season.id=v_season.id
        and source_team.team_id is distinct from v_team.team_id
    ) then
      raise exception 'Use the player transfer workflow after voluntarily leaving a different club in this season';
    end if;
    if exists(
      select 1 from public.team_memberships tm
      join public.season_teams st on st.id=tm.season_team_id
      where tm.user_id=v_membership.user_id and tm.status='active'
        and st.season_id=v_season.id and st.team_id is distinct from v_team.team_id
        and tm.id is distinct from v_membership.id
    ) then
      raise exception 'The player must leave their existing club before joining another club in the same area for this season';
    end if;

    v_barrier_id:=public.get_membership_transition_barrier(v_location_id,v_season.id);
    if v_barrier_id is null then
      perform public.finalize_previous_location_memberships(v_membership.user_id,v_location_id,v_season.id,v_actor);
      update public.team_memberships
      set status='active',joined_at=now(),left_at=null,is_captain=false,
          future_approved_at=null,activation_after_season_id=null,
          future_activated_at=null,future_conflict_reason=null,updated_at=now()
      where id=p_membership_id returning * into v_membership;
      insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
      values(v_actor,'team.membership.approved','team_membership',p_membership_id::text,
        jsonb_build_object('status','active','season_team_id',v_membership.season_team_id));
    else
      update public.team_memberships
      set status='pending',joined_at=null,left_at=null,is_captain=false,
          future_approved_at=now(),activation_after_season_id=v_barrier_id,
          future_activated_at=null,future_conflict_reason=null,updated_at=now()
      where id=p_membership_id returning * into v_membership;
      insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
      values(v_actor,'team.membership.future_approved','team_membership',p_membership_id::text,
        jsonb_build_object('status','pending','future_approved_at',v_membership.future_approved_at,
          'activation_after_season_id',v_barrier_id));
    end if;
  else
    update public.team_memberships
    set status='rejected',left_at=now(),future_approved_at=null,
        activation_after_season_id=null,future_activated_at=null,
        future_conflict_reason=null,updated_at=now()
    where id=p_membership_id returning * into v_membership;
    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
    values(v_actor,'team.membership.rejected','team_membership',p_membership_id::text,
      jsonb_build_object('status','rejected'));
  end if;
  return v_membership;
end;
$$;

revoke all on function public.resolve_future_team_membership_request(uuid,text) from public,anon;
grant execute on function public.resolve_future_team_membership_request(uuid,text) to authenticated;

drop function if exists public.get_my_team_request_statuses();

create or replace function public.get_my_team_request_statuses()
returns table(
  membership_id uuid,
  season_team_id uuid,
  team_name text,
  season_id uuid,
  season_name text,
  team_registration_status text,
  membership_status text,
  is_captain boolean,
  is_transfer_request boolean,
  created_at timestamptz,
  future_approved_at timestamptz,
  activation_after_season_id uuid,
  activation_after_season_name text,
  future_activated_at timestamptz,
  future_conflict_reason text
)
language sql
stable
security definer
set search_path = ''
as $$
  select tm.id,tm.season_team_id,st.name,st.season_id,s.name,
    st.registration_status::text,tm.status::text,tm.is_captain,
    tm.transfer_request_id is not null,tm.created_at,
    tm.future_approved_at,tm.activation_after_season_id,barrier.name,
    tm.future_activated_at,tm.future_conflict_reason
  from public.team_memberships tm
  join public.season_teams st on st.id=tm.season_team_id
  join public.seasons s on s.id=st.season_id
  left join public.seasons barrier on barrier.id=tm.activation_after_season_id
  where auth.uid() is not null
    and tm.user_id = auth.uid()
    and tm.status::text<>'left'
  order by tm.created_at desc,tm.id
  limit 100;
$$;

revoke all on function public.get_my_team_request_statuses() from public,anon;
grant execute on function public.get_my_team_request_statuses() to authenticated;

create or replace function public.get_captain_dashboard()
returns table(
  season_team_id uuid,
  team_name text,
  membership_id uuid,
  player_name text,
  membership_status text,
  is_captain boolean,
  squad_number smallint,
  requested_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid:=auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists(
    select 1 from public.team_memberships tm
    where tm.user_id=v_user_id and tm.is_captain=true and tm.status='active'
  ) then
    raise exception 'Active captain permission required';
  end if;

  return query
  select tm.season_team_id,st.name,tm.id,p.full_name,tm.status::text,
    tm.is_captain,tm.squad_number,tm.created_at
  from public.team_memberships captain
  join public.team_memberships tm on tm.season_team_id=captain.season_team_id
  join public.season_teams st on st.id=tm.season_team_id
  join public.players p on p.user_id=tm.user_id
  where captain.user_id=v_user_id
    and captain.is_captain=true
    and captain.status='active'
    and tm.status in ('active','pending')
    and (tm.future_approved_at is null or tm.future_activated_at is not null)
  order by st.name,case when tm.status='pending' then 0 else 1 end,p.full_name;
end;
$$;

revoke all on function public.get_captain_dashboard() from public,anon;
grant execute on function public.get_captain_dashboard() to authenticated;

create or replace function public.resolve_team_registration(
  p_season_team_id uuid,p_decision text,p_reason text default null
)
returns public.season_teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_season_team public.season_teams;
  v_season public.seasons;
  v_player public.players;
  v_captain_user_id uuid;
  v_location_id uuid;
  v_lock_location_id uuid;
  v_lock_league_id uuid;
  v_barrier_id uuid;
  v_membership public.team_memberships;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;

  select * into v_season_team from public.season_teams
  where id=p_season_team_id and registration_status='pending';
  if not found then raise exception 'No pending team registration exists'; end if;

  select tm.user_id into v_captain_user_id
  from public.team_memberships tm
  where tm.season_team_id=p_season_team_id and tm.status='pending'
    and tm.is_captain=false and tm.future_approved_at is null;
  if v_captain_user_id is null then
    raise exception 'Team registration has no pending applicant to appoint as captain';
  end if;

  select * into v_season from public.seasons where id=v_season_team.season_id;
  if not found then raise exception 'The team registration season no longer exists'; end if;
  v_lock_league_id:=v_season.league_id;
  select l.location_id into v_lock_location_id from public.leagues l where l.id=v_lock_league_id;
  if v_lock_location_id is null then raise exception 'The team registration has no location'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_captain_user_id::text||':'||v_lock_league_id::text,0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_captain_user_id::text||':'||v_lock_location_id::text,0));

  select * into v_season_team from public.season_teams
  where id=p_season_team_id and registration_status='pending'
  for update;
  if not found then raise exception 'This team registration has already been resolved'; end if;

  select * into v_membership from public.team_memberships tm
  where tm.season_team_id=p_season_team_id and tm.user_id=v_captain_user_id
    and tm.status='pending' and tm.is_captain=false and tm.future_approved_at is null
  for update;
  if not found then raise exception 'Team registration no longer has a pending applicant to appoint as captain'; end if;

  select * into v_season from public.seasons where id=v_season_team.season_id for share;
  select l.location_id into v_location_id from public.leagues l where l.id=v_season.league_id;
  if v_season.league_id is distinct from v_lock_league_id or v_location_id is distinct from v_lock_location_id then
    raise exception 'The team registration competition changed while the application was being resolved. Please retry';
  end if;
  if not public.can_administer_location(v_location_id) then
    raise exception 'You are not assigned to this location';
  end if;

  if p_decision='approved' then
    if v_season.status<>'registration_open' then raise exception 'Team registrations are closed for this season'; end if;
    select * into v_player from public.players where user_id=v_captain_user_id for share;
    if not found or v_player.registration_status<>'registered' or v_player.is_banned then
      raise exception 'The proposed captain is no longer an eligible registered player';
    end if;
    if exists(
      select 1 from public.team_memberships tm
      join public.season_teams other_team on other_team.id=tm.season_team_id
      where tm.user_id=v_captain_user_id and tm.status='active'
        and other_team.season_id=v_season_team.season_id and tm.season_team_id<>p_season_team_id
    ) then
      raise exception 'The proposed captain is already active with another club in this area for this season';
    end if;
    if exists(
      select 1 from public.team_memberships tm
      join public.season_teams other_team on other_team.id=tm.season_team_id
      join public.seasons other_season on other_season.id=other_team.season_id
      join public.leagues other_league on other_league.id=other_season.league_id
      where tm.user_id=v_captain_user_id and tm.is_captain=true
        and other_league.location_id=v_location_id
        and other_season.id=v_season_team.season_id
        and (tm.status='active' or tm.future_approved_at is not null)
        and tm.id is distinct from v_membership.id
    ) then
      raise exception 'The proposed captain already holds a captaincy in this area for this season';
    end if;
    v_barrier_id:=public.get_membership_transition_barrier(v_location_id,v_season_team.season_id);
  end if;

  update public.season_teams
  set registration_status=p_decision::public.registration_status,
      approved_at=case when p_decision='approved' then now() else null end,
      approved_by=case when p_decision='approved' then v_actor else null end
  where id=p_season_team_id returning * into v_season_team;

  if p_decision='approved' then
    if v_barrier_id is null then
      perform public.finalize_previous_location_memberships(v_captain_user_id,v_location_id,v_season_team.season_id,v_actor);
      update public.team_memberships
      set status='active',is_captain=true,joined_at=now(),left_at=null,
          future_approved_at=null,activation_after_season_id=null,
          future_activated_at=null,future_conflict_reason=null,updated_at=now()
      where id=v_membership.id returning * into v_membership;
    else
      update public.team_memberships
      set status='pending',is_captain=true,joined_at=null,left_at=null,
          future_approved_at=now(),activation_after_season_id=v_barrier_id,
          future_activated_at=null,future_conflict_reason=null,updated_at=now()
      where id=v_membership.id returning * into v_membership;
    end if;
  else
    update public.team_memberships
    set status='rejected',left_at=now(),future_approved_at=null,
        activation_after_season_id=null,future_activated_at=null,
        future_conflict_reason=null,updated_at=now()
    where id=v_membership.id returning * into v_membership;
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  values(v_actor,'team.registration.'||p_decision,'season_team',p_season_team_id::text,
    nullif(trim(p_reason),''),jsonb_build_object(
      'registration_status',v_season_team.registration_status,
      'captain_user_id',v_captain_user_id,
      'future_captaincy',case when p_decision='approved' then v_membership.future_approved_at is not null else false end,
      'activation_after_season_id',v_membership.activation_after_season_id
    ));
  return v_season_team;
end;
$$;

revoke all on function public.resolve_team_registration(uuid,text,text) from public,anon;
grant execute on function public.resolve_team_registration(uuid,text,text) to authenticated;


-- Keep all player/team departure and transfer mutations on the same
-- league-then-location advisory-lock order as membership approvals.
create or replace function public.leave_team_membership(p_membership_id uuid)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid:=auth.uid();
  v_membership public.team_memberships;
  v_team_name text;
  v_location_id uuid;
  v_league_id uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  select l.location_id,s.league_id,st.name
  into v_location_id,v_league_id,v_team_name
  from public.team_memberships tm
  join public.season_teams st on st.id=tm.season_team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where tm.id=p_membership_id and tm.user_id=v_user;
  if not found then raise exception 'You must have an active membership to leave this club'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text||':'||v_league_id::text,0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text||':'||v_location_id::text,0));

  select * into v_membership
  from public.team_memberships
  where id=p_membership_id and user_id=v_user
  for update;
  if not found or v_membership.status<>'active' then
    raise exception 'You must have an active membership to leave this club';
  end if;
  if v_membership.is_captain then
    raise exception 'Appoint a replacement captain before leaving this club';
  end if;
  if exists(
    select 1 from public.fixture_team_sheet_players tsp
    join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true
    join public.fixtures f on f.id=ts.fixture_id
    where tsp.user_id=v_user and ts.season_team_id=v_membership.season_team_id
      and f.status in ('scheduled','in_progress')
  ) then
    raise exception 'You are on a submitted sheet for a fixture that has not been completed. Ask an administrator to amend it before leaving';
  end if;

  update public.team_memberships
  set status='left',left_at=now(),voluntarily_left_at=now(),squad_number=null,updated_at=now()
  where id=v_membership.id returning * into v_membership;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_user,'player.membership.left','team_membership',v_membership.id::text,
    'Voluntary departure by player',
    jsonb_build_object('status','active','season_team_id',v_membership.season_team_id),
    jsonb_build_object('status','left','season_team_id',v_membership.season_team_id));

  perform public.enqueue_notification_event(v_user,'team.membership_left',
    jsonb_build_object('team_name',coalesce(v_team_name,'your club'),'changed_at',now()));
  return v_membership;
end;
$$;

revoke all on function public.leave_team_membership(uuid) from public,anon;
grant execute on function public.leave_team_membership(uuid) to authenticated;

create or replace function public._resolve_player_transfer_request(
  p_request_id uuid,p_decision text,p_reason text,p_actor uuid,p_admin_override boolean
)
returns public.player_transfer_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.player_transfer_requests;
  v_source public.team_memberships;
  v_source_team_id uuid;
  v_destination public.season_teams;
  v_season public.seasons;
  v_player public.players;
  v_location_id uuid;
  v_cancelled integer:=0;
  v_membership public.team_memberships;
begin
  if p_actor is null then raise exception 'Authentication required'; end if;
  if p_decision is null or p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a decision reason of at least 5 characters'; end if;

  select * into v_request from public.player_transfer_requests where id=p_request_id;
  if not found then raise exception 'Transfer request not found'; end if;
  if v_request.user_id is null then raise exception 'The transfer request no longer belongs to an active player account'; end if;

  select l.location_id into v_location_id
  from public.season_teams destination
  join public.seasons destination_season on destination_season.id=destination.season_id
  join public.leagues l on l.id=destination_season.league_id
  where destination.id=v_request.destination_season_team_id
    and destination_season.league_id=v_request.league_id;
  if v_location_id is null then raise exception 'The transfer destination no longer belongs to a valid location'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_request.user_id::text||':'||v_request.league_id::text,0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_request.user_id::text||':'||v_location_id::text,0));

  select * into v_request from public.player_transfer_requests where id=p_request_id for update;
  if not found or v_request.status<>'pending' then
    raise exception 'This transfer has already been resolved or secured by another club';
  end if;

  select * into v_source from public.team_memberships where id=v_request.source_membership_id for share;
  if not found or v_source.user_id is distinct from v_request.user_id
     or v_source.season_team_id is distinct from v_request.source_season_team_id
     or v_source.status<>'left' or v_source.voluntarily_left_at is null then
    raise exception 'The source membership was not voluntarily left by this player';
  end if;

  select st.team_id into v_source_team_id
  from public.season_teams st join public.seasons source_season on source_season.id=st.season_id
  where st.id=v_source.season_team_id and source_season.league_id=v_request.league_id;
  if v_source_team_id is null then raise exception 'The source membership does not belong to this league'; end if;

  select * into v_destination from public.season_teams where id=v_request.destination_season_team_id for share;
  if not found or v_destination.registration_status<>'approved' then raise exception 'Destination club is no longer approved'; end if;
  if v_source_team_id=v_destination.team_id then raise exception 'A transfer must move the player to a different club'; end if;

  select * into v_season from public.seasons where id=v_destination.season_id for share;
  if not found or v_season.league_id<>v_request.league_id or v_season.status not in ('registration_open','active') then
    raise exception 'Destination season is no longer eligible';
  end if;

  if p_admin_override then
    if not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  elsif not public.is_active_team_captain(v_destination.id) then
    raise exception 'Only the destination club captain can approve or reject this transfer';
  end if;

  select * into v_player from public.players where user_id=v_request.user_id for share;
  if not found or v_player.registration_status<>'registered' or v_player.is_banned then
    raise exception 'Player is not currently eligible to transfer';
  end if;

  if exists(
    select 1 from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    where tm.user_id=v_request.user_id and tm.status='active'
      and s.league_id=v_request.league_id and tm.id<>v_source.id
  ) then
    raise exception 'Player is already attached to a club in this league';
  end if;

  if p_decision='approved' then
    if v_request.is_emergency then
      if v_request.target_fixture_id is null or not exists(
        select 1 from public.fixtures f
        where f.id=v_request.target_fixture_id and f.season_id=v_destination.season_id
          and v_destination.id in (f.home_team_id,f.away_team_id)
          and f.status='scheduled' and f.scheduled_at>now()
          and f.scheduled_at<=now()+interval '24 hours'
          and not exists(select 1 from public.fixture_team_sheets ts
            where ts.fixture_id=f.id and ts.season_team_id=v_destination.id and ts.is_locked=true)
      ) then raise exception 'The emergency transfer window for this fixture has closed'; end if;
    end if;

    update public.player_transfer_requests
    set status='approved',resolved_at=now(),resolved_by=p_actor,resolution_reason=btrim(p_reason),updated_at=now()
    where id=p_request_id returning * into v_request;

    update public.player_transfer_requests
    set status='cancelled',resolved_at=now(),resolved_by=p_actor,
      resolution_reason='Automatically cancelled because another club secured the player',updated_at=now()
    where user_id=v_request.user_id and league_id=v_request.league_id
      and status='pending' and id<>p_request_id;
    get diagnostics v_cancelled=row_count;

    insert into public.team_memberships(
      season_team_id,user_id,status,is_captain,squad_number,joined_at,left_at,transfer_request_id
    ) values(v_destination.id,v_request.user_id,'active',false,null,now(),null,v_request.id)
    on conflict(season_team_id,user_id) do update
      set status='active',is_captain=false,squad_number=null,joined_at=now(),left_at=null,
        voluntarily_left_at=null,transfer_request_id=v_request.id,updated_at=now()
      where public.team_memberships.status in ('left','rejected')
    returning * into v_membership;
    if v_membership.id is null then raise exception 'The destination already has an active or pending membership for this player'; end if;
  else
    update public.player_transfer_requests
    set status='rejected',resolved_at=now(),resolved_by=p_actor,resolution_reason=btrim(p_reason),updated_at=now()
    where id=p_request_id returning * into v_request;
  end if;

  perform public.enqueue_notification_event(
    v_request.user_id,
    case when p_decision='approved' then 'player.transfer_approved' else 'player.transfer_rejected' end,
    jsonb_build_object('transfer_request_id',v_request.id,
      'source_team_name',(select name from public.season_teams where id=v_request.source_season_team_id),
      'team_name',v_destination.name,'reason',btrim(p_reason),'changed_at',now(),'is_emergency',v_request.is_emergency)
  );

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(p_actor,'player.transfer.'||p_decision,'player_transfer_request',p_request_id::text,btrim(p_reason),
    jsonb_build_object('status','pending','league_id',v_request.league_id),
    jsonb_build_object('status',p_decision,'destination_team_id',v_destination.id,
      'cancelled_competing_requests',v_cancelled,'admin_override',p_admin_override));
  return v_request;
end;
$$;

revoke all on function public._resolve_player_transfer_request(uuid,text,text,uuid,boolean) from public,anon,authenticated;

create or replace function public.admin_remove_player_from_team(p_membership_id uuid,p_reason text)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_membership public.team_memberships;
  v_before jsonb;
  v_team_name text;
  v_next_status public.membership_status;
  v_user_id uuid;
  v_location_id uuid;
  v_league_id uuid;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;

  select l.location_id,s.league_id,st.name
  into v_location_id,v_league_id,v_team_name
  from public.team_memberships tm
  join public.season_teams st on st.id=tm.season_team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where tm.id=p_membership_id;
  if not found then raise exception 'Team membership not found'; end if;

  select tm.user_id into v_user_id
  from public.team_memberships tm where tm.id=p_membership_id;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user_id::text||':'||v_league_id::text,0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user_id::text||':'||v_location_id::text,0));

  select * into v_membership from public.team_memberships where id=p_membership_id for update;
  if not found then raise exception 'Team membership not found'; end if;
  if v_membership.status not in ('active','pending') then raise exception 'Only active or pending memberships can be removed'; end if;
  if v_membership.is_captain then raise exception 'Appoint a replacement captain before removing this player'; end if;

  if v_membership.status='active' and exists(
    select 1 from public.fixture_team_sheet_players tsp
    join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true
    join public.fixtures f on f.id=ts.fixture_id
    where tsp.user_id=v_membership.user_id and ts.season_team_id=v_membership.season_team_id
      and f.status='scheduled' and f.scheduled_at>now()
  ) then
    raise exception 'Player is on a locked upcoming team sheet. Amend the team sheet before removing them';
  end if;

  v_before:=jsonb_build_object('status',v_membership.status,'is_captain',v_membership.is_captain,
    'squad_number',v_membership.squad_number,'season_team_id',v_membership.season_team_id);
  v_next_status:=case when v_membership.status='active' then 'left'::public.membership_status else 'rejected'::public.membership_status end;

  update public.team_memberships
  set status=v_next_status,left_at=case when v_next_status='left'::public.membership_status then now() else left_at end,
    squad_number=null,updated_at=now()
  where id=p_membership_id returning * into v_membership;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'team.membership.admin_removed','team_membership',p_membership_id::text,btrim(p_reason),v_before,
    jsonb_build_object('status',v_membership.status,'season_team_id',v_membership.season_team_id,
      'user_id',v_membership.user_id,'reason',btrim(p_reason)));

  if v_next_status='left'::public.membership_status then
    perform public.enqueue_notification_event(v_membership.user_id,'team.membership_removed',
      jsonb_build_object('team_name',v_team_name,'reason',btrim(p_reason),'changed_at',now()));
  end if;
  return v_membership;
end;
$$;

revoke all on function public.admin_remove_player_from_team(uuid,text) from public,anon;
grant execute on function public.admin_remove_player_from_team(uuid,text) to authenticated;

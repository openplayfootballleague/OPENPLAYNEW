-- Enforce player club exclusivity at the location (area) boundary, not merely
-- within a single league. Completed seasons remain historical and do not block
-- membership or captaincy in a later season.

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
  v_season_status text;
  v_latest_source_membership_id uuid;
  v_latest_source_team_id uuid;
  v_has_active_same_club boolean:=false;
  v_transfer_request public.player_transfer_requests;
begin
  if tg_op='UPDATE' and new.season_team_id is distinct from old.season_team_id then
    raise exception 'Membership history cannot be moved between clubs; use the player transfer workflow';
  end if;
  if new.status<>'active' then return new; end if;

  select l.location_id,s.league_id,st.team_id,s.status::text
    into v_location_id,v_league_id,v_club_id,v_season_status
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=new.season_team_id;

  if v_location_id is null then raise exception 'Membership team must belong to a location'; end if;
  if v_season_status not in ('registration_open','active') then return new; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('membership-location:'||new.user_id::text||':'||v_location_id::text,0)
  );

  select exists(
    select 1
    from public.team_memberships active_membership
    join public.season_teams active_team on active_team.id=active_membership.season_team_id
    join public.seasons active_season on active_season.id=active_team.season_id
    join public.leagues active_league on active_league.id=active_season.league_id
    where active_membership.user_id=new.user_id
      and active_membership.status='active'
      and active_season.status in ('registration_open','active')
      and active_league.location_id=v_location_id
      and active_team.team_id=v_club_id
      and active_membership.id is distinct from new.id
  ) into v_has_active_same_club;

  select source_membership.id,source_team.team_id
    into v_latest_source_membership_id,v_latest_source_team_id
  from public.team_memberships source_membership
  join public.season_teams source_team on source_team.id=source_membership.season_team_id
  join public.seasons source_season on source_season.id=source_team.season_id
  where source_membership.user_id=new.user_id
    and source_membership.status='left'
    and source_membership.voluntarily_left_at is not null
    and source_season.league_id=v_league_id
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
  elsif v_latest_source_team_id is not null
    and v_latest_source_team_id is distinct from v_club_id
    and not v_has_active_same_club then
    raise exception 'A player who voluntarily left a different club in this league must join through an approved transfer request';
  end if;

  if exists (
    select 1
    from public.team_memberships tm
    join public.season_teams other_team on other_team.id=tm.season_team_id
    join public.seasons other_season on other_season.id=other_team.season_id
    join public.leagues other_league on other_league.id=other_season.league_id
    where tm.user_id=new.user_id
      and tm.status='active'
      and other_season.status in ('registration_open','active')
      and other_league.location_id=v_location_id
      and other_team.team_id is distinct from v_club_id
      and tm.id is distinct from new.id
  ) then
    raise exception 'A player can represent only one club in the same area at a time';
  end if;

  if exists (
    select 1
    from public.team_memberships pending_membership
    join public.season_teams pending_team on pending_team.id=pending_membership.season_team_id
    join public.seasons pending_season on pending_season.id=pending_team.season_id
    join public.leagues pending_league on pending_league.id=pending_season.league_id
    where pending_membership.user_id=new.user_id
      and pending_membership.status='pending'
      and pending_season.status in ('registration_open','active')
      and pending_league.location_id=v_location_id
      and pending_team.team_id is distinct from v_club_id
      and pending_membership.id is distinct from new.id
  ) then
    raise exception 'Resolve pending team requests to other clubs in this area before activating this membership';
  end if;

  if exists (
    select 1
    from public.player_transfer_requests r
    join public.season_teams destination on destination.id=r.destination_season_team_id
    join public.seasons destination_season on destination_season.id=destination.season_id
    join public.leagues destination_league on destination_league.id=destination_season.league_id
    where r.user_id=new.user_id
      and r.status='pending'
      and destination_league.location_id=v_location_id
  ) then
    raise exception 'Resolve or cancel pending transfer requests in this area before activating another club membership';
  end if;

  return new;
end;
$$;

drop trigger if exists team_memberships_one_active_club_per_league on public.team_memberships;
drop trigger if exists team_memberships_one_active_club_per_location on public.team_memberships;
create trigger team_memberships_one_active_club_per_location
before insert or update of status,season_team_id,user_id
on public.team_memberships
for each row
execute function public.enforce_one_active_club_per_player_per_location();
revoke all on function public.enforce_one_active_club_per_player_per_location() from public,anon,authenticated;

-- One player may hold captaincy for only one distinct club in an area while
-- that area has an open/active season. Completed seasons are historical, so a
-- future season may have a separate captaincy.
create or replace function public.enforce_one_captaincy_per_player_per_location()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_location_id uuid;
  v_team_id uuid;
  v_season_status text;
begin
  if new.status<>'active' or new.is_captain is not true then return new; end if;

  select l.location_id,st.team_id,s.status::text
    into v_location_id,v_team_id,v_season_status
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=new.season_team_id;

  if v_location_id is null then raise exception 'Captain membership must belong to a location'; end if;
  if v_season_status not in ('registration_open','active') then return new; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('captain-location:'||new.user_id::text||':'||v_location_id::text,0)
  );

  if exists (
    select 1
    from public.team_memberships existing
    join public.season_teams existing_team on existing_team.id=existing.season_team_id
    join public.seasons existing_season on existing_season.id=existing_team.season_id
    join public.leagues existing_league on existing_league.id=existing_season.league_id
    where existing.user_id=new.user_id
      and existing.status='active'
      and existing.is_captain=true
      and existing_season.status in ('registration_open','active')
      and existing_league.location_id=v_location_id
      and existing_team.team_id is distinct from v_team_id
      and existing.id is distinct from new.id
  ) then
    raise exception 'You can captain only one club in the same area while its season is open or active';
  end if;
  return new;
end;
$$;

drop trigger if exists team_memberships_one_captaincy_per_location on public.team_memberships;
create trigger team_memberships_one_captaincy_per_location
before insert or update of status,is_captain,season_team_id,user_id
on public.team_memberships
for each row
execute function public.enforce_one_captaincy_per_player_per_location();
revoke all on function public.enforce_one_captaincy_per_player_per_location() from public,anon,authenticated;

-- A pending transfer request is not a way around an active membership in
-- another league at the same location.
create or replace function public.guard_pending_transfer_request_location_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as '
declare
  v_location_id uuid;
begin
  if new.status<>''pending'' or new.user_id is null then return new; end if;

  select l.location_id into v_location_id
  from public.season_teams destination
  join public.seasons s on s.id=destination.season_id
  join public.leagues l on l.id=s.league_id
  where destination.id=new.destination_season_team_id;

  if v_location_id is null then raise exception ''Transfer destination must belong to a location''; end if;

  if exists (
    select 1
    from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where tm.user_id=new.user_id
      and tm.status=''active''
      and s.status in (''registration_open'',''active'')
      and l.location_id=v_location_id
  ) then
    raise exception ''Leave your existing club in this area before requesting a transfer'';
  end if;
  return new;
end;
'
;

drop trigger if exists player_transfer_requests_location_membership_guard on public.player_transfer_requests;
create trigger player_transfer_requests_location_membership_guard
before insert or update of status,destination_season_team_id,user_id
on public.player_transfer_requests
for each row
execute function public.guard_pending_transfer_request_location_membership();
revoke all on function public.guard_pending_transfer_request_location_membership() from public,anon,authenticated;

-- Fail closed if the existing data already violates the newly approved area rules.
do $$
begin
  if exists (
    select tm.user_id,l.location_id
    from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where tm.status='active' and s.status in ('registration_open','active')
    group by tm.user_id,l.location_id
    having count(distinct st.team_id)>1
  ) then
    raise exception 'Resolve existing players attached to multiple clubs in one active area before applying location-wide membership safeguards';
  end if;

  if exists (
    select tm.user_id,l.location_id
    from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where tm.status='active' and tm.is_captain=true
      and s.status in ('registration_open','active')
    group by tm.user_id,l.location_id
    having count(distinct st.team_id)>1
  ) then
    raise exception 'Resolve existing players holding captaincy for multiple clubs in one active area before applying captaincy safeguards';
  end if;
end;
$$;

-- Team join requests are serialized and checked across the whole location.
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
  v_membership public.team_memberships;
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  select * into v_player from public.players where user_id=v_user for share;
  if not found or v_player.registration_status<>'registered' or v_player.is_banned then
    raise exception 'An approved, eligible player registration is required before joining a team';
  end if;

  select * into v_team from public.season_teams where id=p_season_team_id for share;
  if not found or v_team.registration_status<>'approved' then
    raise exception 'This team is not currently accepting player requests';
  end if;

  select * into v_season from public.seasons where id=v_team.season_id for share;
  if not found or v_season.status<>'registration_open' then
    raise exception 'This team is not currently accepting player requests';
  end if;

  select l.location_id into v_location_id
  from public.leagues l where l.id=v_season.league_id;
  if v_location_id is null then raise exception 'This team does not belong to a valid area'; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('membership-location:'||v_user::text||':'||v_location_id::text,0)
  );

  if exists(
    select 1
    from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where tm.user_id=v_user and tm.status='active'
      and s.status in ('registration_open','active')
      and l.location_id=v_location_id
      and st.team_id<>v_team.team_id
  ) then
    raise exception 'You are already attached to another club in this area. Leave that club before requesting to join here.';
  end if;

  if exists(
    select 1
    from public.player_transfer_requests r
    join public.season_teams destination on destination.id=r.destination_season_team_id
    join public.seasons destination_season on destination_season.id=destination.season_id
    join public.leagues destination_league on destination_league.id=destination_season.league_id
    where r.user_id=v_user and r.status='pending'
      and destination_league.location_id=v_location_id
  ) then
    raise exception 'Cancel or resolve your pending transfer request in this area before requesting to join a team';
  end if;

  if not exists(
    select 1
    from public.team_memberships active_membership
    join public.season_teams active_team on active_team.id=active_membership.season_team_id
    join public.seasons active_season on active_season.id=active_team.season_id
    where active_membership.user_id=v_user
      and active_membership.status='active'
      and active_season.league_id=v_season.league_id
      and active_team.team_id=v_team.team_id
  ) and exists(
    select 1
    from (
      select source_team.team_id
      from public.team_memberships source_membership
      join public.season_teams source_team on source_team.id=source_membership.season_team_id
      join public.seasons source_season on source_season.id=source_team.season_id
      where source_membership.user_id=v_user
        and source_membership.status='left'
        and source_membership.voluntarily_left_at is not null
        and source_season.league_id=v_season.league_id
      order by source_membership.voluntarily_left_at desc
      limit 1
    ) latest_voluntary_departure
    where latest_voluntary_departure.team_id<>v_team.team_id
  ) then
    raise exception 'Use the player transfer workflow after voluntarily leaving a different club in this league';
  end if;

  if exists(
    select 1
    from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where tm.user_id=v_user and tm.status='pending'
      and s.status in ('registration_open','active')
      and l.location_id=v_location_id
      and st.team_id<>v_team.team_id
  ) then
    raise exception 'You already have a pending team request for another club in this area';
  end if;

  insert into public.team_memberships(season_team_id,user_id,status)
  values(p_season_team_id,v_user,'pending')
  on conflict(season_team_id,user_id) do update
    set status='pending',left_at=null,voluntarily_left_at=null,transfer_request_id=null,joined_at=null,is_captain=false,updated_at=now()
    where public.team_memberships.status in ('left','rejected')
  returning * into v_membership;

  if v_membership.id is null then
    raise exception 'A membership or request already exists for this team';
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id)
  values(v_user,'team.membership.requested','team_membership',v_membership.id::text);

  return v_membership;
end;
$$;

revoke all on function public.request_team_membership(uuid) from public,anon;
grant execute on function public.request_team_membership(uuid) to authenticated;

-- Captain/location-admin approvals use the same location lock and scope.
create or replace function public.resolve_team_membership_request(
  p_membership_id uuid,
  p_decision text
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
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  select * into v_membership from public.team_memberships
  where id=p_membership_id and status='pending';
  if not found then raise exception 'No pending team request exists'; end if;

  select l.location_id into v_location_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=v_membership.season_team_id;

  if not public.is_active_team_captain(v_membership.season_team_id)
     and not public.can_administer_location(v_location_id) then
    raise exception 'Captain or assigned location administrator permission required';
  end if;

  if p_decision='approved' then
    select * into v_team from public.season_teams
    where id=v_membership.season_team_id for share;
    if not found or v_team.registration_status<>'approved' then
      raise exception 'Only approved teams can accept players';
    end if;

    select * into v_season from public.seasons where id=v_team.season_id for share;
    if not found or v_season.status not in ('registration_open','active') then
      raise exception 'Membership approvals are closed for this season';
    end if;

    select * into v_player from public.players where user_id=v_membership.user_id for share;
    if not found or v_player.registration_status<>'registered' or v_player.is_banned then
      raise exception 'Only registered, eligible players can join a team';
    end if;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('membership-location:'||v_membership.user_id::text||':'||v_location_id::text,0)
  );

  select * into v_membership from public.team_memberships
  where id=p_membership_id and status='pending' for update;
  if not found then raise exception 'No pending team request exists'; end if;

  if p_decision='approved' then
    if exists(
      select 1
      from public.player_transfer_requests r
      join public.season_teams destination on destination.id=r.destination_season_team_id
      join public.seasons destination_season on destination_season.id=destination.season_id
      join public.leagues destination_league on destination_league.id=destination_season.league_id
      where r.user_id=v_membership.user_id and r.status='pending'
        and destination_league.location_id=v_location_id
    ) then
      raise exception 'This player has a pending transfer request in this area';
    end if;

    if exists(
      select 1
      from public.team_memberships tm
      join public.season_teams other_team on other_team.id=tm.season_team_id
      join public.seasons other_season on other_season.id=other_team.season_id
      join public.leagues other_league on other_league.id=other_season.league_id
      where tm.user_id=v_membership.user_id and tm.status='active'
        and other_season.status in ('registration_open','active')
        and other_league.location_id=v_location_id
        and other_team.team_id<>v_team.team_id
        and tm.id<>v_membership.id
    ) then
      raise exception 'This player is already active at another club in this area';
    end if;
  end if;

  update public.team_memberships set
    status=case when p_decision='approved' then 'active'::public.membership_status else 'rejected'::public.membership_status end,
    joined_at=case when p_decision='approved' then now() else joined_at end,
    left_at=case when p_decision='rejected' then now() else null end
  where id=p_membership_id returning * into v_membership;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'team.membership.'||p_decision,'team_membership',p_membership_id::text,
    jsonb_build_object('status',v_membership.status));

  return v_membership;
end;
$$;

revoke all on function public.resolve_team_membership_request(uuid,text) from public,anon;
grant execute on function public.resolve_team_membership_request(uuid,text) to authenticated;

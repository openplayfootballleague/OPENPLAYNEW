-- Player-led, league-scoped transfers. A player must leave voluntarily before requesting a move.
-- In the final 24 hours before a fixture, unattached players may request every
-- eligible club that has not yet submitted that fixture's locked team sheet.

alter table public.team_memberships
  add column if not exists voluntarily_left_at timestamptz;

alter table public.player_transfer_requests
  alter column source_membership_id drop not null,
  add column if not exists league_id uuid references public.leagues(id) on delete restrict,
  add column if not exists is_emergency boolean not null default false,
  add column if not exists target_fixture_id uuid references public.fixtures(id) on delete set null;

update public.player_transfer_requests r
set league_id=s.league_id
from public.season_teams st
join public.seasons s on s.id=st.season_id
where st.id=r.destination_season_team_id
  and r.league_id is null;

alter table public.player_transfer_requests
  alter column league_id set not null;

-- Requests created under the former "request while still attached" model are
-- not valid under the player-led workflow. Preserve them as cancelled history.
with cancelled_legacy as (
  update public.player_transfer_requests
  set status='cancelled',
      resolved_at=coalesce(resolved_at,now()),
      resolution_reason='Cancelled during transfer policy change; leave your club before requesting a new transfer',
      updated_at=now()
  where status='pending'
  returning id,user_id,source_season_team_id,destination_season_team_id
)
insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
select null,'player.transfer.cancelled_policy_migration','player_transfer_request',id::text,
  'Legacy pending request cancelled during transfer policy change',
  jsonb_build_object('user_id',user_id,'source_team_id',source_season_team_id,'destination_team_id',destination_season_team_id)
from cancelled_legacy;

-- Rejoining or otherwise activating a membership clears the voluntary-leave
-- marker. Only the self-service leave RPC below sets it.
create or replace function public.clear_voluntary_leave_marker_on_rejoin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status='active' then
    new.voluntarily_left_at:=null;
  end if;
  return new;
end;
$$;

drop trigger if exists team_memberships_clear_voluntary_leave_marker on public.team_memberships;
create trigger team_memberships_clear_voluntary_leave_marker
before insert or update of status on public.team_memberships
for each row
execute function public.clear_voluntary_leave_marker_on_rejoin();

revoke all on function public.clear_voluntary_leave_marker_on_rejoin() from public,anon,authenticated;

drop index if exists public.player_transfer_one_pending_per_source_idx;
create unique index if not exists player_transfer_one_pending_destination_idx
  on public.player_transfer_requests(user_id,league_id,destination_season_team_id)
  where status='pending';
create index if not exists player_transfer_pending_player_league_idx
  on public.player_transfer_requests(user_id,league_id,requested_at desc)
  where status='pending';

comment on column public.player_transfer_requests.source_membership_id is
  'Historical membership the player voluntarily left before requesting this transfer; nullable for retained/anonymised history.';
comment on column public.player_transfer_requests.league_id is
  'League scope for the transfer; active membership exclusivity and pending requests are enforced across every season in this league.';
comment on column public.player_transfer_requests.is_emergency is
  'True only when requested in the 24 hours before the destination club fixture kickoff while its team sheet is not submitted.';
comment on column public.player_transfer_requests.target_fixture_id is
  'Upcoming fixture that made the destination eligible for an emergency transfer request.';

-- All membership and transfer mutations must pass through the audited RPCs;
-- direct client table writes cannot bypass the league-level transaction rules.
revoke insert,update,delete on public.team_memberships from anon,authenticated;
revoke insert,update,delete on public.player_transfer_requests from anon,authenticated;
revoke insert,update,delete on public.fixture_team_sheets from anon,authenticated;
revoke insert,update,delete on public.fixture_team_sheet_players from anon,authenticated;

-- One active club per player per league, including across different seasons.
create or replace function public.enforce_one_active_club_per_player_per_league()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_league_id uuid;
  v_club_id uuid;
begin
  if new.status <> 'active' then
    return new;
  end if;

  select s.league_id,st.team_id
    into v_league_id,v_club_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  where st.id=new.season_team_id;

  if v_league_id is null then
    raise exception 'Membership team must belong to a league';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.user_id::text || ':' || v_league_id::text, 0)
  );

  if exists (
    select 1
    from public.team_memberships tm
    join public.season_teams other_team on other_team.id=tm.season_team_id
    join public.seasons other_season on other_season.id=other_team.season_id
    where tm.user_id=new.user_id
      and tm.status='active'
      and other_season.league_id=v_league_id
      and other_team.team_id is distinct from v_club_id
      and tm.id is distinct from new.id
  ) then
    raise exception 'A player can represent only one club in the same league at a time';
  end if;

  if exists (
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
create trigger team_memberships_one_active_club_per_league
before insert or update of status,season_team_id,user_id
on public.team_memberships
for each row
execute function public.enforce_one_active_club_per_player_per_league();

revoke all on function public.enforce_one_active_club_per_player_per_league() from public,anon,authenticated;

-- Do not silently grandfather an already-invalid multi-club league membership.
-- Same-club memberships in overlapping seasons are allowed; different clubs are not.
do $$
begin
  if exists (
    select tm.user_id,s.league_id
    from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    where tm.status='active'
    group by tm.user_id,s.league_id
    having count(distinct st.team_id)>1
  ) then
    raise exception 'Resolve existing players attached to multiple clubs in one league before applying player transfer safeguards';
  end if;
end;
$$;

-- A captain may save/edit drafts up to kickoff. A submitted sheet is locked.
create or replace function public.enforce_team_sheet_before_kickoff()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scheduled_at timestamptz;
  v_status public.fixture_status;
begin
  if coalesce(pg_catalog.current_setting('request.jwt.claim.role', true), '')='service_role' then
    return new;
  end if;

  select f.scheduled_at,f.status
    into v_scheduled_at,v_status
  from public.fixtures f
  where f.id=new.fixture_id
  for update;

  if not found then
    raise exception 'Fixture not found';
  end if;

  if v_status='in_progress' or (v_status='scheduled' and v_scheduled_at is not null and v_scheduled_at<=now()) then
    raise exception 'Team sheets can only be edited, saved or submitted before kickoff';
  end if;

  return new;
end;
$$;

drop trigger if exists fixture_team_sheets_before_kickoff_guard on public.fixture_team_sheets;
create trigger fixture_team_sheets_before_kickoff_guard
before insert or update on public.fixture_team_sheets
for each row
execute function public.enforce_team_sheet_before_kickoff();

revoke all on function public.enforce_team_sheet_before_kickoff() from public,anon,authenticated;

-- If a destination captain submits their sheet after receiving an emergency
-- request, that club is no longer eligible. Expire its outstanding requests.
create or replace function public.expire_emergency_transfers_on_sheet_submission()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_locked is distinct from true then
    return new;
  end if;

  with expired as (
    update public.player_transfer_requests r
    set status='cancelled',
        resolved_at=now(),
        resolved_by=auth.uid(),
        resolution_reason='Destination club submitted its matchday team sheet; emergency request expired',
        updated_at=now()
    where r.status='pending'
      and r.is_emergency=true
      and r.target_fixture_id=new.fixture_id
      and r.destination_season_team_id=new.season_team_id
    returning r.id,r.user_id
  )
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  select auth.uid(),'player.transfer.expired_after_sheet_submission',
    'player_transfer_request',expired.id::text,
    'Destination club submitted its matchday team sheet',
    jsonb_build_object('user_id',expired.user_id,'fixture_id',new.fixture_id,'season_team_id',new.season_team_id)
  from expired;

  return new;
end;
$$;

drop trigger if exists fixture_team_sheets_expire_emergency_transfers on public.fixture_team_sheets;
create trigger fixture_team_sheets_expire_emergency_transfers
after insert or update of is_locked on public.fixture_team_sheets
for each row
execute function public.expire_emergency_transfers_on_sheet_submission();

revoke all on function public.expire_emergency_transfers_on_sheet_submission() from public,anon,authenticated;

-- A player leaves their own club; no old captain/admin decision is involved.
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
begin
  if v_user is null then raise exception 'Authentication required'; end if;

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

  if exists (
    select 1
    from public.fixture_team_sheet_players tsp
    join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true
    join public.fixtures f on f.id=ts.fixture_id
    where tsp.user_id=v_user
      and ts.season_team_id=v_membership.season_team_id
      and f.status in ('scheduled','in_progress')
  ) then
    raise exception 'You are on a submitted sheet for a fixture that has not been completed. Ask an administrator to amend it before leaving';
  end if;

  select name into v_team_name from public.season_teams where id=v_membership.season_team_id;

  update public.team_memberships
  set status='left',left_at=now(),voluntarily_left_at=now(),squad_number=null,updated_at=now()
  where id=v_membership.id
  returning * into v_membership;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_user,'player.membership.left','team_membership',v_membership.id::text,
    'Voluntary departure by player',
    jsonb_build_object('status','active','season_team_id',v_membership.season_team_id),
    jsonb_build_object('status','left','season_team_id',v_membership.season_team_id));

  perform public.enqueue_notification_event(
    v_user,'team.membership_left',
    jsonb_build_object('team_name',coalesce(v_team_name,'your club'),'changed_at',now())
  );

  return v_membership;
end;
$$;

revoke all on function public.leave_team_membership(uuid) from public,anon;
grant execute on function public.leave_team_membership(uuid) to authenticated;

-- Return destinations in leagues where this player has a prior left membership.
-- When any fixture in a season is within 24 hours, only teams with an unsubmitted
-- team sheet for a fixture in that window are returned.
drop function if exists public.get_my_transfer_destinations();
create function public.get_my_transfer_destinations()
returns table(
  source_membership_id uuid,
  source_team_id uuid,
  source_team_name text,
  league_id uuid,
  league_name text,
  season_id uuid,
  season_name text,
  destination_team_id uuid,
  destination_team_name text,
  emergency_window boolean,
  target_fixture_id uuid,
  target_fixture_scheduled_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists(
    select 1 from public.players p
    where p.user_id=v_user and p.registration_status='registered' and p.is_banned=false
  ) then
    return;
  end if;

  return query
  with player_leagues as (
    select distinct on (s.league_id)
      s.league_id,l.name as league_name,tm.id as source_membership_id,
      st.team_id as source_team_id,st.name as source_team_name
    from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where tm.user_id=v_user and tm.status='left' and tm.voluntarily_left_at is not null
    order by s.league_id,tm.left_at desc nulls last,tm.updated_at desc
  ),
  candidate_teams as (
    select pl.*,s.id as season_id,s.name as season_name,s.status as season_status,
      dest.id as destination_team_id,dest.name as destination_team_name,dest.team_id as destination_club_id
    from player_leagues pl
    join public.seasons s on s.league_id=pl.league_id and s.status in ('registration_open','active')
    join public.season_teams dest on dest.season_id=s.id and dest.registration_status='approved'
    where dest.team_id<>pl.source_team_id
      and not exists (
        select 1 from public.team_memberships active_tm
        join public.season_teams active_st on active_st.id=active_tm.season_team_id
        join public.seasons active_s on active_s.id=active_st.season_id
        where active_tm.user_id=v_user and active_tm.status='active'
          and active_s.league_id=pl.league_id
      )
      and not exists (
        select 1 from public.team_memberships pending_tm
        join public.season_teams pending_st on pending_st.id=pending_tm.season_team_id
        join public.seasons pending_s on pending_s.id=pending_st.season_id
        where pending_tm.user_id=v_user and pending_tm.status='pending'
          and pending_s.league_id=pl.league_id
      )
  ),
  candidates_with_fixture as (
    select c.*,
      eligible.id as target_fixture_id,
      eligible.scheduled_at as target_fixture_scheduled_at
    from candidate_teams c
    left join lateral (
      select f.id,f.scheduled_at
      from public.fixtures f
      where f.season_id=c.season_id
        and c.destination_team_id in (f.home_team_id,f.away_team_id)
        and f.status='scheduled'
        and f.scheduled_at>now()
        and f.scheduled_at<=now()+interval '24 hours'
        and not exists (
          select 1 from public.fixture_team_sheets submitted
          where submitted.fixture_id=f.id
            and submitted.season_team_id=c.destination_team_id
            and submitted.is_locked=true
        )
      order by f.scheduled_at
      limit 1
    ) eligible on true
  ),
  season_modes as (
    select c.league_id,
      bool_or(c.target_fixture_id is not null) as emergency_open,
      coalesce(bool_or(r.status='pending' and r.is_emergency and exists(
        select 1 from public.fixtures pending_fixture
        where pending_fixture.id=r.target_fixture_id
          and pending_fixture.status='scheduled'
          and pending_fixture.scheduled_at>now()
          and pending_fixture.scheduled_at<=now()+interval '24 hours'
          and not exists(
            select 1 from public.fixture_team_sheets pending_sheet
            where pending_sheet.fixture_id=pending_fixture.id
              and pending_sheet.season_team_id=r.destination_season_team_id
              and pending_sheet.is_locked=true
          )
      )),false) as has_emergency_request,
      coalesce(bool_or(r.status='pending' and not r.is_emergency),false) as has_normal_request
    from candidates_with_fixture c
    left join public.player_transfer_requests r
      on r.user_id=v_user and r.league_id=c.league_id and r.status='pending'
    group by c.league_id
  )
  select c.source_membership_id,c.source_team_id,c.source_team_name,
    c.league_id,c.league_name,c.season_id,c.season_name,
    c.destination_team_id,c.destination_team_name,
    (c.target_fixture_id is not null),c.target_fixture_id,c.target_fixture_scheduled_at
  from candidates_with_fixture c
  join season_modes m on m.league_id=c.league_id
  where (
    (
      (m.emergency_open or m.has_emergency_request)
      and c.target_fixture_id is not null
      and not m.has_normal_request
    )
    or
    (
      not m.emergency_open
      and not m.has_emergency_request
      and not m.has_normal_request
    )
  )
  order by c.league_name,c.season_name,c.destination_team_name;
end;
$$;

revoke all on function public.get_my_transfer_destinations() from public,anon;
grant execute on function public.get_my_transfer_destinations() to authenticated;

drop function if exists public.get_my_transfer_requests();
create function public.get_my_transfer_requests()
returns table(
  id uuid,source_team_name text,destination_team_name text,
  season_name text,reason text,status text,requested_at timestamptz,
  resolved_at timestamptz,resolution_reason text,is_emergency boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  return query
  select r.id,coalesce(src.name,'Unattached'),dst.name,se.name,r.reason,
    r.status,r.requested_at,r.resolved_at,r.resolution_reason,r.is_emergency
  from public.player_transfer_requests r
  left join public.season_teams src on src.id=r.source_season_team_id
  join public.season_teams dst on dst.id=r.destination_season_team_id
  join public.seasons se on se.id=dst.season_id
  where r.user_id=v_user
  order by r.requested_at desc;
end;
$$;

revoke all on function public.get_my_transfer_requests() from public,anon;
grant execute on function public.get_my_transfer_requests() to authenticated;

-- Request creation is player-only. A normal request is exclusive per league;
-- the emergency window permits multiple destinations, but only eligible clubs.
drop function if exists public.request_player_transfer(uuid,uuid,text);
create function public.request_player_transfer(
  p_destination_season_team_id uuid,
  p_reason text
)
returns public.player_transfer_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid:=auth.uid();
  v_destination public.season_teams;
  v_season public.seasons;
  v_league public.leagues;
  v_source public.team_memberships;
  v_fixture public.fixtures;
  v_emergency_open boolean:=false;
  v_request public.player_transfer_requests;
  v_has_pending boolean:=false;
  v_has_normal_pending boolean:=false;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then
    raise exception 'Enter a transfer reason of at least 5 characters';
  end if;

  select * into v_destination
  from public.season_teams
  where id=p_destination_season_team_id
  for share;
  if not found or v_destination.registration_status<>'approved' then
    raise exception 'Destination club is not approved';
  end if;

  select * into v_season from public.seasons where id=v_destination.season_id for share;
  if not found or v_season.status not in ('registration_open','active') then
    raise exception 'Transfers are closed for this season';
  end if;

  select * into v_league from public.leagues where id=v_season.league_id;
  if not found then raise exception 'Destination league was not found'; end if;

  if not exists(
    select 1 from public.players p
    where p.user_id=v_user and p.registration_status='registered' and p.is_banned=false
  ) then
    raise exception 'Only registered, non-banned players can request a transfer';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user::text || ':' || v_league.id::text,0)
  );

  -- Emergency requests expire when their fixture window closes or the
  -- destination submits its sheet. Clear those stale requests before allowing a
  -- new ordinary request in the same league.
  update public.player_transfer_requests r
  set status='cancelled',resolved_at=now(),resolved_by=v_user,
      resolution_reason='Emergency transfer window closed before approval',
      updated_at=now()
  where r.user_id=v_user and r.league_id=v_league.id
    and r.status='pending' and r.is_emergency
    and not exists(
      select 1 from public.fixtures pending_fixture
      where pending_fixture.id=r.target_fixture_id
        and pending_fixture.status='scheduled'
        and pending_fixture.scheduled_at>now()
        and pending_fixture.scheduled_at<=now()+interval '24 hours'
        and not exists(
          select 1 from public.fixture_team_sheets pending_sheet
          where pending_sheet.fixture_id=pending_fixture.id
            and pending_sheet.season_team_id=r.destination_season_team_id
            and pending_sheet.is_locked=true
        )
    );

  if exists(
    select 1 from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    where tm.user_id=v_user and tm.status='active' and s.league_id=v_league.id
  ) then
    raise exception 'Leave your current club in this league before requesting a transfer';
  end if;

  if exists(
    select 1 from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    where tm.user_id=v_user and tm.status='pending' and s.league_id=v_league.id
  ) then
    raise exception 'Resolve your pending team request in this league before requesting a transfer';
  end if;

  select tm.* into v_source
  from public.team_memberships tm
  join public.season_teams source_team on source_team.id=tm.season_team_id
  join public.seasons source_season on source_season.id=source_team.season_id
  where tm.user_id=v_user and tm.status='left' and tm.voluntarily_left_at is not null and source_season.league_id=v_league.id
  order by tm.left_at desc nulls last,tm.updated_at desc
  limit 1
  for share of tm;

  if not found then
    raise exception 'You must first have been a member of a club in this league and leave it voluntarily';
  end if;

  if v_source.is_captain then
    raise exception 'Appoint a replacement captain before requesting a transfer';
  end if;

  if exists(
    select 1 from public.season_teams source_team
    where source_team.id=v_source.season_team_id
      and source_team.team_id=v_destination.team_id
  ) then
    raise exception 'Choose a different club from the one you left';
  end if;

  select exists(
    select 1
    from public.fixtures f
    join public.season_teams participant
      on participant.id in (f.home_team_id,f.away_team_id)
    join public.seasons participant_season on participant_season.id=f.season_id
    where participant_season.league_id=v_league.id
      and participant_season.status in ('registration_open','active')
      and participant.registration_status='approved'
      and f.status='scheduled'
      and f.scheduled_at>now()
      and f.scheduled_at<=now()+interval '24 hours'
      and not exists(
        select 1 from public.fixture_team_sheets ts
        where ts.fixture_id=f.id and ts.season_team_id=participant.id and ts.is_locked=true
      )
  ) into v_emergency_open;

  select exists(
    select 1 from public.player_transfer_requests r
    where r.user_id=v_user and r.league_id=v_league.id and r.status='pending'
  ) into v_has_pending;

  select exists(
    select 1 from public.player_transfer_requests r
    where r.user_id=v_user and r.league_id=v_league.id
      and r.status='pending' and not r.is_emergency
  ) into v_has_normal_pending;

  if v_emergency_open then
    if v_has_normal_pending then
      raise exception 'A normal transfer request is already pending in this league';
    end if;
    select f.* into v_fixture
    from public.fixtures f
    where f.season_id=v_season.id
      and v_destination.id in (f.home_team_id,f.away_team_id)
      and f.status='scheduled'
      and f.scheduled_at>now()
      and f.scheduled_at<=now()+interval '24 hours'
      and not exists(
        select 1 from public.fixture_team_sheets ts
        where ts.fixture_id=f.id and ts.season_team_id=v_destination.id and ts.is_locked=true
      )
    order by f.scheduled_at
    limit 1;
    if not found then
      raise exception 'This club has already submitted its matchday team sheet or is not eligible for an emergency transfer';
    end if;
  elsif v_has_pending then
    raise exception 'You already have a pending transfer request in this league';
  end if;

  insert into public.player_transfer_requests(
    user_id,source_membership_id,source_season_team_id,destination_season_team_id,
    league_id,reason,is_emergency,target_fixture_id
  ) values(
    v_user,v_source.id,v_source.season_team_id,v_destination.id,
    v_league.id,btrim(p_reason),v_emergency_open,v_fixture.id
  )
  returning * into v_request;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  values(v_user,'player.transfer.requested','player_transfer_request',v_request.id::text,btrim(p_reason),
    jsonb_build_object(
      'source_team_id',v_source.season_team_id,
      'destination_team_id',v_destination.id,
      'league_id',v_league.id,
      'is_emergency',v_emergency_open,
      'target_fixture_id',v_fixture.id
    ));

  return v_request;
end;
$$;

revoke all on function public.request_player_transfer(uuid,text) from public,anon;
grant execute on function public.request_player_transfer(uuid,text) to authenticated;

create or replace function public.cancel_player_transfer_request(p_request_id uuid)
returns public.player_transfer_requests
language plpgsql
security definer
set search_path = ''
as $$
declare v_user uuid:=auth.uid(); v_request public.player_transfer_requests;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_request from public.player_transfer_requests
  where id=p_request_id and user_id=v_user;
  if not found then raise exception 'Transfer request not found'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user::text || ':' || v_request.league_id::text,0)
  );
  select * into v_request from public.player_transfer_requests
  where id=p_request_id and user_id=v_user for update;
  if not found then raise exception 'Transfer request not found'; end if;
  if v_request.status<>'pending' then raise exception 'Only pending transfer requests can be cancelled'; end if;

  update public.player_transfer_requests
  set status='cancelled',resolved_at=now(),resolved_by=v_user,
      resolution_reason='Cancelled by player',updated_at=now()
  where id=p_request_id returning * into v_request;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_user,'player.transfer.cancelled','player_transfer_request',p_request_id::text,
    'Cancelled by player',jsonb_build_object('status','pending'),jsonb_build_object('status','cancelled'));

  return v_request;
end;
$$;

revoke all on function public.cancel_player_transfer_request(uuid) from public,anon;
grant execute on function public.cancel_player_transfer_request(uuid) to authenticated;

-- Captain approval is first-wins. The league advisory lock serialises approvals;
-- the winner activates membership and cancels every competing pending request.
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
  v_destination public.season_teams;
  v_season public.seasons;
  v_player public.players;
  v_cancelled integer:=0;
  v_membership public.team_memberships;
begin
  if p_actor is null then raise exception 'Authentication required'; end if;
  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;
  if p_reason is null or length(btrim(p_reason))<5 then
    raise exception 'Enter a decision reason of at least 5 characters';
  end if;

  select * into v_request
  from public.player_transfer_requests
  where id=p_request_id;
  if not found then raise exception 'Transfer request not found'; end if;

  if v_request.user_id is null then raise exception 'The transfer request no longer belongs to an active player account'; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_request.user_id::text || ':' || v_request.league_id::text,0)
  );

  -- Acquire the request row only after the player/league lock. This avoids a
  -- deadlock when competing approvals must cancel each other's request rows.
  select * into v_request
  from public.player_transfer_requests
  where id=p_request_id
  for update;
  if not found or v_request.status<>'pending' then
    raise exception 'This transfer has already been resolved or secured by another club';
  end if;

  select * into v_destination from public.season_teams
  where id=v_request.destination_season_team_id for share;
  if not found or v_destination.registration_status<>'approved' then
    raise exception 'Destination club is no longer approved';
  end if;

  select * into v_season from public.seasons
  where id=v_destination.season_id for share;
  if not found or v_season.league_id<>v_request.league_id
     or v_season.status not in ('registration_open','active') then
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
    select 1
    from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    where tm.user_id=v_request.user_id and tm.status='active'
      and s.league_id=v_request.league_id
  ) then
    raise exception 'Player is already attached to a club in this league';
  end if;

  if p_decision='approved' then
    if v_request.is_emergency then
      if v_request.target_fixture_id is null or not exists(
        select 1 from public.fixtures f
        where f.id=v_request.target_fixture_id
          and f.season_id=v_destination.season_id
          and v_destination.id in (f.home_team_id,f.away_team_id)
          and f.status='scheduled'
          and f.scheduled_at>now()
          and f.scheduled_at<=now()+interval '24 hours'
          and not exists(
            select 1 from public.fixture_team_sheets ts
            where ts.fixture_id=f.id and ts.season_team_id=v_destination.id and ts.is_locked=true
          )
      ) then
        raise exception 'The emergency transfer window for this fixture has closed';
      end if;
    end if;

    -- Mark the winner first, then cancel every competing request in this
    -- league before the active-membership trigger checks the new membership.
    update public.player_transfer_requests
    set status='approved',resolved_at=now(),resolved_by=p_actor,
        resolution_reason=btrim(p_reason),updated_at=now()
    where id=p_request_id returning * into v_request;

    update public.player_transfer_requests
    set status='cancelled',resolved_at=now(),resolved_by=p_actor,
        resolution_reason='Automatically cancelled because another club secured the player',
        updated_at=now()
    where user_id=v_request.user_id
      and league_id=v_request.league_id
      and status='pending'
      and id<>p_request_id;
    get diagnostics v_cancelled=row_count;

    insert into public.team_memberships(
      season_team_id,user_id,status,is_captain,squad_number,joined_at,left_at,transfer_request_id
    ) values(
      v_destination.id,v_request.user_id,'active',false,null,now(),null,v_request.id
    )
    on conflict(season_team_id,user_id) do update
      set status='active',is_captain=false,squad_number=null,joined_at=now(),
          left_at=null,voluntarily_left_at=null,transfer_request_id=v_request.id,updated_at=now()
      where public.team_memberships.status in ('left','rejected')
    returning * into v_membership;

    if v_membership.id is null then
      raise exception 'The destination already has an active or pending membership for this player';
    end if;
  else
    update public.player_transfer_requests
    set status='rejected',resolved_at=now(),resolved_by=p_actor,
        resolution_reason=btrim(p_reason),updated_at=now()
    where id=p_request_id returning * into v_request;
  end if;

  perform public.enqueue_notification_event(
    v_request.user_id,
    case when p_decision='approved' then 'player.transfer_approved' else 'player.transfer_rejected' end,
    jsonb_build_object(
      'transfer_request_id',v_request.id,
      'source_team_name',(select name from public.season_teams where id=v_request.source_season_team_id),
      'team_name',v_destination.name,
      'reason',btrim(p_reason),
      'changed_at',now(),
      'is_emergency',v_request.is_emergency
    )
  );

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(p_actor,'player.transfer.'||p_decision,'player_transfer_request',p_request_id::text,btrim(p_reason),
    jsonb_build_object('status','pending','league_id',v_request.league_id),
    jsonb_build_object(
      'status',p_decision,'destination_team_id',v_destination.id,
      'cancelled_competing_requests',v_cancelled,'admin_override',p_admin_override
    ));

  return v_request;
end;
$$;

revoke all on function public._resolve_player_transfer_request(uuid,text,text,uuid,boolean) from public,anon,authenticated;

create or replace function public.resolve_player_transfer_request(
  p_request_id uuid,p_decision text,p_reason text
)
returns public.player_transfer_requests
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public._resolve_player_transfer_request(p_request_id,p_decision,p_reason,auth.uid(),false);
end;
$$;

revoke all on function public.resolve_player_transfer_request(uuid,text,text) from public,anon;
grant execute on function public.resolve_player_transfer_request(uuid,text,text) to authenticated;

create or replace function public.admin_resolve_player_transfer_request(
  p_request_id uuid,p_decision text,p_reason text
)
returns public.player_transfer_requests
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  return public._resolve_player_transfer_request(p_request_id,p_decision,p_reason,auth.uid(),true);
end;
$$;

revoke all on function public.admin_resolve_player_transfer_request(uuid,text,text) from public,anon;
grant execute on function public.admin_resolve_player_transfer_request(uuid,text,text) to authenticated;

create or replace function public.get_captain_transfer_requests()
returns table(
  id uuid,user_id uuid,player_name text,source_team_name text,
  destination_season_team_id uuid,destination_team_name text,
  league_name text,season_name text,reason text,status text,
  requested_at timestamptz,is_emergency boolean,target_fixture_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if not exists(
    select 1 from public.team_memberships tm
    where tm.user_id=v_actor and tm.is_captain=true and tm.status='active'
  ) then raise exception 'Active captain permission required'; end if;

  return query
  select r.id,r.user_id,p.full_name,coalesce(src.name,'Unattached'),
    dst.id,dst.name,l.name,se.name,r.reason,r.status,r.requested_at,
    r.is_emergency,r.target_fixture_id
  from public.player_transfer_requests r
  join public.players p on p.user_id=r.user_id
  left join public.season_teams src on src.id=r.source_season_team_id
  join public.season_teams dst on dst.id=r.destination_season_team_id
  join public.seasons se on se.id=dst.season_id
  join public.leagues l on l.id=se.league_id
  join public.team_memberships captain
    on captain.season_team_id=dst.id and captain.user_id=v_actor
      and captain.is_captain=true and captain.status='active'
  where r.status='pending'
  order by r.is_emergency desc,r.requested_at;
end;
$$;

revoke all on function public.get_captain_transfer_requests() from public,anon;
grant execute on function public.get_captain_transfer_requests() to authenticated;

create or replace function public.admin_get_transfer_requests(p_status text default 'pending')
returns table(
  id uuid,user_id uuid,player_name text,source_membership_id uuid,
  source_team_name text,destination_team_id uuid,destination_team_name text,
  season_name text,league_name text,reason text,status text,requested_at timestamptz
)
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
  if p_status is not null and p_status not in ('all','pending','approved','rejected','cancelled') then
    raise exception 'Invalid transfer status filter';
  end if;

  return query
  select r.id,r.user_id,p.full_name,r.source_membership_id,
    coalesce(src.name,'Unattached'),dst.id,dst.name,se.name,l.name,
    r.reason,r.status,r.requested_at
  from public.player_transfer_requests r
  left join public.players p on p.user_id=r.user_id
  left join public.season_teams src on src.id=r.source_season_team_id
  join public.season_teams dst on dst.id=r.destination_season_team_id
  join public.seasons se on se.id=dst.season_id
  join public.leagues l on l.id=se.league_id
  where p_status is null or p_status='all' or r.status=p_status
  order by case when r.status='pending' then 0 else 1 end,r.requested_at desc;
end;
$$;

revoke all on function public.admin_get_transfer_requests(text) from public,anon;
grant execute on function public.admin_get_transfer_requests(text) to authenticated;

create or replace function public.admin_get_transfer_requests_contextual(
  p_status text default 'pending',
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null
)
returns table(
  id uuid,user_id uuid,player_name text,source_membership_id uuid,
  source_team_name text,destination_team_id uuid,destination_team_name text,
  season_name text,league_name text,reason text,status text,requested_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_location uuid:=p_location_id;
  v_league uuid:=p_league_id;
  v_season uuid:=p_season_id;
  v_league_location uuid;
  v_season_league uuid;
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_status is not null and p_status not in ('all','pending','approved','rejected','cancelled') then
    raise exception 'Invalid transfer status filter';
  end if;

  if v_season is not null then
    select s.league_id into v_season_league from public.seasons s where s.id=v_season;
    if v_season_league is null then raise exception 'Selected season was not found'; end if;
    if v_league is not null and v_league<>v_season_league then
      raise exception 'Season does not belong to selected league';
    end if;
    v_league:=v_season_league;
  end if;

  if v_league is not null then
    select l.location_id into v_league_location from public.leagues l where l.id=v_league;
    if v_league_location is null then raise exception 'Selected league was not found'; end if;
    if v_location is not null and v_location<>v_league_location then
      raise exception 'League does not belong to selected location';
    end if;
    v_location:=v_league_location;
  end if;

  if v_location is not null and not exists(select 1 from public.locations where id=v_location) then
    raise exception 'Selected location was not found';
  end if;

  return query
  select r.id,r.user_id,p.full_name,r.source_membership_id,
    coalesce(src.name,'Unattached'),dst.id,dst.name,se.name,l.name,
    r.reason,r.status,r.requested_at
  from public.player_transfer_requests r
  left join public.players p on p.user_id=r.user_id
  left join public.season_teams src on src.id=r.source_season_team_id
  join public.season_teams dst on dst.id=r.destination_season_team_id
  join public.seasons se on se.id=dst.season_id
  join public.leagues l on l.id=se.league_id
  where (p_status is null or p_status='all' or r.status=p_status)
    and (v_location is null or l.location_id=v_location)
    and (v_league is null or l.id=v_league)
    and (v_season is null or se.id=v_season)
  order by case when r.status='pending' then 0 else 1 end,r.requested_at desc;
end;
$$;

revoke all on function public.admin_get_transfer_requests_contextual(text,uuid,uuid,uuid) from public,anon;
grant execute on function public.admin_get_transfer_requests_contextual(text,uuid,uuid,uuid) to authenticated;

-- Ensure a standard team-joining approval cannot bypass a pending transfer.
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
  where id=p_membership_id and status='pending' for update;
  if not found then raise exception 'No pending team request exists'; end if;

  select l.location_id into v_location_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=v_membership.season_team_id;

  if not public.has_platform_role()
     and not public.is_active_team_captain(v_membership.season_team_id)
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

    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_membership.user_id::text || ':' || v_season.league_id::text,0)
    );

    if exists(
      select 1 from public.player_transfer_requests r
      where r.user_id=v_membership.user_id and r.league_id=v_season.league_id and r.status='pending'
    ) then
      raise exception 'This player has a pending transfer request in this league';
    end if;

    if exists(
      select 1 from public.team_memberships tm
      join public.season_teams other_team on other_team.id=tm.season_team_id
      join public.seasons other_season on other_season.id=other_team.season_id
      where tm.user_id=v_membership.user_id and tm.status='active'
        and other_season.league_id=v_season.league_id
        and other_team.team_id<>v_team.team_id
        and tm.id<>v_membership.id
    ) then
      raise exception 'This player is already active at another club in this league';
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


-- Keep the ordinary join-request path from creating a parallel request while
-- a transfer is pending, and serialise pending requests across the whole league.
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

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user::text || ':' || v_season.league_id::text,0)
  );

  if exists(
    select 1 from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    where tm.user_id=v_user and tm.status='active' and s.league_id=v_season.league_id
      and st.team_id<>v_team.team_id
  ) then
    raise exception 'You are already attached to a club in this league';
  end if;

  if exists(
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
    select 1 from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    where tm.user_id=v_user and tm.status='pending' and s.league_id=v_season.league_id
  ) then
    raise exception 'You already have a pending team request in this league';
  end if;

  if exists(
    select 1 from public.player_transfer_requests r
    where r.user_id=v_user and r.league_id=v_season.league_id and r.status='pending'
  ) then
    raise exception 'Cancel or resolve your pending transfer request before requesting to join a team';
  end if;

  insert into public.team_memberships(season_team_id,user_id,status)
  values(p_season_team_id,v_user,'pending')
  on conflict(season_team_id,user_id) do update
    set status='pending',left_at=null,voluntarily_left_at=null,joined_at=null,is_captain=false,updated_at=now()
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

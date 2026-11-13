-- Captain-requested membership removal requires the affected player's explicit approval.
-- No captain can directly deactivate another player's membership.

-- Include request identifiers in notification deduplication so a later
-- removal request for the same membership is not suppressed by an older event.
create or replace function public.enqueue_notification_event(
  p_user_id uuid,
  p_event_type text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path=''
as '
declare
  v_preferences public.notification_preferences;
  v_dedupe text;
begin
  if p_user_id is null or p_event_type is null or length(btrim(p_event_type))<3 then return; end if;
  insert into public.notification_preferences(user_id) values(p_user_id)
  on conflict(user_id) do nothing;
  select * into v_preferences from public.notification_preferences where user_id=p_user_id;
  v_dedupe:=p_event_type||'':''||coalesce(
    p_payload->>''request_id'',
    p_payload->>''report_id'',
    p_payload->>''message_id'',
    p_payload->>''fixture_id'',
    p_payload->>''membership_id'',
    p_payload->>''season_team_id'',
    p_payload->>''conversation_id'',
    ''event''
  )||'':''||p_user_id::text;

  if v_preferences.email_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key)
    values(p_user_id,''email'',p_event_type,''queued'',coalesce(p_payload,''{}''::jsonb),v_dedupe||'':email'')
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
  if v_preferences.sms_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key)
    values(p_user_id,''sms'',p_event_type,''queued'',coalesce(p_payload,''{}''::jsonb),v_dedupe||'':sms'')
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
  if v_preferences.in_app_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key,sent_at)
    values(p_user_id,''in_app'',p_event_type,''sent'',coalesce(p_payload,''{}''::jsonb),v_dedupe||'':in_app'',now())
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
end;
'
;
revoke all on function public.enqueue_notification_event(uuid,text,jsonb) from public,anon,authenticated;

create table if not exists public.team_membership_removal_requests (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.team_memberships(id) on delete restrict,
  player_user_id uuid references auth.users(id) on delete set null,
  requested_by uuid references auth.users(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','cancelled')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete set null,
  decision_reason text,
  constraint team_membership_removal_decision_consistency check (
    (status='pending' and decided_at is null and decided_by is null)
    or (status<>'pending' and decided_at is not null)
  )
);

create unique index if not exists team_membership_removal_one_pending_per_membership
  on public.team_membership_removal_requests(membership_id)
  where status='pending';

create index if not exists team_membership_removal_player_pending
  on public.team_membership_removal_requests(player_user_id,created_at desc)
  where status='pending';

alter table public.team_membership_removal_requests enable row level security;
revoke all on public.team_membership_removal_requests from public,anon,authenticated;

comment on table public.team_membership_removal_requests is
  'Captain-initiated removal requests. Membership remains active until the affected player explicitly approves.';

create or replace function public.request_team_membership_removal(p_membership_id uuid)
returns public.team_membership_removal_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_membership public.team_memberships;
  v_team_name text;
  v_league_id uuid;
  v_request public.team_membership_removal_requests;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;

  select * into v_membership
  from public.team_memberships
  where id=p_membership_id;
  if not found then raise exception 'Membership not found'; end if;

  select s.league_id into v_league_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  where st.id=v_membership.season_team_id;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_membership.user_id::text || ':' || coalesce(v_league_id::text,''),0)
  );

  select * into v_membership
  from public.team_memberships
  where id=p_membership_id
  for update;
  if not found or v_membership.status<>'active' then
    raise exception 'Only an active player membership can be considered for removal';
  end if;
  if v_membership.user_id=v_actor then
    raise exception 'Captains cannot use removal requests to remove themselves';
  end if;
  if v_membership.is_captain then
    raise exception 'A captain must appoint a replacement before leaving the club';
  end if;
  if not exists (
    select 1 from public.team_memberships captain
    where captain.season_team_id=v_membership.season_team_id
      and captain.user_id=v_actor
      and captain.is_captain=true
      and captain.status='active'
  ) then
    raise exception 'Only this club''s active captain can request a player removal';
  end if;

  if exists (
    select 1 from public.team_membership_removal_requests r
    where r.membership_id=v_membership.id and r.status='pending'
  ) then
    raise exception 'A removal request is already awaiting this player''s decision';
  end if;

  select name into v_team_name
  from public.season_teams where id=v_membership.season_team_id;

  insert into public.team_membership_removal_requests(membership_id,player_user_id,requested_by)
  values(v_membership.id,v_membership.user_id,v_actor)
  returning * into v_request;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'captain.membership_removal.requested','team_membership',v_membership.id::text,
    'Captain requested removal; player approval required',
    jsonb_build_object('membership_status','active'),
    jsonb_build_object('request_id',v_request.id,'request_status','pending','season_team_id',v_membership.season_team_id));

  perform public.enqueue_notification_event(
    v_membership.user_id,'team.membership_removal_requested',
    jsonb_build_object('request_id',v_request.id,'membership_id',v_membership.id,'team_name',coalesce(v_team_name,'your club'),'requested_at',now())
  );

  return v_request;
end;
$$;

revoke all on function public.request_team_membership_removal(uuid) from public,anon;
grant execute on function public.request_team_membership_removal(uuid) to authenticated;

create or replace function public.respond_team_membership_removal(
  p_request_id uuid,
  p_decision text,
  p_reason text default null
)
returns public.team_membership_removal_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_request public.team_membership_removal_requests;
  v_membership public.team_memberships;
  v_team_name text;
  v_league_id uuid;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;
  if p_reason is not null and length(btrim(p_reason))>500 then
    raise exception 'Decision note must be 500 characters or fewer';
  end if;

  select * into v_request
  from public.team_membership_removal_requests
  where id=p_request_id and player_user_id=v_actor;
  if not found then raise exception 'Removal request not found'; end if;

  select tm.* into v_membership
  from public.team_memberships tm
  where tm.id=v_request.membership_id;
  if not found or v_membership.user_id is distinct from v_actor then
    raise exception 'This removal request no longer belongs to your membership';
  end if;

  select s.league_id,st.name into v_league_id,v_team_name
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  where st.id=v_membership.season_team_id;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_actor::text || ':' || coalesce(v_league_id::text,''),0)
  );

  select tm.* into v_membership
  from public.team_memberships tm
  where tm.id=v_request.membership_id
  for update;
  if not found or v_membership.user_id is distinct from v_actor then
    raise exception 'This removal request no longer belongs to your membership';
  end if;

  select * into v_request
  from public.team_membership_removal_requests
  where id=p_request_id and player_user_id=v_actor
  for update;
  if not found or v_request.status<>'pending' then
    raise exception 'This removal request has already been resolved';
  end if;
  if v_membership.status<>'active' or v_membership.is_captain then
    raise exception 'This membership is no longer eligible for captain-requested removal';
  end if;

  if p_decision='approved' then
    if exists (
      select 1
      from public.fixture_team_sheet_players tsp
      join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true
      join public.fixtures f on f.id=ts.fixture_id
      where tsp.user_id=v_actor
        and ts.season_team_id=v_membership.season_team_id
        and f.status in ('scheduled','in_progress')
    ) then
      raise exception 'You are on a submitted sheet for a fixture that has not been completed. Ask an administrator to amend it before approving removal';
    end if;

    update public.team_memberships
    set status='left',left_at=now(),voluntarily_left_at=now(),
        squad_number=null,updated_at=now()
    where id=v_membership.id and status='active';

    if not found then raise exception 'Membership changed before removal could be approved'; end if;
  end if;

  update public.team_membership_removal_requests
  set status=p_decision,decided_at=now(),decided_by=v_actor,
      decision_reason=nullif(btrim(p_reason), '')
  where id=p_request_id
  returning * into v_request;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'player.membership_removal.'||p_decision,'team_membership',v_membership.id::text,
    coalesce(nullif(btrim(p_reason),''),case when p_decision='approved' then 'Player approved captain-requested removal' else 'Player rejected captain-requested removal' end),
    jsonb_build_object('membership_status','active','request_status','pending'),
    jsonb_build_object('membership_status',case when p_decision='approved' then 'left' else 'active' end,
      'request_status',p_decision,'request_id',v_request.id,'captain_user_id',v_request.requested_by));

  if v_request.requested_by is not null then
    perform public.enqueue_notification_event(
      v_request.requested_by,
      case when p_decision='approved' then 'team.membership_removal_approved' else 'team.membership_removal_rejected' end,
      jsonb_build_object('request_id',v_request.id,'membership_id',v_membership.id,'team_name',coalesce(v_team_name,'your club'),
        'decision_reason',v_request.decision_reason,'changed_at',now())
    );
  end if;

  perform public.enqueue_notification_event(
    v_actor,
    case when p_decision='approved' then 'team.membership_left' else 'team.membership_removal_declined' end,
    jsonb_build_object('request_id',v_request.id,'membership_id',v_membership.id,'team_name',coalesce(v_team_name,'your club'),'changed_at',now())
  );

  return v_request;
end;
$$;

revoke all on function public.respond_team_membership_removal(uuid,text,text) from public,anon;
grant execute on function public.respond_team_membership_removal(uuid,text,text) to authenticated;

create or replace function public.cancel_team_membership_removal_request(p_request_id uuid)
returns public.team_membership_removal_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_request public.team_membership_removal_requests;
  v_membership public.team_memberships;
  v_team_name text;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  select * into v_request
  from public.team_membership_removal_requests
  where id=p_request_id;
  if not found or v_request.status<>'pending' then
    raise exception 'Only pending removal requests can be cancelled';
  end if;

  select * into v_membership
  from public.team_memberships where id=v_request.membership_id;
  if not found then raise exception 'Membership not found'; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(coalesce(v_membership.user_id::text,'') || ':' ||
      coalesce((select s.league_id::text from public.season_teams st join public.seasons s on s.id=st.season_id where st.id=v_membership.season_team_id),''),0)
  );

  select * into v_membership
  from public.team_memberships where id=v_request.membership_id for update;
  if not found then raise exception 'Membership not found'; end if;

  select * into v_request
  from public.team_membership_removal_requests
  where id=p_request_id and status='pending'
  for update;
  if not found then raise exception 'Only pending removal requests can be cancelled'; end if;

  if not exists (
    select 1 from public.team_memberships captain
    where captain.season_team_id=v_membership.season_team_id
      and captain.user_id=v_actor and captain.is_captain=true and captain.status='active'
  ) then
    raise exception 'Only the requesting club''s active captain can cancel this removal request';
  end if;
  if v_request.requested_by is distinct from v_actor then
    raise exception 'Only the captain who submitted this removal request can cancel it';
  end if;

  update public.team_membership_removal_requests
  set status='cancelled',decided_at=now(),decided_by=v_actor,
      decision_reason='Cancelled by requesting captain'
  where id=p_request_id
  returning * into v_request;

  select name into v_team_name from public.season_teams where id=v_membership.season_team_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'captain.membership_removal.cancelled','team_membership',v_membership.id::text,
    'Cancelled by requesting captain',jsonb_build_object('request_status','pending'),
    jsonb_build_object('request_status','cancelled','request_id',v_request.id));

  perform public.enqueue_notification_event(
    v_request.player_user_id,'team.membership_removal_cancelled',
    jsonb_build_object('request_id',v_request.id,'team_name',coalesce(v_team_name,'your club'),'changed_at',now())
  );
  return v_request;
end;
$$;

revoke all on function public.cancel_team_membership_removal_request(uuid) from public,anon;
grant execute on function public.cancel_team_membership_removal_request(uuid) to authenticated;

create or replace function public.get_my_membership_removal_requests()
returns table(
  id uuid,membership_id uuid,team_name text,requested_at timestamptz,status text,
  decided_at timestamptz,decision_reason text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  return query
  select r.id,r.membership_id,st.name,r.created_at,r.status,r.decided_at,r.decision_reason
  from public.team_membership_removal_requests r
  join public.team_memberships tm on tm.id=r.membership_id
  join public.season_teams st on st.id=tm.season_team_id
  where r.player_user_id=v_actor
  order by r.created_at desc;
end;
$$;

revoke all on function public.get_my_membership_removal_requests() from public,anon;
grant execute on function public.get_my_membership_removal_requests() to authenticated;

create or replace function public.get_captain_membership_removal_requests()
returns table(
  id uuid,membership_id uuid,player_user_id uuid,player_name text,team_name text,
  requested_at timestamptz,status text,decided_at timestamptz,decision_reason text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.team_memberships tm
    where tm.user_id=v_actor and tm.is_captain=true and tm.status='active'
  ) then raise exception 'Active captain permission required'; end if;

  return query
  select r.id,r.membership_id,r.player_user_id,p.full_name,st.name,
    r.created_at,r.status,r.decided_at,r.decision_reason
  from public.team_membership_removal_requests r
  join public.team_memberships target on target.id=r.membership_id
  join public.season_teams st on st.id=target.season_team_id
  left join public.players p on p.user_id=r.player_user_id
  join public.team_memberships captain
    on captain.season_team_id=target.season_team_id
    and captain.user_id=v_actor and captain.is_captain=true and captain.status='active'
  order by case when r.status='pending' then 0 else 1 end,r.created_at desc;
end;
$$;

revoke all on function public.get_captain_membership_removal_requests() from public,anon;
grant execute on function public.get_captain_membership_removal_requests() to authenticated;

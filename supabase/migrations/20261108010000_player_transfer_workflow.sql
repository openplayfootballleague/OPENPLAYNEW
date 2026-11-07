create table if not exists public.player_transfer_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  source_membership_id uuid not null references public.team_memberships(id) on delete restrict,
  source_season_team_id uuid not null references public.season_teams(id) on delete restrict,
  destination_season_team_id uuid not null references public.season_teams(id) on delete restrict,
  reason text not null check (length(btrim(reason))>=5),
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete restrict,
  resolution_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_transfer_different_teams check (source_season_team_id<>destination_season_team_id),
  constraint player_transfer_resolution_check check (
    (status='pending' and resolved_at is null and resolved_by is null)
    or (status<>'pending' and resolved_at is not null)
  )
);
create unique index if not exists player_transfer_one_pending_per_source_idx
  on public.player_transfer_requests(user_id,source_membership_id)
  where status='pending';
create index if not exists player_transfer_status_created_idx
  on public.player_transfer_requests(status,requested_at desc);

alter table public.team_memberships
  add column if not exists transfer_request_id uuid
  references public.player_transfer_requests(id) on delete restrict;

alter table public.player_transfer_requests enable row level security;
drop policy if exists player_transfer_requests_select_owner_or_admin on public.player_transfer_requests;
create policy player_transfer_requests_select_owner_or_admin
  on public.player_transfer_requests for select to authenticated
  using (user_id=(select auth.uid()) or public.has_platform_role());
revoke all on public.player_transfer_requests from public,anon;
grant select on public.player_transfer_requests to authenticated;
revoke insert,update,delete on public.player_transfer_requests from authenticated;

create or replace function public.get_my_transfer_destinations()
returns table(
  source_membership_id uuid,source_team_id uuid,source_team_name text,
  season_id uuid,season_name text,league_name text,
  destination_team_id uuid,destination_team_name text
)
language plpgsql stable security definer set search_path = '' as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.players p where p.user_id=v_user and p.registration_status='registered' and p.is_banned=false) then
    raise exception 'Only registered, non-banned players can request a transfer';
  end if;
  return query
  select tm.id,st.id,st.name,se.id,se.name,l.name,dest.id,dest.name
  from public.team_memberships tm
  join public.season_teams st on st.id=tm.season_team_id
  join public.seasons se on se.id=st.season_id
  join public.leagues l on l.id=se.league_id
  join public.season_teams dest on dest.season_id=se.id
    and dest.id<>st.id and dest.registration_status='approved'
  where tm.user_id=v_user and tm.status='active' and tm.is_captain=false
    and se.status in ('registration_open','active')
    and not exists(
      select 1 from public.team_memberships existing
      where existing.user_id=v_user and existing.season_team_id=dest.id
        and existing.status in ('active','pending')
    )
  order by se.name,st.name,dest.name;
end;
$$;

create or replace function public.get_my_transfer_requests()
returns table(
  id uuid,source_team_name text,destination_team_name text,
  season_name text,reason text,status text,requested_at timestamptz,
  resolved_at timestamptz,resolution_reason text
)
language plpgsql stable security definer set search_path = '' as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  return query
  select r.id,src.name,dst.name,se.name,r.reason,r.status,r.requested_at,r.resolved_at,r.resolution_reason
  from public.player_transfer_requests r
  join public.season_teams src on src.id=r.source_season_team_id
  join public.season_teams dst on dst.id=r.destination_season_team_id
  join public.seasons se on se.id=src.season_id
  where r.user_id=v_user
  order by r.requested_at desc;
end;
$$;

create or replace function public.request_player_transfer(
  p_source_membership_id uuid,
  p_destination_season_team_id uuid,
  p_reason text
)
returns public.player_transfer_requests
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid:=auth.uid();
  v_source public.team_memberships;
  v_source_team public.season_teams;
  v_destination public.season_teams;
  v_season public.seasons;
  v_request public.player_transfer_requests;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a transfer reason of at least 5 characters'; end if;
  select * into v_source from public.team_memberships
  where id=p_source_membership_id and user_id=v_user for update;
  if not found or v_source.status<>'active' then raise exception 'You must be an active member of the source team'; end if;
  if v_source.is_captain then raise exception 'A captain must appoint a replacement captain before requesting a transfer'; end if;
  select * into v_source_team from public.season_teams where id=v_source.season_team_id;
  select * into v_destination from public.season_teams where id=p_destination_season_team_id;
  if not found then raise exception 'Destination team not found'; end if;
  if v_source_team.id=v_destination.id then raise exception 'Choose a different destination team'; end if;
  if v_source_team.season_id<>v_destination.season_id then raise exception 'Transfers are limited to teams in the same season'; end if;
  if v_destination.registration_status<>'approved' then raise exception 'Destination team must be approved'; end if;
  select * into v_season from public.seasons where id=v_source_team.season_id;
  if v_season.status not in ('registration_open','active') then raise exception 'Transfers are closed for this season'; end if;
  if not exists(select 1 from public.players p where p.user_id=v_user and p.registration_status='registered' and p.is_banned=false) then
    raise exception 'Only registered, non-banned players can request a transfer';
  end if;
  if exists(select 1 from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id
    where tm.user_id=v_user and st.season_id=v_source_team.season_id and tm.status='active' and tm.id<>v_source.id) then
    raise exception 'Your account has another active membership in this season; contact an administrator';
  end if;
  if exists(select 1 from public.team_memberships tm where tm.user_id=v_user and tm.season_team_id=v_destination.id and tm.status in ('active','pending')) then
    raise exception 'You already have an active or pending membership with the destination team';
  end if;
  if exists(
    select 1 from public.fixture_team_sheet_players tsp
    join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true
    join public.fixtures f on f.id=ts.fixture_id
    where tsp.user_id=v_user and ts.season_team_id=v_source.id
      and f.status='scheduled' and f.scheduled_at>now()
  ) then raise exception 'You are on a locked upcoming team sheet. Ask an administrator to amend it before transferring'; end if;

  insert into public.player_transfer_requests(user_id,source_membership_id,source_season_team_id,destination_season_team_id,reason)
  values(v_user,v_source.id,v_source.season_team_id,v_destination.id,btrim(p_reason))
  returning * into v_request;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  values(v_user,'player.transfer.requested','player_transfer_request',v_request.id::text,btrim(p_reason),
    jsonb_build_object('source_team_id',v_source.season_team_id,'destination_team_id',v_destination.id));
  return v_request;
end;
$$;

create or replace function public.cancel_player_transfer_request(p_request_id uuid)
returns public.player_transfer_requests
language plpgsql security definer set search_path = '' as $$
declare v_user uuid:=auth.uid(); v_request public.player_transfer_requests;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_request from public.player_transfer_requests
  where id=p_request_id and user_id=v_user for update;
  if not found then raise exception 'Transfer request not found'; end if;
  if v_request.status<>'pending' then raise exception 'Only pending transfer requests can be cancelled'; end if;
  update public.player_transfer_requests set status='cancelled',resolved_at=now(),
    resolution_reason='Cancelled by player',updated_at=now()
  where id=p_request_id returning * into v_request;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_user,'player.transfer.cancelled','player_transfer_request',p_request_id::text,
    'Cancelled by player',jsonb_build_object('status','pending'),jsonb_build_object('status','cancelled'));
  return v_request;
end;
$$;

create or replace function public.admin_get_transfer_requests(p_status text default 'pending')
returns table(
  id uuid,user_id uuid,player_name text,source_membership_id uuid,
  source_team_name text,destination_team_id uuid,destination_team_name text,
  season_name text,league_name text,reason text,status text,requested_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_status is not null and p_status not in ('all','pending','approved','rejected','cancelled') then raise exception 'Invalid transfer status filter'; end if;
  return query
  select r.id,r.user_id,p.full_name,r.source_membership_id,src.name,dst.id,dst.name,se.name,l.name,r.reason,r.status,r.requested_at
  from public.player_transfer_requests r
  join public.players p on p.user_id=r.user_id
  join public.season_teams src on src.id=r.source_season_team_id
  join public.season_teams dst on dst.id=r.destination_season_team_id
  join public.seasons se on se.id=src.season_id
  join public.leagues l on l.id=se.league_id
  where p_status is null or p_status='all' or r.status=p_status
  order by case when r.status='pending' then 0 else 1 end,r.requested_at desc;
end;
$$;

create or replace function public.admin_resolve_player_transfer_request(
  p_request_id uuid,p_decision text,p_reason text
)
returns public.player_transfer_requests
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid:=auth.uid();
  v_request public.player_transfer_requests;
  v_source public.team_memberships;
  v_destination public.season_teams;
  v_season public.seasons;
  v_player public.players;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a decision reason of at least 5 characters'; end if;

  select * into v_request from public.player_transfer_requests where id=p_request_id for update;
  if not found then raise exception 'Transfer request not found'; end if;
  if v_request.status<>'pending' then raise exception 'Transfer request has already been resolved'; end if;
  select * into v_source from public.team_memberships where id=v_request.source_membership_id for update;
  if not found or v_source.status<>'active' then raise exception 'Source membership is no longer active'; end if;
  if v_source.is_captain then raise exception 'Appoint a replacement captain before approving this transfer'; end if;
  select * into v_destination from public.season_teams where id=v_request.destination_season_team_id;
  select * into v_season from public.seasons where id=v_destination.season_id;
  select * into v_player from public.players where user_id=v_request.user_id;
  if v_player.registration_status<>'registered' or v_player.is_banned then raise exception 'Player is not currently eligible to transfer'; end if;
  if v_destination.season_id<>(select season_id from public.season_teams where id=v_request.source_season_team_id)
    or v_destination.registration_status<>'approved'
    or v_season.status not in ('registration_open','active') then
    raise exception 'Destination team or season is no longer eligible for transfers';
  end if;
  if exists(
    select 1 from public.fixture_team_sheet_players tsp
    join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true
    join public.fixtures f on f.id=ts.fixture_id
    where tsp.user_id=v_request.user_id and ts.season_team_id=v_source.season_team_id
      and f.status='scheduled' and f.scheduled_at>now()
  ) then raise exception 'Player is on a locked upcoming team sheet; amend it before approving the transfer'; end if;

  if p_decision='approved' then
    update public.team_memberships set status='left',left_at=now(),squad_number=null,updated_at=now()
    where id=v_source.id;
    insert into public.team_memberships(
      season_team_id,user_id,status,is_captain,squad_number,joined_at,left_at,transfer_request_id
    ) values(
      v_destination.id,v_request.user_id,'active',false,null,now(),null,v_request.id
    )
    on conflict(season_team_id,user_id) do update set
      status='active',is_captain=false,squad_number=null,joined_at=now(),left_at=null,
      transfer_request_id=v_request.id,updated_at=now();
  end if;

  update public.player_transfer_requests set status=p_decision,resolved_at=now(),
    resolved_by=v_actor,resolution_reason=btrim(p_reason),updated_at=now()
  where id=p_request_id returning * into v_request;

  perform public.enqueue_notification_event(
    v_request.user_id,
    case when p_decision='approved' then 'player.transfer_approved' else 'player.transfer_rejected' end,
    jsonb_build_object(
      'transfer_request_id',v_request.id,
      'source_team_name',(select name from public.season_teams where id=v_request.source_season_team_id),
      'team_name',(select name from public.season_teams where id=v_request.destination_season_team_id),
      'reason',btrim(p_reason),
      'changed_at',now()
    )
  );

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'player.transfer.'||p_decision,'player_transfer_request',p_request_id::text,btrim(p_reason),
    jsonb_build_object('status','pending','source_team_id',v_request.source_season_team_id),
    jsonb_build_object('status',p_decision,'destination_team_id',v_request.destination_season_team_id));
  return v_request;
end;
$$;

-- A transfer's destination membership is announced by the transfer RPC itself.
create or replace function public.notify_team_membership_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_team_name text;
begin
  if new.transfer_request_id is null and not new.is_captain and (
    (tg_op='INSERT' and new.status='active') or
    (tg_op='UPDATE' and old.status is distinct from new.status and new.status in ('active','rejected'))
  ) then
    select name into v_team_name from public.season_teams where id=new.season_team_id;
    perform public.enqueue_notification_event(
      new.user_id,
      case when new.status='active' then 'team.membership_approved' else 'team.membership_rejected' end,
      jsonb_build_object('season_team_id',new.season_team_id,'team_name',v_team_name,'membership_id',new.id,'changed_at',now())
    );
  end if;
  return new;
end;
$$;

-- Include transfer IDs in outbox idempotency keys.
create or replace function public.enqueue_notification_event(
  p_user_id uuid,p_event_type text,p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_preferences public.notification_preferences; v_dedupe text;
begin
  if p_user_id is null or p_event_type is null or length(btrim(p_event_type))<3 then return; end if;
  insert into public.notification_preferences(user_id) values(p_user_id) on conflict(user_id) do nothing;
  select * into v_preferences from public.notification_preferences where user_id=p_user_id;
  v_dedupe:=p_event_type||':'||
    coalesce(p_payload->>'fixture_id',p_payload->>'membership_id',p_payload->>'transfer_request_id',p_payload->>'season_team_id','event')||':'||
    coalesce(p_payload->>'scheduled_at',p_payload->>'changed_at','')||':'||p_user_id::text;
  if v_preferences.email_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key)
    values(p_user_id,'email',p_event_type,'queued',coalesce(p_payload,'{}'::jsonb),v_dedupe||':email')
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
  if v_preferences.sms_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key)
    values(p_user_id,'sms',p_event_type,'queued',coalesce(p_payload,'{}'::jsonb),v_dedupe||':sms')
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
  if v_preferences.in_app_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key,sent_at)
    values(p_user_id,'in_app',p_event_type,'sent',coalesce(p_payload,'{}'::jsonb),v_dedupe||':in_app',now())
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
end;
$$;

revoke all on function public.get_my_transfer_destinations() from public,anon;
grant execute on function public.get_my_transfer_destinations() to authenticated;
revoke all on function public.get_my_transfer_requests() from public,anon;
grant execute on function public.get_my_transfer_requests() to authenticated;
revoke all on function public.request_player_transfer(uuid,uuid,text) from public,anon;
grant execute on function public.request_player_transfer(uuid,uuid,text) to authenticated;
revoke all on function public.cancel_player_transfer_request(uuid) from public,anon;
grant execute on function public.cancel_player_transfer_request(uuid) to authenticated;
revoke all on function public.admin_get_transfer_requests(text) from public,anon;
grant execute on function public.admin_get_transfer_requests(text) to authenticated;
revoke all on function public.admin_resolve_player_transfer_request(uuid,text,text) from public,anon;
grant execute on function public.admin_resolve_player_transfer_request(uuid,text,text) to authenticated;
revoke all on function public.notify_team_membership_change() from public,anon,authenticated;

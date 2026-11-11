create or replace function public.admin_resolve_player_transfer_request(
  p_request_id uuid,
  p_decision text,
  p_reason text
)
returns public.player_transfer_requests
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid:=auth.uid();
  v_request public.player_transfer_requests;
  v_source public.team_memberships;
  v_destination public.season_teams;
  v_source_team public.season_teams;
  v_season public.seasons;
  v_player public.players;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;
  if p_reason is null or length(btrim(p_reason))<5 then
    raise exception 'Enter a decision reason of at least 5 characters';
  end if;

  select * into v_request
  from public.player_transfer_requests
  where id=p_request_id
  for update;
  if not found then raise exception 'Transfer request not found'; end if;
  if v_request.status<>'pending' then raise exception 'Transfer request has already been resolved'; end if;

  select * into v_source
  from public.team_memberships
  where id=v_request.source_membership_id
  for update;
  if not found or v_source.status<>'active' then
    raise exception 'Source membership is no longer active';
  end if;
  if v_source.user_id<>v_request.user_id
     or v_source.season_team_id<>v_request.source_season_team_id then
    raise exception 'Transfer source membership does not match the request';
  end if;
  if v_source.is_captain then
    raise exception 'Appoint a replacement captain before approving this transfer';
  end if;

  select * into v_source_team
  from public.season_teams
  where id=v_source.season_team_id;
  if not found then raise exception 'Source team not found'; end if;

  select * into v_destination
  from public.season_teams
  where id=v_request.destination_season_team_id;
  if not found then raise exception 'Destination team not found'; end if;

  select * into v_season
  from public.seasons
  where id=v_destination.season_id;
  if not found then raise exception 'Destination season not found'; end if;

  select * into v_player
  from public.players
  where user_id=v_request.user_id;
  if not found then raise exception 'Player record not found'; end if;
  if v_player.registration_status<>'registered' or v_player.is_banned then
    raise exception 'Player is not currently eligible to transfer';
  end if;

  if v_destination.season_id<>v_source_team.season_id
     or v_destination.registration_status<>'approved'
     or v_season.status not in ('registration_open','active') then
    raise exception 'Destination team or season is no longer eligible for transfers';
  end if;

  if p_decision='approved' then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_request.user_id::text || ':' || v_source_team.season_id::text, 0)
    );

    if exists(
      select 1
      from public.team_memberships tm
      join public.season_teams other_team on other_team.id=tm.season_team_id
      where tm.user_id=v_request.user_id
        and tm.status='active'
        and other_team.season_id=v_source_team.season_id
        and tm.id<>v_source.id
    ) then
      raise exception 'Player has another active team membership in this season; resolve it before transferring';
    end if;

    if exists(
      select 1
      from public.fixture_team_sheet_players tsp
      join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true
      join public.fixtures f on f.id=ts.fixture_id
      where tsp.user_id=v_request.user_id
        and ts.season_team_id=v_source.season_team_id
        and f.status='scheduled'
        and f.scheduled_at>now()
    ) then
      raise exception 'Player is on a locked upcoming team sheet; amend it before approving the transfer';
    end if;

    update public.team_memberships
    set status='left',left_at=now(),squad_number=null,updated_at=now()
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

  update public.player_transfer_requests
  set status=p_decision,resolved_at=now(),resolved_by=v_actor,
      resolution_reason=btrim(p_reason),updated_at=now()
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
$function$;

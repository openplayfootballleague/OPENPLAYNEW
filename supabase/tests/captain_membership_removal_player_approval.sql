-- Captain-requested membership removal is never unilateral.
-- Run only against the disposable local Supabase database in CI.
do $captain_membership_removal$
declare
  v_captain uuid:=gen_random_uuid();
  v_player uuid:=gen_random_uuid();
  v_other_player uuid:=gen_random_uuid();
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_team uuid;
  v_season_team uuid;
  v_membership uuid;
  v_approved_membership uuid;
  v_request uuid;
  v_error text;
begin
  if has_table_privilege('authenticated','public.team_membership_removal_requests','SELECT')
     or has_table_privilege('authenticated','public.team_membership_removal_requests','INSERT')
     or has_table_privilege('authenticated','public.team_membership_removal_requests','UPDATE')
     or has_table_privilege('authenticated','public.team_membership_removal_requests','DELETE')
     or has_table_privilege('authenticated','public.team_memberships','UPDATE') then
    raise exception 'Authenticated users retain direct write/read privileges on protected membership workflow tables';
  end if;

  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_captain,'authenticated','authenticated','ci-removal-captain@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player,'authenticated','authenticated','ci-removal-player@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_other_player,'authenticated','authenticated','ci-removal-other@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_genuine)
  values
    (v_captain,'Removal Test Captain','+447700920001','ci-removal-captain@openplay.invalid',date '1990-01-01','registered',true),
    (v_player,'Removal Test Player','+447700920002','ci-removal-player@openplay.invalid',date '1990-01-02','registered',true),
    (v_other_player,'Removal Test Other','+447700920003','ci-removal-other@openplay.invalid',date '1990-01-03','registered',true);

  insert into public.locations(name,slug,town)
  values('Captain Removal Test Location','captain-removal-test','Bideford')
  returning id into v_location;

  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location,'Captain Removal Test League','captain-removal-test','six_a_side',true)
  returning id into v_league;

  insert into public.seasons(league_id,name,status,is_public)
  values(v_league,'Captain Removal Test Season','active',true)
  returning id into v_season;

  insert into public.teams(created_by) values(v_captain) returning id into v_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_team,v_season,'Captain Removal Test Club','captain-removal-test-club','approved',v_captain)
  returning id into v_season_team;

  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values
    (v_season_team,v_captain,'active',true),
    (v_season_team,v_player,'active',false),
    (v_season_team,v_other_player,'active',false);

  select id into v_membership from public.team_memberships
  where season_team_id=v_season_team and user_id=v_player;
  v_approved_membership:=v_membership;

  -- A player cannot submit a captain request or act on another player's request.
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  begin
    perform public.request_team_membership_removal(v_membership);
    raise exception 'A non-captain was incorrectly allowed to request removal';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'Only this club''s active captain%' then raise; end if;
  end;

  -- Captain creates a request; the target membership remains active.
  perform set_config('request.jwt.claim.sub',v_captain::text,true);
  select (public.request_team_membership_removal(v_membership)).id into v_request;
  if (select status from public.team_memberships where id=v_membership)<>'active'
     or (select status from public.team_membership_removal_requests where id=v_request)<>'pending' then
    raise exception 'Captain request changed membership before player approval';
  end if;
  if not exists(select 1 from public.notification_events where user_id=v_player and event_type='team.membership_removal_requested') then
    raise exception 'Captain removal request did not notify the affected player';
  end if;

  -- Duplicate requests are blocked while the player has a pending decision.
  begin
    perform public.request_team_membership_removal(v_membership);
    raise exception 'Duplicate pending removal request was incorrectly allowed';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'A removal request is already awaiting%' then raise; end if;
  end;

  -- Unrelated user cannot respond, and player can see their own pending request.
  perform set_config('request.jwt.claim.sub',v_other_player::text,true);
  begin
    perform public.respond_team_membership_removal(v_request,'approved',null);
    raise exception 'Unrelated player was incorrectly allowed to approve removal';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'Removal request not found%' then raise; end if;
  end;

  perform set_config('request.jwt.claim.sub',v_player::text,true);
  if not exists(select 1 from public.get_my_membership_removal_requests() where id=v_request and status='pending') then
    raise exception 'Player cannot see their own pending removal request';
  end if;

  -- Rejection preserves the active membership.
  perform public.respond_team_membership_removal(v_request,'rejected','I wish to remain with this club');
  if (select status from public.team_memberships where id=v_membership)<>'active'
     or (select status from public.team_membership_removal_requests where id=v_request)<>'rejected' then
    raise exception 'Player rejection did not preserve the active membership';
  end if;

  -- A new request can be made and explicitly approved by the same player.
  perform set_config('request.jwt.claim.sub',v_captain::text,true);
  select (public.request_team_membership_removal(v_membership)).id into v_request;
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  perform public.respond_team_membership_removal(v_request,'approved',null);

  if not exists(select 1 from public.notification_events where user_id=v_captain and event_type='team.membership_removal_approved') then
    raise exception 'Player approval did not notify the requesting captain';
  end if;
  if (select status from public.team_memberships where id=v_membership)<>'left'
     or (select voluntarily_left_at from public.team_memberships where id=v_membership) is null
     or (select left_at from public.team_memberships where id=v_membership) is null
     or (select squad_number from public.team_memberships where id=v_membership) is not null
     or (select status from public.team_membership_removal_requests where id=v_request)<>'approved' then
    raise exception 'Player approval did not atomically detach the player and retain departure history';
  end if;

  -- A captain cannot request removal of themselves or another captain.
  perform set_config('request.jwt.claim.sub',v_captain::text,true);
  begin
    perform public.request_team_membership_removal(
      (select id from public.team_memberships where season_team_id=v_season_team and user_id=v_captain)
    );
    raise exception 'Captain was incorrectly allowed to request their own removal';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'Captains cannot use removal requests%' then raise; end if;
  end;

  -- Request cancellation is restricted to the captain who created it.
  select id into v_membership from public.team_memberships
  where season_team_id=v_season_team and user_id=v_other_player;
  select (public.request_team_membership_removal(v_membership)).id into v_request;
  perform set_config('request.jwt.claim.sub',v_other_player::text,true);
  begin
    perform public.cancel_team_membership_removal_request(v_request);
    raise exception 'Target player was incorrectly allowed to cancel the captain request';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'Only the requesting club''s active captain%' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub',v_captain::text,true);
  perform public.cancel_team_membership_removal_request(v_request);
  if (select status from public.team_membership_removal_requests where id=v_request)<>'cancelled'
     or (select status from public.team_memberships where id=v_membership)<>'active' then
    raise exception 'Captain cancellation changed membership or failed to close the request';
  end if;

  if not exists(select 1 from public.audit_log where entity_type='team_membership' and entity_id=v_membership::text and action='captain.membership_removal.cancelled')
     or not exists(select 1 from public.audit_log where entity_type='team_membership' and entity_id=v_approved_membership::text and action='player.membership_removal.approved') then
    raise exception 'Membership removal lifecycle audit events are missing';
  end if;
end;
$captain_membership_removal$;

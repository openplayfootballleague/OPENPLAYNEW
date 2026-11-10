-- Secure messaging permissions, membership lifecycle, notifications and moderation.
-- Runs against the disposable local Supabase database created by CI.
do $secure_messaging_platform$
declare
  v_admin uuid:=gen_random_uuid();
  v_captain uuid:=gen_random_uuid();
  v_player_a uuid:=gen_random_uuid();
  v_player_b uuid:=gen_random_uuid();
  v_player_c uuid:=gen_random_uuid();
  v_spammer uuid:=gen_random_uuid();
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_team_one uuid;
  v_team_two uuid;
  v_season_team_one uuid;
  v_season_team_two uuid;
  v_membership_a uuid;
  v_direct uuid;
  v_team_conversation uuid;
  v_support uuid;
  v_broadcast uuid;
  v_message uuid;
  v_message_two uuid;
  v_report uuid;
  v_count integer;
  v_unread bigint;
  v_body text;
  v_failed boolean;
  v_i integer;
begin
  if has_table_privilege('anon','public.message_conversations','SELECT')
     or has_table_privilege('anon','public.messages','SELECT')
     or has_table_privilege('anon','public.message_conversation_participants','SELECT')
     or has_table_privilege('authenticated','public.messages','INSERT')
     or has_table_privilege('authenticated','public.messages','UPDATE')
     or has_table_privilege('authenticated','public.messages','DELETE')
     or has_table_privilege('authenticated','public.message_conversation_participants','INSERT')
     or has_table_privilege('authenticated','public.message_reports','SELECT') then
    raise exception 'Messaging tables expose direct or anonymous privileges';
  end if;

  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-message-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_captain,'authenticated','authenticated','ci-message-captain@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player_a,'authenticated','authenticated','ci-message-player-a@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player_b,'authenticated','authenticated','ci-message-player-b@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player_c,'authenticated','authenticated','ci-message-player-c@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_spammer,'authenticated','authenticated','ci-message-spammer@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.profiles(id,display_name)
  values
    (v_admin,'Messaging Admin'),
    (v_captain,'Messaging Captain'),
    (v_player_a,'Messaging Player A'),
    (v_player_b,'Messaging Player B'),
    (v_player_c,'Messaging Outsider'),
    (v_spammer,'Messaging Spammer')
  on conflict(id) do update set display_name=excluded.display_name;

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
  values
    (v_captain,'Messaging Captain','+447700920001','ci-message-captain@openplay.invalid',date '1990-01-01','registered',false),
    (v_player_a,'Messaging Player A','+447700920002','ci-message-player-a@openplay.invalid',date '1990-01-02','registered',false),
    (v_player_b,'Messaging Player B','+447700920003','ci-message-player-b@openplay.invalid',date '1990-01-03','registered',false),
    (v_player_c,'Messaging Outsider','+447700920004','ci-message-player-c@openplay.invalid',date '1990-01-04','registered',false),
    (v_spammer,'Messaging Spammer','+447700920005','ci-message-spammer@openplay.invalid',date '1990-01-05','registered',false);

  insert into public.user_roles(user_id,role,granted_by)
  values(v_admin,'admin',v_admin);

  select id into v_location from public.locations where is_active=true order by created_at limit 1;
  if v_location is null then raise exception 'Messaging regression requires an active location'; end if;

  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location,'Messaging Test League','ci-messaging-test-league','six_a_side',true)
  returning id into v_league;
  insert into public.seasons(league_id,name,status,is_public)
  values(v_league,'Messaging Test Season','active',true)
  returning id into v_season;

  insert into public.teams(created_by) values(v_captain) returning id into v_team_one;
  insert into public.teams(created_by) values(v_player_c) returning id into v_team_two;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values
    (v_team_one,v_season,'Messaging Test Team','ci-messaging-test-team','approved',v_captain),
    (v_team_two,v_season,'Messaging Other Team','ci-messaging-other-team','approved',v_player_c);
  select id into v_season_team_one from public.season_teams where team_id=v_team_one and season_id=v_season;
  select id into v_season_team_two from public.season_teams where team_id=v_team_two and season_id=v_season;

  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values
    (v_season_team_one,v_captain,'active',true),
    (v_season_team_one,v_player_a,'active',false),
    (v_season_team_one,v_player_b,'active',false),
    (v_season_team_one,v_spammer,'active',false),
    (v_season_team_two,v_player_c,'active',true);

  select id into v_membership_a from public.team_memberships
  where season_team_id=v_season_team_one and user_id=v_player_a;

  select id into v_team_conversation from public.message_conversations
  where kind='team' and season_team_id=v_season_team_one and closed_at is null;
  if v_team_conversation is null then raise exception 'Active team membership did not create its team conversation'; end if;
  select count(*) into v_count from public.message_conversation_participants
  where conversation_id=v_team_conversation and left_at is null;
  if v_count<>4 then raise exception 'Team conversation should include all four active team members; found %',v_count; end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_a::text,'role','authenticated')::text,true);

  v_direct:=public.create_direct_message_conversation(v_player_b);
  v_message:=public.send_message(v_direct,'Hello from Player A');
  select count(*) into v_count from public.search_message_recipients('Messaging Player B',20)
  where user_id=v_player_b;
  if v_count<>1 then raise exception 'Same-team recipient search did not return Player B'; end if;
  select count(*) into v_count from public.search_message_recipients('Messaging Outsider',20)
  where user_id=v_player_c;
  if v_count<>0 then raise exception 'Recipient search exposed a player outside the active team'; end if;

  select unread_count into v_unread
  from public.get_my_message_conversations(50)
  where conversation_id=v_direct;
  if coalesce(v_unread,0)<>0 then raise exception 'Sender should not have unread messages'; end if;

  update public.message_conversation_participants
  set last_read_at=now()-interval '1 minute'
  where conversation_id=v_direct and user_id=v_player_b;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_b::text,'role','authenticated')::text,true);

  select unread_count into v_unread
  from public.get_my_message_conversations(50)
  where conversation_id=v_direct;
  if coalesce(v_unread,0)<>1 then raise exception 'Recipient unread count should be one'; end if;
  perform public.mark_message_conversation_read(v_direct);
  select unread_count into v_unread
  from public.get_my_message_conversations(50)
  where conversation_id=v_direct;
  if coalesce(v_unread,0)<>0 then raise exception 'Mark-read did not clear unread count'; end if;
  select body into v_body from public.get_message_history(v_direct,50,null)
  where message_id=v_message;
  if v_body<>'Hello from Player A' then raise exception 'Direct message history was not returned to its participant'; end if;

  v_failed:=false;
  begin
    perform public.get_message_history(v_team_conversation,50,null);
  exception when others then v_failed:=true;
  end;
  if v_failed then raise exception 'Active team member unexpectedly lost team conversation access'; end if;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_c::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_c::text,'role','authenticated')::text,true);
  v_failed:=false;
  begin
    perform public.create_direct_message_conversation(v_player_a);
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Unrelated player was allowed to start a direct conversation'; end if;
  v_failed:=false;
  begin
    perform public.get_message_history(v_direct,50,null);
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Non-participant could read a private direct conversation'; end if;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_a::text,'role','authenticated')::text,true);
  v_support:=public.create_support_message_conversation('Help with my account','Please can an administrator help me?');
  if not exists (
    select 1 from public.message_conversation_participants
    where conversation_id=v_support and user_id=v_admin and left_at is null
  ) then raise exception 'Private support thread did not include an administrator'; end if;
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_admin::text,'role','authenticated')::text,true);
  select unread_count into v_unread from public.get_my_message_conversations(50)
  where conversation_id=v_support;
  if coalesce(v_unread,0)<>1 then raise exception 'New private support message was not marked unread for the admin'; end if;
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_c::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_c::text,'role','authenticated')::text,true);
  v_failed:=false;
  begin
    perform public.get_message_history(v_support,50,null);
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Unrelated player could read a private admin-support thread'; end if;
  v_failed:=false;
  begin
    perform public.admin_create_message_broadcast('Unauthorised','Player cannot broadcast','team',v_season_team_one);
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Ordinary player was allowed to create an admin broadcast'; end if;
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_a::text,'role','authenticated')::text,true);

  v_failed:=false;
  begin
    perform public.send_message(v_team_conversation,'I am not a captain','announcement');
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Ordinary team member was allowed to post a captain announcement'; end if;
  perform public.send_message(v_team_conversation,'Team update from Player A','message');
  v_failed:=false;
  begin
    perform public.report_message(v_message,'A sender must not be able to report their own message');
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Sender was allowed to report their own message'; end if;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_b::text,'role','authenticated')::text,true);
  v_report:=public.report_message(v_message,'This message is being reported for review');
  v_message_two:=public.report_message(v_message,'This duplicate report should resolve to the same open report');
  if v_report<>v_message_two then raise exception 'Duplicate open reports were not deduplicated'; end if;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_a::text,'role','authenticated')::text,true);
  perform public.block_message_user(v_player_b);
  select count(*) into v_count from public.get_my_blocked_message_users()
  where user_id=v_player_b;
  if v_count<>1 then raise exception 'Blocked-member list did not include the blocked player'; end if;
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_b::text,'role','authenticated')::text,true);
  v_failed:=false;
  begin
    perform public.send_message(v_direct,'A blocked participant should not be able to reply');
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Direct-message block did not prevent sending'; end if;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_captain::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_captain::text,'role','authenticated')::text,true);
  perform public.send_message(v_team_conversation,'Captain announcement','announcement');

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_admin::text,'role','authenticated')::text,true);
  select count(*) into v_count
  from jsonb_array_elements(public.admin_get_message_target_options()->'teams') as targets(item)
  where targets.item->>'id'=v_season_team_one::text;
  if v_count<>1 then raise exception 'Admin target options did not return the permitted team'; end if;
  v_broadcast:=public.admin_create_message_broadcast(
    'Team-only update','A message for the active team only','team',v_season_team_one
  );
  if not exists (
    select 1 from public.message_conversation_participants
    where conversation_id=v_broadcast and user_id=v_player_a
  ) or exists (
    select 1 from public.message_conversation_participants
    where conversation_id=v_broadcast and user_id=v_player_c
  ) then raise exception 'Team-targeted admin broadcast recipients are incorrect'; end if;
  if not exists (
    select 1 from public.message_conversation_participants
    where conversation_id=v_broadcast and user_id=v_admin
  ) then raise exception 'Broadcast creator was not enrolled in the broadcast conversation'; end if;
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_a::text,'role','authenticated')::text,true);
  select unread_count into v_unread from public.get_my_message_conversations(50)
  where conversation_id=v_broadcast;
  if coalesce(v_unread,0)<>1 then raise exception 'New admin broadcast was not marked unread for its recipients'; end if;
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_admin::text,'role','authenticated')::text,true);
  if not exists (
    select 1 from public.notification_events
    where user_id=v_player_a and channel='in_app' and event_type='message.new'
      and payload->>'conversation_id'=v_broadcast::text
  ) then raise exception 'Admin broadcast did not enqueue an in-app message notification'; end if;
  select count(*) into v_count from public.admin_get_message_reports('open',50)
  where report_id=v_report;
  if v_count<>1 then raise exception 'Administrator could not review the message report'; end if;
  perform public.admin_resolve_message_report(v_report,'hide_message','Hidden after moderation review');
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_b::text,'role','authenticated')::text,true);
  select body into v_body from public.get_message_history(v_direct,50,null)
  where message_id=v_message;
  if v_body<>'[Message hidden by moderation]' then raise exception 'Moderated message was not hidden from participants'; end if;
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_a::text,'role','authenticated')::text,true);
  perform public.unblock_message_user(v_player_b);
  select count(*) into v_count from public.get_my_blocked_message_users()
  where user_id=v_player_b;
  if v_count<>0 then raise exception 'Unblocking did not remove the member from the block list'; end if;
  execute 'reset role';

  -- Leaving a team revokes access to its group history immediately.
  update public.team_memberships set status='left' where id=v_membership_a;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player_a::text,'role','authenticated')::text,true);
  v_failed:=false;
  begin
    perform public.get_message_history(v_team_conversation,50,null);
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Former team member retained team conversation access'; end if;
  -- Existing direct history remains available, but replies stop when the shared
  -- active-team relationship ends.
  perform public.get_message_history(v_direct,50,null);
  v_failed:=false;
  begin
    perform public.send_message(v_direct,'A former teammate cannot reply here');
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Former teammates were allowed to continue a direct conversation'; end if;
  execute 'reset role';

  -- A fresh sender may send ten messages per minute, but not an eleventh.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_spammer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_spammer::text,'role','authenticated')::text,true);
  v_direct:=public.create_direct_message_conversation(v_captain);
  for v_i in 1..10 loop
    perform public.send_message(v_direct,'Rate-limit test message '||v_i);
  end loop;
  v_failed:=false;
  begin
    perform public.send_message(v_direct,'This eleventh message must be rate limited');
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Per-user message rate limit did not activate'; end if;
  execute 'reset role';

  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='messages'
  ) then raise exception 'Messages are not enabled for Supabase Realtime'; end if;

  raise notice 'Secure messaging access, team lifecycle, read receipts, reporting, moderation, notifications and rate-limit assertions passed';
end;
$secure_messaging_platform$;

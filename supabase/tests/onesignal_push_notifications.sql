-- OneSignal push preferences, category controls and outbox retry regression.
do $onesignal_push$
declare
  v_user uuid := 'f3000000-0000-4000-8000-000000000001';
  v_preferences public.notification_preferences;
  v_push_id uuid;
  v_claimed integer;
  v_denied boolean := false;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values (v_user,'authenticated','authenticated','ci-onesignal-push@openplay.invalid','','{}'::jsonb,now(),now());

  insert into public.profiles(id,account_retention_status)
  values(v_user,'active')
  on conflict(id) do update set account_retention_status='active';

  perform set_config('request.jwt.claim.sub',v_user::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user,'role','authenticated')::text,true);

  select * into v_preferences from public.get_my_notification_preferences();
  if v_preferences.push_enabled is not false
     or coalesce((v_preferences.category_preferences->>'match_updates')::boolean,false) is not true
     or coalesce((v_preferences.category_preferences->>'team_updates')::boolean,false) is not true
     or coalesce((v_preferences.category_preferences->>'club_messages')::boolean,false) is not true then
    raise exception 'Default push/category preferences are incorrect';
  end if;

  perform public.update_my_notification_category_preferences(
    '{"match_updates":false,"team_updates":false,"club_messages":false}'::jsonb
  );
  perform public.enqueue_notification_event(v_user,'fixture.rescheduled',jsonb_build_object('fixture_id','f3000000-0000-4000-8000-000000000010'));
  if exists(select 1 from public.notification_events where user_id=v_user and payload->>'fixture_id'='f3000000-0000-4000-8000-000000000010') then
    raise exception 'Disabled match category still enqueued notifications';
  end if;

  -- Account-security events are intentionally always enabled.
  perform public.enqueue_notification_event(v_user,'player.banned',jsonb_build_object('player_id','f3000000-0000-4000-8000-000000000011'));
  if not exists(select 1 from public.notification_events where user_id=v_user and event_type='player.banned' and channel='in_app')
     or not exists(select 1 from public.notification_events where user_id=v_user and event_type='player.banned' and channel='email') then
    raise exception 'Critical account-security notification was suppressed by category preferences';
  end if;
  if exists(select 1 from public.notification_events where user_id=v_user and event_type='player.banned' and channel='push') then
    raise exception 'Push event was enqueued while push delivery was disabled';
  end if;

  perform public.update_my_notification_category_preferences('{"match_updates":true}'::jsonb);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user,'role','service_role')::text,true);
  update public.notification_preferences set push_enabled=true where user_id=v_user;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user,'role','authenticated')::text,true);
  perform public.enqueue_notification_event(v_user,'fixture.rescheduled',jsonb_build_object('fixture_id','f3000000-0000-4000-8000-000000000012'));

  select id into v_push_id from public.notification_events
  where user_id=v_user and event_type='fixture.rescheduled'
    and payload->>'fixture_id'='f3000000-0000-4000-8000-000000000012' and channel='push';
  if v_push_id is null then raise exception 'Enabled push preference did not enqueue a push event'; end if;

  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user,'role','service_role')::text,true);
  select count(*) into v_claimed from public.claim_notification_events(10,array['push']) where id=v_push_id;
  if v_claimed<>1 then raise exception 'Push outbox event was not claimed by the push worker'; end if;

  perform public.fail_notification_event_permanent(v_push_id,'No active OneSignal subscriptions');
  if not exists(select 1 from public.notification_events where id=v_push_id and status='failed') then
    raise exception 'Permanent push failure was incorrectly scheduled for another retry';
  end if;

  perform set_config('request.jwt.claim.sub',v_user::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user,'role','authenticated')::text,true);
  begin
    perform public.update_my_notification_category_preferences('{"unknown_category":false}'::jsonb);
    v_denied := false;
  exception when others then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Unknown notification category was accepted'; end if;

  if pg_catalog.has_function_privilege('anon','public.update_my_notification_category_preferences(jsonb)','EXECUTE') then
    raise exception 'Anonymous role must not update notification categories';
  end if;

  raise notice 'Push channel, category preferences, critical alerts and permanent retry regressions passed';
end;
$onesignal_push$;

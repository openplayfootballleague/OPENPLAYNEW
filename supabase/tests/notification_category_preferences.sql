-- Category-level notification preferences and mandatory notice regression tests.
-- Runs against the disposable local Supabase database created by CI.

do $notification_category_preferences$
declare
  v_user uuid := gen_random_uuid();
  v_team_count integer;
  v_fixture_count integer;
  v_result_count integer;
  v_message_count integer;
  v_referee_count integer;
  v_mandatory_count integer;
  v_prefs public.notification_preferences;
begin
  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_user,'authenticated','authenticated','ci-notification-categories@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.profiles(id,display_name,account_retention_status)
  values(v_user,'Notification Category Test','active')
  on conflict(id) do update set display_name=excluded.display_name,account_retention_status='active';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_user::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user::text,'role','authenticated')::text,true);

  v_prefs := public.update_my_notification_category_preferences(false,false,false,false,false);
  if v_prefs.team_updates_enabled or v_prefs.fixture_updates_enabled
     or v_prefs.result_updates_enabled or v_prefs.messages_enabled
     or v_prefs.referee_updates_enabled then
    raise exception 'Category preference RPC did not persist all five opt-outs';
  end if;

  execute 'reset role';

  perform public.enqueue_notification_event(v_user,'team.membership_approved','{"membership_id":"category-test"}'::jsonb);
  perform public.enqueue_notification_event(v_user,'fixture.scheduled','{"fixture_id":"category-test-scheduled"}'::jsonb);
  perform public.enqueue_notification_event(v_user,'fixture.result_published','{"fixture_id":"category-test-result"}'::jsonb);
  perform public.enqueue_notification_event(v_user,'message.new','{"conversation_id":"category-test"}'::jsonb);
  perform public.enqueue_notification_event(v_user,'referee.report.approved','{"fixture_id":"category-test-referee"}'::jsonb);
  perform public.enqueue_notification_event(v_user,'player.banned','{"reason":"Safety test"}'::jsonb);

  select count(*) into v_team_count from public.notification_events
  where user_id=v_user and event_type='team.membership_approved';
  select count(*) into v_fixture_count from public.notification_events
  where user_id=v_user and event_type='fixture.scheduled';
  select count(*) into v_result_count from public.notification_events
  where user_id=v_user and event_type='fixture.result_published';
  select count(*) into v_message_count from public.notification_events
  where user_id=v_user and event_type='message.new';
  select count(*) into v_referee_count from public.notification_events
  where user_id=v_user and event_type='referee.report.approved';
  select count(*) into v_mandatory_count from public.notification_events
  where user_id=v_user and event_type='player.banned';

  if v_team_count<>0 or v_fixture_count<>0 or v_result_count<>0
     or v_message_count<>0 or v_referee_count<>0 then
    raise exception 'A disabled optional category still enqueued notifications';
  end if;
  if v_mandatory_count=0 then
    raise exception 'Mandatory safeguarding/eligibility notice was suppressed by category preferences';
  end if;

  if has_function_privilege('anon','public.update_my_notification_category_preferences(boolean,boolean,boolean,boolean,boolean)','EXECUTE') then
    raise exception 'Anonymous users can update notification category preferences';
  end if;

  delete from auth.users where id=v_user;
end;
$notification_category_preferences$;

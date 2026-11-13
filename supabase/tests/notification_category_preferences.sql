-- Notification category preferences are owner-scoped, audited and applied
-- before any email/SMS/in-app event is enqueued. Account/security events remain mandatory.
do $$
declare
  v_user uuid:='f3000000-0000-4000-8000-000000000001';
  v_preferences public.notification_preferences;
  v_count integer;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values(v_user,'authenticated','authenticated','ci-notification-categories@openplay.invalid','','{}'::jsonb,now(),now(),now())
  on conflict(id) do nothing;
  insert into public.profiles(id,display_name,phone,created_at,updated_at)
  values(v_user,'Notification Categories Test','+447700900501',now(),now())
  on conflict(id) do nothing;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_user::text,true);

  v_preferences:=public.get_my_notification_preferences();
  if v_preferences.category_preferences<>'{"matchday":true,"team_updates":true,"messages":true,"payments":true}'::jsonb then
    raise exception 'New accounts must default all optional notification categories to enabled';
  end if;

  v_preferences:=public.update_my_notification_preferences(true,false,true);
  v_preferences:=public.update_my_notification_category_preferences(false,true,false,true);
  if not v_preferences.email_enabled or v_preferences.sms_enabled or not v_preferences.in_app_enabled then
    raise exception 'Category updates must not change channel-level notification preferences';
  end if;
  if v_preferences.category_preferences<>'{"matchday":false,"team_updates":true,"messages":false,"payments":true}'::jsonb then
    raise exception 'Category preference RPC did not persist the selected allowlisted values';
  end if;
  if v_preferences.sms_consented_at is not null or v_preferences.sms_consent_version is not null then
    raise exception 'Category preference changes must not create or alter SMS consent';
  end if;
  if has_table_privilege('authenticated','public.notification_preferences','UPDATE') then
    raise exception 'Authenticated clients must not bypass category preference RPCs with direct table updates';
  end if;
  if not has_function_privilege('authenticated','public.update_my_notification_category_preferences(boolean,boolean,boolean,boolean)','EXECUTE')
     or has_function_privilege('anon','public.update_my_notification_category_preferences(boolean,boolean,boolean,boolean)','EXECUTE') then
    raise exception 'Category preference RPC grants are incorrect';
  end if;
  execute 'reset role';

  perform public.enqueue_notification_event(v_user,'fixture.scheduled','{"fixture_id":"f3000000-0000-4000-8000-000000000101"}'::jsonb);
  perform public.enqueue_notification_event(v_user,'message.new','{"conversation_id":"f3000000-0000-4000-8000-000000000102"}'::jsonb);
  perform public.enqueue_notification_event(v_user,'team.membership_approved','{"membership_id":"f3000000-0000-4000-8000-000000000103"}'::jsonb);
  perform public.enqueue_notification_event(v_user,'payment.refund','{"payment_id":"f3000000-0000-4000-8000-000000000104"}'::jsonb);
  perform public.enqueue_notification_event(v_user,'player.banned','{"reason":"test"}'::jsonb);

  select count(*) into v_count from public.notification_events
  where user_id=v_user and channel='in_app';
  if v_count<>4 then
    raise exception 'Only enabled team updates and protected account/security events should be enqueued on email and in-app channels; found %',v_count;
  end if;
  if exists(select 1 from public.notification_events where user_id=v_user and event_type in ('fixture.scheduled','message.new','payment.refund')) then
    raise exception 'Disabled notification categories must not enqueue events on any channel';
  end if;
  if (select count(*) from public.notification_events where user_id=v_user and event_type='team.membership_approved')<>2
     or (select count(*) from public.notification_events where user_id=v_user and event_type='player.banned')<>2 then
    raise exception 'Enabled team updates and protected account/security events must use both enabled channels';
  end if;
  if not exists(
    select 1 from public.audit_log
    where actor_user_id=v_user and action='notification.categories_updated'
      and after_data->'category_preferences'='{"matchday":false,"team_updates":true,"messages":false,"payments":true}'::jsonb
  ) then
    raise exception 'Category preference changes must be recorded in the audit log';
  end if;
  raise notice 'Notification category preference and mandatory security-notice regressions passed';
end;
$$;

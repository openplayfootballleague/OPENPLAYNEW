-- Add per-category notification controls while keeping security/account notices mandatory.
alter table public.notification_preferences
  add column if not exists category_preferences jsonb not null
  default '{"matchday":true,"team_updates":true,"messages":true,"payments":true}'::jsonb;

alter table public.notification_preferences
  drop constraint if exists notification_preferences_category_preferences_check;
alter table public.notification_preferences
  add constraint notification_preferences_category_preferences_check
  check (
    jsonb_typeof(category_preferences)='object'
    and category_preferences ?& array['matchday','team_updates','messages','payments']
    and (category_preferences - array['matchday','team_updates','messages','payments'])='{}'::jsonb
    and jsonb_typeof(category_preferences->'matchday')='boolean'
    and jsonb_typeof(category_preferences->'team_updates')='boolean'
    and jsonb_typeof(category_preferences->'messages')='boolean'
    and jsonb_typeof(category_preferences->'payments')='boolean'
  );

create or replace function public.update_my_notification_category_preferences(
  p_matchday_enabled boolean,
  p_team_updates_enabled boolean,
  p_messages_enabled boolean,
  p_payments_enabled boolean
)
returns public.notification_preferences
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_preferences public.notification_preferences;
  v_before jsonb;
  v_after jsonb:=jsonb_build_object(
    'matchday',p_matchday_enabled,
    'team_updates',p_team_updates_enabled,
    'messages',p_messages_enabled,
    'payments',p_payments_enabled
  );
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  insert into public.notification_preferences(user_id,category_preferences)
  values(v_user,'{"matchday":true,"team_updates":true,"messages":true,"payments":true}'::jsonb)
  on conflict(user_id) do nothing;

  select category_preferences into v_before
  from public.notification_preferences where user_id=v_user for update;

  update public.notification_preferences
  set category_preferences=v_after,updated_at=now()
  where user_id=v_user
  returning * into v_preferences;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data)
  values(v_user,'notification.categories_updated','notification_preferences',v_user::text,
    jsonb_build_object('category_preferences',v_before),
    jsonb_build_object('category_preferences',v_after));

  return v_preferences;
end;
$$;
revoke all on function public.update_my_notification_category_preferences(boolean,boolean,boolean,boolean) from public,anon;
grant execute on function public.update_my_notification_category_preferences(boolean,boolean,boolean,boolean) to authenticated;

create or replace function public.enqueue_notification_event(
  p_user_id uuid,
  p_event_type text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_preferences public.notification_preferences;
  v_dedupe text;
  v_category text;
begin
  if p_user_id is null or p_event_type is null or length(btrim(p_event_type))<3 then return; end if;

  v_category:=case
    when p_event_type like 'fixture.%' then 'matchday'
    when p_event_type like 'team.payment.%' or p_event_type like 'payment.%'
      or p_event_type like 'finance.%' or p_event_type like 'referee.payout.%' then 'payments'
    when p_event_type like 'team.%' or p_event_type like 'player.transfer_%' then 'team_updates'
    when p_event_type like 'message.%' then 'messages'
    else 'account_security'
  end;

  insert into public.notification_preferences(user_id) values(p_user_id)
  on conflict(user_id) do nothing;
  select * into v_preferences from public.notification_preferences where user_id=p_user_id;

  -- Account and security notices are mandatory. Other categories can be
  -- disabled independently, without changing channel-level consent.
  if v_category<>'account_security'
     and coalesce((v_preferences.category_preferences->>v_category)::boolean,true)=false then
    return;
  end if;

  v_dedupe:=p_event_type||':'||coalesce(p_payload->>'fixture_id',p_payload->>'membership_id',p_payload->>'season_team_id','event')||':'||p_user_id::text;

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
revoke all on function public.enqueue_notification_event(uuid,text,jsonb) from public,anon,authenticated;

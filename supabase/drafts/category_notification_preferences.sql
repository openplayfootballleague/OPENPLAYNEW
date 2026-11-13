-- Category-level notification preferences. Channel preferences remain independent.
-- Critical account, safety, eligibility and security notices are not suppressible by
-- category settings; unknown future event types retain the existing delivery behaviour.

alter table public.notification_preferences
  add column if not exists team_updates_enabled boolean not null default true,
  add column if not exists fixture_updates_enabled boolean not null default true,
  add column if not exists result_updates_enabled boolean not null default true,
  add column if not exists messages_enabled boolean not null default true,
  add column if not exists referee_updates_enabled boolean not null default true;

create or replace function public.update_my_notification_category_preferences(
  p_team_updates_enabled boolean,
  p_fixture_updates_enabled boolean,
  p_result_updates_enabled boolean,
  p_messages_enabled boolean,
  p_referee_updates_enabled boolean
)
returns public.notification_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_preferences public.notification_preferences;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_team_updates_enabled is null
    or p_fixture_updates_enabled is null
    or p_result_updates_enabled is null
    or p_messages_enabled is null
    or p_referee_updates_enabled is null then
    raise exception 'Choose a setting for every notification category';
  end if;

  insert into public.notification_preferences(
    user_id,team_updates_enabled,fixture_updates_enabled,
    result_updates_enabled,messages_enabled,referee_updates_enabled,updated_at
  )
  values(
    v_user,p_team_updates_enabled,p_fixture_updates_enabled,
    p_result_updates_enabled,p_messages_enabled,p_referee_updates_enabled,now()
  )
  on conflict(user_id) do update set
    team_updates_enabled=excluded.team_updates_enabled,
    fixture_updates_enabled=excluded.fixture_updates_enabled,
    result_updates_enabled=excluded.result_updates_enabled,
    messages_enabled=excluded.messages_enabled,
    referee_updates_enabled=excluded.referee_updates_enabled,
    updated_at=now()
  returning * into v_preferences;

  return v_preferences;
end;
$$;

create or replace function public.enqueue_notification_event(
  p_user_id uuid,
  p_event_type text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_preferences public.notification_preferences;
  v_dedupe text;
  v_category_enabled boolean := true;
begin
  if p_user_id is null or p_event_type is null or length(btrim(p_event_type))<3 then return; end if;

  insert into public.notification_preferences(user_id)
  values(p_user_id) on conflict(user_id) do nothing;

  select * into v_preferences
  from public.notification_preferences
  where user_id=p_user_id;

  -- Only these optional categories can be muted. Account/security, safeguarding,
  -- discipline and any future unclassified event types deliberately remain enabled.
  if p_event_type like 'team.%' or p_event_type like 'player.transfer_%' then
    v_category_enabled := v_preferences.team_updates_enabled;
  elsif p_event_type in ('fixture.scheduled','fixture.rescheduled','fixture.status_changed',
                         'fixture.reminder_24h','fixture.reminder_3h') then
    v_category_enabled := v_preferences.fixture_updates_enabled;
  elsif p_event_type in ('fixture.result_published','fixture.result_corrected') then
    v_category_enabled := v_preferences.result_updates_enabled;
  elsif p_event_type like 'message.%' then
    v_category_enabled := v_preferences.messages_enabled;
  elsif p_event_type like 'referee.report.%' then
    v_category_enabled := v_preferences.referee_updates_enabled;
  end if;

  if not v_category_enabled then return; end if;

  v_dedupe:=p_event_type||':'||
    coalesce(p_payload->>'fixture_id',p_payload->>'membership_id',p_payload->>'season_team_id','event')
    ||':'||p_user_id::text;

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

revoke all on function public.update_my_notification_category_preferences(boolean,boolean,boolean,boolean,boolean) from public,anon;
grant execute on function public.update_my_notification_category_preferences(boolean,boolean,boolean,boolean,boolean) to authenticated;
revoke all on function public.enqueue_notification_event(uuid,text,jsonb) from public,anon,authenticated;

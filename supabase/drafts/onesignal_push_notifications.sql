-- OneSignal push delivery, account category preferences and privacy-safe retry behavior.
alter table public.notification_preferences
  add column if not exists push_enabled boolean not null default false,
  add column if not exists category_preferences jsonb not null default
    '{"match_updates":true,"team_updates":true,"club_messages":true,"competition_announcements":true,"support_updates":true}'::jsonb;

drop index if exists public.notification_events_outbox_due_idx;
create index notification_events_outbox_due_idx
  on public.notification_events(status,next_attempt_at,created_at)
  where channel in ('email','sms','push');

create or replace function public.notification_category_for_event(p_event_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_event_type like 'fixture.%' or p_event_type like 'referee.report.%' then 'match_updates'
    when p_event_type like 'team.%' or p_event_type like 'player.transfer.%' then 'team_updates'
    when p_event_type = 'message.new' then 'club_messages'
    when p_event_type like 'announcement.%' then 'competition_announcements'
    when p_event_type like 'support.%' then 'support_updates'
    else null
  end;
$$;

create or replace function public.update_my_notification_category_preferences(p_category_preferences jsonb)
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
  if p_category_preferences is null or jsonb_typeof(p_category_preferences) <> 'object' then
    raise exception 'Notification category preferences must be an object';
  end if;
  if exists (
    select 1 from jsonb_each(p_category_preferences) item
    where item.key not in ('match_updates','team_updates','club_messages','competition_announcements','support_updates')
       or jsonb_typeof(item.value) <> 'boolean'
  ) then
    raise exception 'Notification category preferences contain an unsupported category or value';
  end if;

  insert into public.notification_preferences(user_id) values(v_user)
  on conflict(user_id) do nothing;

  update public.notification_preferences
  set category_preferences = category_preferences || p_category_preferences,
      updated_at = now()
  where user_id = v_user
  returning * into v_preferences;

  return v_preferences;
end;
$$;

create or replace function public.set_my_push_enabled(p_enabled boolean)
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
  insert into public.notification_preferences(user_id,push_enabled)
  values(v_user,p_enabled)
  on conflict(user_id) do update
    set push_enabled = excluded.push_enabled,
        updated_at = now()
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
  v_category text;
  v_category_enabled boolean := true;
begin
  if p_user_id is null or p_event_type is null or length(btrim(p_event_type)) < 3 then return; end if;
  insert into public.notification_preferences(user_id) values(p_user_id) on conflict(user_id) do nothing;
  select * into v_preferences from public.notification_preferences where user_id = p_user_id;

  v_category := public.notification_category_for_event(p_event_type);
  if v_category is not null then
    v_category_enabled := coalesce((v_preferences.category_preferences ->> v_category)::boolean, true);
  end if;
  -- Account-security events intentionally have no category and cannot be disabled.
  if not v_category_enabled then return; end if;

  v_dedupe := p_event_type || ':' ||
    coalesce(p_payload->>'fixture_id',p_payload->>'membership_id',p_payload->>'season_team_id','event') ||
    ':' || p_user_id::text;

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
  if v_preferences.push_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key)
    values(p_user_id,'push',p_event_type,'queued',coalesce(p_payload,'{}'::jsonb),v_dedupe||':push')
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
  if v_preferences.in_app_enabled then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key,sent_at)
    values(p_user_id,'in_app',p_event_type,'sent',coalesce(p_payload,'{}'::jsonb),v_dedupe||':in_app',now())
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
end;
$$;

drop function if exists public.claim_notification_events(integer);
create or replace function public.claim_notification_events(
  p_limit integer default 25,
  p_channels text[] default array['email','sms']
)
returns setof public.notification_events
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'Service role required'; end if;
  if p_channels is null or cardinality(p_channels) = 0 or exists (
    select 1 from unnest(p_channels) channel where channel not in ('email','sms','push')
  ) then
    raise exception 'Invalid notification delivery channels';
  end if;

  update public.notification_events e
  set status='cancelled',last_error='Delivery disabled by recipient notification preferences.',updated_at=now()
  from public.notification_preferences pref
  where e.user_id=pref.user_id and e.status='queued'
    and (
      (e.channel='email' and not pref.email_enabled)
      or (e.channel='sms' and not pref.sms_enabled)
      or (e.channel='push' and not pref.push_enabled)
      or (
        public.notification_category_for_event(e.event_type) is not null
        and coalesce(
          (pref.category_preferences ->> public.notification_category_for_event(e.event_type))::boolean,
          true
        ) = false
      )
    );

  return query
  with candidates as (
    select e.id from public.notification_events e
    where e.status='queued'
      and e.channel = any(p_channels)
      and e.next_attempt_at <= now()
      and (e.locked_at is null or e.locked_at < now()-interval '15 minutes')
    order by e.next_attempt_at,e.created_at
    for update skip locked
    limit least(greatest(coalesce(p_limit,25),1),100)
  )
  update public.notification_events e
  set status='sending',attempt_count=e.attempt_count+1,last_attempt_at=now(),locked_at=now(),updated_at=now()
  from candidates c where e.id=c.id
  returning e.*;
end;
$$;

create or replace function public.fail_notification_event(p_event_id uuid,p_error text)
returns public.notification_events
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.notification_events;
  v_max_attempts integer;
  v_delay integer;
  v_permanent boolean := left(coalesce(p_error,''),10) = 'Permanent:';
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'Service role required'; end if;
  select * into v_event from public.notification_events where id=p_event_id for update;
  if not found or v_event.status <> 'sending' then raise exception 'Notification event is not currently sending'; end if;
  v_max_attempts := case when v_event.manual_retry_used then v_event.attempt_count else 5 end;
  v_delay := least(5*power(2,greatest(v_event.attempt_count-1,0)),240)::integer;
  update public.notification_events
  set status = case when v_permanent or v_event.attempt_count >= v_max_attempts then 'failed' else 'queued' end,
      next_attempt_at = case when v_permanent or v_event.attempt_count >= v_max_attempts
        then next_attempt_at else now()+make_interval(mins=>v_delay) end,
      last_error = left(coalesce(p_error,'Delivery failed without an error message.'),2000),
      locked_at = null,
      updated_at = now()
  where id=p_event_id returning * into v_event;
  return v_event;
end;
$$;

revoke all on function public.notification_category_for_event(text) from public,anon,authenticated;
revoke all on function public.update_my_notification_category_preferences(jsonb) from public,anon;
grant execute on function public.update_my_notification_category_preferences(jsonb) to authenticated;
revoke all on function public.set_my_push_enabled(boolean) from public,anon;
grant execute on function public.set_my_push_enabled(boolean) to authenticated;
revoke all on function public.enqueue_notification_event(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.claim_notification_events(integer,text[]) from public,anon,authenticated;
grant execute on function public.claim_notification_events(integer,text[]) to service_role;
revoke all on function public.fail_notification_event(uuid,text) from public,anon,authenticated;
grant execute on function public.fail_notification_event(uuid,text) to service_role;

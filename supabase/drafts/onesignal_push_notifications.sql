-- OneSignal push delivery, account category preferences and privacy-safe retry behavior.
alter table public.notification_events
  drop constraint if exists notification_events_channel_check;
alter table public.notification_events
  add constraint notification_events_channel_check
  check (channel in ('email','sms','in_app','push'));

-- Preference mutations go through narrowly scoped security-definer RPCs or the
-- authenticated OneSignal device manager; do not expose direct table updates.
revoke update on public.notification_preferences from authenticated;

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
    when p_event_type like 'fixture.%' or p_event_type like 'referee.%' then 'match_updates'
    when p_event_type like 'team.%' or p_event_type like 'player.transfer%' then 'team_updates'
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

create or replace function public.disable_my_push()
returns public.notification_preferences
language plpgsql
security definer
set search_path = ''
as $
declare
  v_user uuid := auth.uid();
  v_preferences public.notification_preferences;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  insert into public.notification_preferences(user_id,push_enabled)
  values(v_user,false)
  on conflict(user_id) do update
    set push_enabled=false,updated_at=now()
  returning * into v_preferences;
  return v_preferences;
end;
$;

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
  v_critical boolean := p_event_type in ('player.banned','player.unbanned','player.guardian_consent.captain_review_required');
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
    ':' || coalesce(p_payload->>'scheduled_at',p_payload->>'changed_at','') || ':' || p_user_id::text;

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
  if v_preferences.in_app_enabled or v_critical then
    insert into public.notification_events(user_id,channel,event_type,status,payload,dedupe_key,sent_at)
    values(p_user_id,'in_app',p_event_type,'sent',coalesce(p_payload,'{}'::jsonb),v_dedupe||':in_app',now())
    on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end if;
end;
$$;

-- Keep fixture changes cancelling queued push reminders as well as email/SMS.
create or replace function public.notify_fixture_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $
declare v_event text; v_payload jsonb; v_user uuid;
begin
  if tg_op='INSERT' then
    v_event:='fixture.scheduled';
  elsif old.status is distinct from new.status then
    update public.notification_events
    set status='cancelled',last_error='Fixture changed; reminder is no longer valid.',updated_at=now()
    where payload->>'fixture_id'=new.id::text
      and event_type in ('fixture.reminder_24h','fixture.reminder_3h')
      and ((channel in ('email','sms','push') and status in ('queued','held'))
        or (channel='in_app' and status='sent' and read_at is null));
    if new.status='completed' then return new; end if;
    v_event:='fixture.status_changed';
  elsif old.scheduled_at is distinct from new.scheduled_at then
    update public.notification_events
    set status='cancelled',last_error='Fixture time changed; reminder is no longer valid.',updated_at=now()
    where payload->>'fixture_id'=new.id::text
      and event_type in ('fixture.reminder_24h','fixture.reminder_3h')
      and ((channel in ('email','sms','push') and status in ('queued','held'))
        or (channel='in_app' and status='sent' and read_at is null));
    v_event:='fixture.rescheduled';
  else
    return new;
  end if;
  v_payload:=jsonb_build_object(
    'fixture_id',new.id,'gameweek',new.gameweek,'scheduled_at',new.scheduled_at,
    'status',new.status,
    'home_team_name',(select name from public.season_teams where id=new.home_team_id),
    'away_team_name',(select name from public.season_teams where id=new.away_team_id)
  );
  for v_user in
    select distinct tm.user_id from public.team_memberships tm
    where tm.season_team_id in (new.home_team_id,new.away_team_id) and tm.status='active'
  loop
    perform public.enqueue_notification_event(v_user,v_event,v_payload);
  end loop;
  return new;
end;
$;

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
  where e.user_id=pref.user_id and e.status in ('queued','held')
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

revoke all on function public.notification_category_for_event(text) from public,anon,authenticated;
revoke all on function public.update_my_notification_category_preferences(jsonb) from public,anon;
grant execute on function public.update_my_notification_category_preferences(jsonb) to authenticated;
revoke all on function public.disable_my_push() from public,anon;
grant execute on function public.disable_my_push() to authenticated;
revoke all on function public.enqueue_notification_event(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.claim_notification_events(integer,text[]) from public,anon,authenticated;
grant execute on function public.claim_notification_events(integer,text[]) to service_role;

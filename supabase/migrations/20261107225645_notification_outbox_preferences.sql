-- Notification preferences, outbox retries/holds and automatic event enqueueing.
alter table public.notification_events
  add column if not exists attempt_count integer not null default 0,
  add column if not exists last_attempt_at timestamptz,
  add column if not exists next_attempt_at timestamptz not null default now(),
  add column if not exists last_error text,
  add column if not exists locked_at timestamptz,
  add column if not exists unconfirmed_at timestamptz,
  add column if not exists held_at timestamptz,
  add column if not exists held_by uuid references auth.users(id) on delete restrict,
  add column if not exists hold_reason text,
  add column if not exists manual_retry_used boolean not null default false,
  add column if not exists dedupe_key text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists read_at timestamptz;

alter table public.notification_events
  drop constraint if exists notification_events_status_check;
alter table public.notification_events
  add constraint notification_events_status_check
  check (status in ('queued','sending','sent','failed','held','unconfirmed','cancelled'));

create unique index if not exists notification_events_dedupe_key_idx
  on public.notification_events(dedupe_key) where dedupe_key is not null;
create index if not exists notification_events_outbox_due_idx
  on public.notification_events(status,next_attempt_at,created_at)
  where channel in ('email','sms');
create index if not exists notification_events_admin_status_idx
  on public.notification_events(status,created_at desc);

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  email_enabled boolean not null default true,
  sms_enabled boolean not null default false,
  in_app_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.notification_preferences enable row level security;
drop policy if exists notification_preferences_select_owner_or_admin on public.notification_preferences;
create policy notification_preferences_select_owner_or_admin
  on public.notification_preferences for select to authenticated
  using (user_id=(select auth.uid()) or public.has_platform_role());
drop policy if exists notification_preferences_update_owner on public.notification_preferences;
create policy notification_preferences_update_owner
  on public.notification_preferences for update to authenticated
  using (user_id=(select auth.uid()))
  with check (user_id=(select auth.uid()));
revoke all on public.notification_preferences from public,anon;
grant select,update on public.notification_preferences to authenticated;
revoke insert,delete on public.notification_preferences from authenticated;

revoke all on public.notification_events from public,anon;
grant select on public.notification_events to authenticated;

create or replace function public.get_my_notification_preferences()
returns public.notification_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare v_user uuid:=auth.uid(); v_preferences public.notification_preferences;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  insert into public.notification_preferences(user_id) values(v_user) on conflict(user_id) do nothing;
  select * into v_preferences from public.notification_preferences where user_id=v_user;
  return v_preferences;
end;
$$;

create or replace function public.update_my_notification_preferences(
  p_email_enabled boolean,
  p_sms_enabled boolean,
  p_in_app_enabled boolean
)
returns public.notification_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare v_user uuid:=auth.uid(); v_preferences public.notification_preferences;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  insert into public.notification_preferences(user_id,email_enabled,sms_enabled,in_app_enabled,updated_at)
  values(v_user,p_email_enabled,p_sms_enabled,p_in_app_enabled,now())
  on conflict(user_id) do update set
    email_enabled=excluded.email_enabled,
    sms_enabled=excluded.sms_enabled,
    in_app_enabled=excluded.in_app_enabled,
    updated_at=now()
  returning * into v_preferences;
  return v_preferences;
end;
$$;

create or replace function public.mark_notification_read(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  update public.notification_events
  set read_at=coalesce(read_at,now()),updated_at=now()
  where id=p_event_id and user_id=v_user and channel='in_app';
  if not found then raise exception 'Notification not found'; end if;
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
declare v_preferences public.notification_preferences; v_dedupe text;
begin
  if p_user_id is null or p_event_type is null or length(btrim(p_event_type))<3 then return; end if;
  insert into public.notification_preferences(user_id) values(p_user_id) on conflict(user_id) do nothing;
  select * into v_preferences from public.notification_preferences where user_id=p_user_id;
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

create or replace function public.notify_team_membership_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_team_name text;
begin
  if (tg_op='INSERT' and new.status='active') or
     (tg_op='UPDATE' and old.status is distinct from new.status and new.status in ('active','rejected')) then
    select name into v_team_name from public.season_teams where id=new.season_team_id;
    perform public.enqueue_notification_event(
      new.user_id,
      case when new.status='active' then 'team.membership_approved' else 'team.membership_rejected' end,
      jsonb_build_object('season_team_id',new.season_team_id,'team_name',v_team_name,'membership_id',new.id)
    );
  end if;
  return new;
end;
$$;
drop trigger if exists notify_team_membership_change_trigger on public.team_memberships;
create trigger notify_team_membership_change_trigger
after insert or update of status on public.team_memberships
for each row execute function public.notify_team_membership_change();

create or replace function public.notify_team_registration_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_captain uuid;
begin
  if tg_op='UPDATE' and old.registration_status is distinct from new.registration_status
    and new.registration_status in ('approved','rejected') then
    select user_id into v_captain from public.team_memberships
    where season_team_id=new.id and is_captain=true
    order by joined_at nulls first limit 1;
    if v_captain is not null then
      perform public.enqueue_notification_event(
        v_captain,
        case when new.registration_status='approved' then 'team.registration_approved' else 'team.registration_rejected' end,
        jsonb_build_object('season_team_id',new.id,'team_name',new.name)
      );
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists notify_team_registration_change_trigger on public.season_teams;
create trigger notify_team_registration_change_trigger
after update of registration_status on public.season_teams
for each row execute function public.notify_team_registration_change();

create or replace function public.notify_fixture_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_event text; v_payload jsonb; v_user uuid;
begin
  if tg_op='INSERT' then
    v_event:='fixture.scheduled';
  elsif old.status is distinct from new.status then
    if new.status='completed' then return new; end if;
    v_event:='fixture.status_changed';
  elsif old.scheduled_at is distinct from new.scheduled_at then
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
$$;
drop trigger if exists notify_fixture_change_trigger on public.fixtures;
create trigger notify_fixture_change_trigger
after insert or update of status,scheduled_at on public.fixtures
for each row execute function public.notify_fixture_change();

create or replace function public.notify_fixture_result_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_event text; v_payload jsonb; v_user uuid; v_fixture public.fixtures;
begin
  if new.confirmed_at is null then return new; end if;
  if tg_op='UPDATE' and old.home_score is not distinct from new.home_score and old.away_score is not distinct from new.away_score then
    return new;
  end if;
  v_event:=case when tg_op='INSERT' then 'fixture.result_published' else 'fixture.result_corrected' end;
  select * into v_fixture from public.fixtures where id=new.fixture_id;
  v_payload:=jsonb_build_object(
    'fixture_id',new.fixture_id,'home_score',new.home_score,'away_score',new.away_score,
    'gameweek',v_fixture.gameweek,
    'home_team_name',(select name from public.season_teams where id=v_fixture.home_team_id),
    'away_team_name',(select name from public.season_teams where id=v_fixture.away_team_id)
  );
  for v_user in
    select distinct tm.user_id from public.team_memberships tm
    where tm.season_team_id in (v_fixture.home_team_id,v_fixture.away_team_id) and tm.status='active'
  loop
    perform public.enqueue_notification_event(v_user,v_event,v_payload);
  end loop;
  return new;
end;
$$;
drop trigger if exists notify_fixture_result_change_trigger on public.fixture_results;
create trigger notify_fixture_result_change_trigger
after insert or update of home_score,away_score,confirmed_at on public.fixture_results
for each row execute function public.notify_fixture_result_change();

create or replace function public.admin_get_notification_events(
  p_status text default 'all',
  p_limit integer default 50,
  p_offset integer default 0
)
returns table(
  id uuid,user_id uuid,recipient_name text,recipient_email text,recipient_phone text,
  channel text,event_type text,status text,attempt_count integer,last_attempt_at timestamptz,
  next_attempt_at timestamptz,last_error text,created_at timestamptz,sent_at timestamptz,
  held_at timestamptz,hold_reason text,manual_retry_used boolean,read_at timestamptz,payload jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_status is not null and p_status not in ('all','queued','sending','sent','failed','held','unconfirmed','cancelled') then
    raise exception 'Invalid notification status filter';
  end if;
  return query
  select e.id,e.user_id,p.full_name,p.email,p.phone,e.channel,e.event_type,e.status,e.attempt_count,
    e.last_attempt_at,e.next_attempt_at,e.last_error,e.created_at,e.sent_at,e.held_at,e.hold_reason,e.manual_retry_used,e.read_at,e.payload
  from public.notification_events e
  left join public.players p on p.user_id=e.user_id
  where p_status is null or p_status='all' or e.status=p_status
  order by e.created_at desc
  limit least(greatest(coalesce(p_limit,50),1),100)
  offset greatest(coalesce(p_offset,0),0);
end;
$$;

create or replace function public.admin_retry_notification(p_event_id uuid,p_reason text)
returns public.notification_events
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_event public.notification_events; v_previous text;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  select * into v_event from public.notification_events where id=p_event_id for update;
  if not found then raise exception 'Notification event not found'; end if;
  v_previous:=v_event.status;
  if v_event.status not in ('failed','unconfirmed') then raise exception 'Only failed or unconfirmed events can be retried'; end if;
  if v_event.manual_retry_used then raise exception 'The one manual retry has already been used'; end if;
  update public.notification_events
  set status='queued',manual_retry_used=true,next_attempt_at=now(),last_error=null,
      locked_at=null,unconfirmed_at=null,updated_at=now()
  where id=p_event_id returning * into v_event;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'notification.manual_retry','notification_event',p_event_id::text,btrim(p_reason),
    jsonb_build_object('status',v_previous,'attempt_count',v_event.attempt_count),
    jsonb_build_object('status','queued','manual_retry_used',true));
  return v_event;
end;
$$;

create or replace function public.admin_set_notification_hold(
  p_event_id uuid,p_hold boolean,p_reason text default null
)
returns public.notification_events
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_event public.notification_events; v_previous text;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_event from public.notification_events where id=p_event_id for update;
  if not found then raise exception 'Notification event not found'; end if;
  v_previous:=v_event.status;
  if p_hold then
    if v_event.status<>'queued' then raise exception 'Only queued events can be held'; end if;
    if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
    update public.notification_events set status='held',held_at=now(),held_by=v_actor,hold_reason=btrim(p_reason),updated_at=now()
    where id=p_event_id returning * into v_event;
  else
    if v_event.status<>'held' then raise exception 'Only held events can be released'; end if;
    update public.notification_events set status='queued',held_at=null,held_by=null,hold_reason=null,next_attempt_at=now(),updated_at=now()
    where id=p_event_id returning * into v_event;
  end if;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,case when p_hold then 'notification.held' else 'notification.released' end,
    'notification_event',p_event_id::text,nullif(btrim(p_reason),''),
    jsonb_build_object('status',v_previous),jsonb_build_object('status',v_event.status,'hold_reason',v_event.hold_reason));
  return v_event;
end;
$$;

create or replace function public.claim_notification_events(p_limit integer default 25)
returns setof public.notification_events
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service role required'; end if;
  update public.notification_events e
  set status='cancelled',last_error='Delivery disabled by the recipient notification preferences.',updated_at=now()
  from public.notification_preferences pref
  where e.user_id=pref.user_id and e.status='queued'
    and ((e.channel='email' and not pref.email_enabled) or (e.channel='sms' and not pref.sms_enabled));

  return query
  with candidates as (
    select e.id from public.notification_events e
    where e.status='queued' and e.channel in ('email','sms')
      and e.next_attempt_at<=now()
      and (e.locked_at is null or e.locked_at<now()-interval '15 minutes')
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

create or replace function public.complete_notification_event(p_event_id uuid,p_provider_reference text default null)
returns public.notification_events
language plpgsql
security definer
set search_path = ''
as $$
declare v_event public.notification_events;
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service role required'; end if;
  update public.notification_events
  set status='sent',sent_at=now(),provider_reference=p_provider_reference,last_error=null,locked_at=null,updated_at=now()
  where id=p_event_id and status='sending'
  returning * into v_event;
  if not found then raise exception 'Notification event is not currently sending'; end if;
  return v_event;
end;
$$;

create or replace function public.fail_notification_event(p_event_id uuid,p_error text)
returns public.notification_events
language plpgsql
security definer
set search_path = ''
as $$
declare v_event public.notification_events; v_max_attempts integer; v_delay integer;
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service role required'; end if;
  select * into v_event from public.notification_events where id=p_event_id for update;
  if not found or v_event.status<>'sending' then raise exception 'Notification event is not currently sending'; end if;
  v_max_attempts:=case when v_event.manual_retry_used then v_event.attempt_count else 5 end;
  v_delay:=least(5*power(2,greatest(v_event.attempt_count-1,0)),240)::integer;
  update public.notification_events
  set status=case when v_event.attempt_count>=v_max_attempts then 'failed' else 'queued' end,
      next_attempt_at=case when v_event.attempt_count>=v_max_attempts then next_attempt_at else now()+make_interval(mins=>v_delay) end,
      last_error=left(coalesce(p_error,'Delivery failed without an error message.'),2000),
      locked_at=null,updated_at=now()
  where id=p_event_id returning * into v_event;
  return v_event;
end;
$$;

create or replace function public.mark_stale_notification_events_unconfirmed()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service role required'; end if;
  update public.notification_events
  set status='unconfirmed',unconfirmed_at=now(),last_error='Provider response timed out; delivery outcome is unknown and requires review.',locked_at=null,updated_at=now()
  where status='sending' and locked_at<now()-interval '15 minutes';
  get diagnostics v_count=row_count;
  return v_count;
end;
$$;

revoke all on function public.get_my_notification_preferences() from public,anon;
grant execute on function public.get_my_notification_preferences() to authenticated;
revoke all on function public.update_my_notification_preferences(boolean,boolean,boolean) from public,anon;
grant execute on function public.update_my_notification_preferences(boolean,boolean,boolean) to authenticated;
revoke all on function public.mark_notification_read(uuid) from public,anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;
revoke all on function public.enqueue_notification_event(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.admin_get_notification_events(text,integer,integer) from public,anon;
grant execute on function public.admin_get_notification_events(text,integer,integer) to authenticated;
revoke all on function public.admin_retry_notification(uuid,text) from public,anon;
grant execute on function public.admin_retry_notification(uuid,text) to authenticated;
revoke all on function public.admin_set_notification_hold(uuid,boolean,text) from public,anon;
grant execute on function public.admin_set_notification_hold(uuid,boolean,text) to authenticated;
revoke all on function public.claim_notification_events(integer) from public,anon,authenticated;
grant execute on function public.claim_notification_events(integer) to service_role;
revoke all on function public.complete_notification_event(uuid,text) from public,anon,authenticated;
grant execute on function public.complete_notification_event(uuid,text) to service_role;
revoke all on function public.fail_notification_event(uuid,text) from public,anon,authenticated;
grant execute on function public.fail_notification_event(uuid,text) to service_role;
revoke all on function public.mark_stale_notification_events_unconfirmed() from public,anon,authenticated;
grant execute on function public.mark_stale_notification_events_unconfirmed() to service_role;

create extension if not exists pg_cron;

-- Include the fixture's current scheduled time in the idempotency key so a
-- reschedule can create fresh reminders while old queued reminders are cancelled.
create or replace function public.enqueue_notification_event(
  p_user_id uuid,p_event_type text,p_payload jsonb
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
  v_dedupe:=p_event_type||':'||
    coalesce(p_payload->>'fixture_id',p_payload->>'membership_id',p_payload->>'season_team_id','event')||':'||
    coalesce(p_payload->>'scheduled_at','')||':'||p_user_id::text;

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

create or replace function public.enqueue_fixture_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_fixture record; v_user uuid; v_event text; v_count integer:=0; v_payload jsonb;
begin
  for v_fixture in
    select f.id,f.gameweek,f.scheduled_at,f.home_team_id,f.away_team_id,
      h.name as home_team_name,a.name as away_team_name
    from public.fixtures f
    join public.season_teams h on h.id=f.home_team_id
    join public.season_teams a on a.id=f.away_team_id
    where f.status='scheduled' and f.scheduled_at is not null
      and (
        f.scheduled_at between now()+interval '23 hours' and now()+interval '25 hours'
        or f.scheduled_at between now()+interval '2 hours' and now()+interval '4 hours'
      )
  loop
    v_event:=case
      when v_fixture.scheduled_at between now()+interval '23 hours' and now()+interval '25 hours' then 'fixture.reminder_24h'
      else 'fixture.reminder_3h'
    end;
    v_payload:=jsonb_build_object(
      'fixture_id',v_fixture.id,'gameweek',v_fixture.gameweek,
      'scheduled_at',v_fixture.scheduled_at,
      'home_team_name',v_fixture.home_team_name,'away_team_name',v_fixture.away_team_name,
      'reminder_hours',case when v_event='fixture.reminder_24h' then 24 else 3 end
    );
    for v_user in
      select distinct tm.user_id from public.team_memberships tm
      where tm.season_team_id in (v_fixture.home_team_id,v_fixture.away_team_id)
        and tm.status='active'
    loop
      perform public.enqueue_notification_event(v_user,v_event,v_payload);
      v_count:=v_count+1;
    end loop;
  end loop;
  return v_count;
end;
$$;

-- Cancel queued or in-app reminders when a fixture is postponed, cancelled,
-- completed or moved to a different kick-off time.
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
    update public.notification_events
    set status='cancelled',last_error='Fixture changed; reminder is no longer valid.',updated_at=now()
    where payload->>'fixture_id'=new.id::text
      and event_type in ('fixture.reminder_24h','fixture.reminder_3h')
      and ((channel in ('email','sms') and status in ('queued','held'))
        or (channel='in_app' and status='sent' and read_at is null));
    if new.status='completed' then return new; end if;
    v_event:='fixture.status_changed';
  elsif old.scheduled_at is distinct from new.scheduled_at then
    update public.notification_events
    set status='cancelled',last_error='Fixture time changed; reminder is no longer valid.',updated_at=now()
    where payload->>'fixture_id'=new.id::text
      and event_type in ('fixture.reminder_24h','fixture.reminder_3h')
      and ((channel in ('email','sms') and status in ('queued','held'))
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
$$;

revoke all on function public.enqueue_fixture_reminders() from public,anon,authenticated;
grant execute on function public.enqueue_fixture_reminders() to service_role;

-- A quarter-hour schedule catches the 24h and 3h windows without duplicate
-- sends; the outbox dedupe key protects against repeated scheduler executions.
select cron.unschedule(jobid) from cron.job where jobname='open-play-fixture-reminders';
select cron.schedule('open-play-fixture-reminders','*/15 * * * *','select public.enqueue_fixture_reminders();');

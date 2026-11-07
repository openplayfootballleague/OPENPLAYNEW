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
    coalesce(p_payload->>'scheduled_at',p_payload->>'changed_at','')||':'||p_user_id::text;

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

create or replace function public.notify_player_ban_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.is_banned is distinct from new.is_banned then
    perform public.enqueue_notification_event(
      new.user_id,
      case when new.is_banned then 'player.banned' else 'player.unbanned' end,
      jsonb_build_object(
        'player_name',new.full_name,
        'reason',case when new.is_banned then new.banned_reason else null end,
        'changed_at',now()
      )
    );
  end if;
  return new;
end;
$$;
drop trigger if exists notify_player_ban_change_trigger on public.players;
create trigger notify_player_ban_change_trigger
after update of is_banned on public.players
for each row execute function public.notify_player_ban_change();

revoke all on function public.notify_player_ban_change() from public,anon,authenticated;

create or replace function public.mark_notification_event_unconfirmed(p_event_id uuid,p_error text)
returns public.notification_events
language plpgsql
security definer
set search_path = ''
as $$
declare v_event public.notification_events;
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service role required'; end if;
  update public.notification_events
  set status='unconfirmed',
      unconfirmed_at=now(),
      last_error=left(coalesce(p_error,'Provider accepted message but delivery confirmation could not be stored.'),2000),
      locked_at=null,
      updated_at=now()
  where id=p_event_id and status='sending'
  returning * into v_event;
  if not found then raise exception 'Notification event is not currently sending'; end if;
  return v_event;
end;
$$;
revoke all on function public.mark_notification_event_unconfirmed(uuid,text) from public,anon,authenticated;
grant execute on function public.mark_notification_event_unconfirmed(uuid,text) to service_role;

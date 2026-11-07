create or replace function public.fail_notification_event_permanent(p_event_id uuid,p_error text)
returns public.notification_events
language plpgsql
security definer
set search_path = ''
as $$
declare v_event public.notification_events;
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service role required'; end if;
  update public.notification_events
  set status='failed',
      last_error=left(coalesce(p_error,'Permanent notification delivery error.'),2000),
      locked_at=null,
      updated_at=now()
  where id=p_event_id and status='sending'
  returning * into v_event;
  if not found then raise exception 'Notification event is not currently sending'; end if;
  return v_event;
end;
$$;
revoke all on function public.fail_notification_event_permanent(uuid,text) from public,anon,authenticated;
grant execute on function public.fail_notification_event_permanent(uuid,text) to service_role;

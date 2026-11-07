-- Allow the delivery worker to claim only channels with configured providers.
drop function if exists public.claim_notification_events(integer);
create function public.claim_notification_events(
  p_limit integer default 25,
  p_channels text[] default array['email','sms']::text[]
)
returns setof public.notification_events
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service role required'; end if;
  if p_channels is null or cardinality(p_channels)=0 or exists(select 1 from unnest(p_channels) c where c not in ('email','sms')) then
    raise exception 'Only email and SMS channels can be claimed';
  end if;

  update public.notification_events e
  set status='cancelled',last_error='Delivery disabled by the recipient notification preferences.',updated_at=now()
  from public.notification_preferences pref
  where e.user_id=pref.user_id and e.status='queued'
    and ((e.channel='email' and not pref.email_enabled) or (e.channel='sms' and not pref.sms_enabled));

  return query
  with candidates as (
    select e.id from public.notification_events e
    where e.status='queued' and e.channel=any(p_channels)
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
revoke all on function public.claim_notification_events(integer,text[]) from public,anon,authenticated;
grant execute on function public.claim_notification_events(integer,text[]) to service_role;

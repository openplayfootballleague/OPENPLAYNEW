create or replace function public.notify_team_membership_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_team_name text;
begin
  if not new.is_captain and (
    (tg_op='INSERT' and new.status='active') or
    (tg_op='UPDATE' and old.status is distinct from new.status and new.status in ('active','rejected'))
  ) then
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

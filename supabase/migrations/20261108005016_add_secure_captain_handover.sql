create or replace function public.handover_team_captain(
  p_season_team_id uuid,
  p_new_captain_membership_id uuid
)
returns public.team_memberships
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid:=auth.uid();
  v_current public.team_memberships;
  v_new public.team_memberships;
  v_player public.players;
  v_before jsonb;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if not public.is_active_team_captain(p_season_team_id) then
    raise exception 'Active team captain permission required';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('captain-handover:'||p_season_team_id::text,0)
  );

  select * into v_current
  from public.team_memberships
  where season_team_id=p_season_team_id
    and user_id=v_actor
    and status='active'
    and is_captain=true
  for update;
  if not found then raise exception 'Current captain membership not found'; end if;

  select * into v_new
  from public.team_memberships
  where id=p_new_captain_membership_id
    and season_team_id=p_season_team_id
    and status='active'
  for update;
  if not found then raise exception 'Choose an active player from your team'; end if;
  if v_new.id=v_current.id then raise exception 'Choose a different player as the new captain'; end if;

  select * into v_player from public.players where user_id=v_new.user_id for share;
  if not found or v_player.registration_status<>'registered' or v_player.is_banned then
    raise exception 'The new captain must be a registered, eligible player';
  end if;

  v_before:=jsonb_build_object(
    'previous_captain_user_id',v_current.user_id,
    'new_captain_user_id',v_new.user_id,
    'season_team_id',p_season_team_id
  );

  update public.team_memberships
  set is_captain=false,updated_at=now()
  where id=v_current.id;

  update public.team_memberships
  set is_captain=true,updated_at=now()
  where id=v_new.id
  returning * into v_new;

  insert into public.audit_log(
    actor_user_id,action,entity_type,entity_id,before_data,after_data
  ) values(
    v_actor,'team.captain.handed_over','team_membership',v_new.id::text,
    v_before,jsonb_build_object(
      'previous_captain_user_id',v_current.user_id,
      'new_captain_user_id',v_new.user_id,
      'season_team_id',p_season_team_id
    )
  );

  perform public.enqueue_notification_event(
    v_current.user_id,'team.captain.handover_completed',
    jsonb_build_object('season_team_id',p_season_team_id,'changed_at',now(),'role','former_captain')
  );
  perform public.enqueue_notification_event(
    v_new.user_id,'team.captain.handover_completed',
    jsonb_build_object('season_team_id',p_season_team_id,'changed_at',now(),'role','captain')
  );

  return v_new;
end;
$function$;

create or replace function public.admin_add_player_to_team(
  p_season_team_id uuid,
  p_user_id uuid,
  p_make_captain boolean default false
)
returns public.team_memberships
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid:=auth.uid();
  v_team public.season_teams;
  v_season public.seasons;
  v_player public.players;
  v_existing_captain uuid;
  v_membership public.team_memberships;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_user_id is null then raise exception 'Choose a player'; end if;

  select * into v_team
  from public.season_teams
  where id=p_season_team_id
  for share;
  if not found then raise exception 'Choose an existing team'; end if;
  if v_team.registration_status<>'approved' then
    raise exception 'Only approved teams can accept players';
  end if;

  select * into v_season
  from public.seasons
  where id=v_team.season_id
  for share;
  if not found or v_season.status in ('completed','archived') then
    raise exception 'Players cannot be added to a completed or archived season';
  end if;

  select * into v_player
  from public.players
  where user_id=p_user_id
  for share;
  if not found or v_player.registration_status<>'registered' or v_player.is_banned then
    raise exception 'Choose a registered, eligible player';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text || ':' || v_team.season_id::text, 0)
  );

  if exists(
    select 1
    from public.team_memberships tm
    join public.season_teams other_team on other_team.id=tm.season_team_id
    where tm.user_id=p_user_id
      and tm.status='active'
      and other_team.season_id=v_team.season_id
      and other_team.id<>p_season_team_id
  ) then
    raise exception 'This player is already active in another team in this season. Use the transfer workflow.';
  end if;

  if p_make_captain then
    select tm.user_id into v_existing_captain
    from public.team_memberships tm
    where tm.season_team_id=p_season_team_id
      and tm.status='active' and tm.is_captain=true
    limit 1;
    if v_existing_captain is not null and v_existing_captain<>p_user_id then
      raise exception 'This team already has an active captain. Complete a captain handover first.';
    end if;
  end if;

  insert into public.team_memberships as existing(
    season_team_id,user_id,status,is_captain,joined_at,left_at
  )
  values(
    p_season_team_id,p_user_id,'active',coalesce(p_make_captain,false),now(),null
  )
  on conflict(season_team_id,user_id) do update
    set status='active',
        is_captain=(existing.is_captain or excluded.is_captain),
        joined_at=coalesce(existing.joined_at,now()),
        left_at=null
  returning * into v_membership;

  insert into public.audit_log(
    actor_user_id,action,entity_type,entity_id,after_data
  ) values(
    v_actor,
    case when v_membership.is_captain then 'team.player_added_as_captain' else 'team.player_added_by_admin' end,
    'team_membership',v_membership.id::text,
    jsonb_build_object(
      'season_team_id',p_season_team_id,
      'user_id',p_user_id,
      'is_captain',v_membership.is_captain
    )
  );
  return v_membership;
end;
$function$;

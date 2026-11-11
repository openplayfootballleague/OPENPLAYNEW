create or replace function public.resolve_team_registration(
  p_season_team_id uuid,
  p_decision text,
  p_reason text default null
)
returns public.season_teams
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid:=auth.uid();
  v_season_team public.season_teams;
  v_season public.seasons;
  v_player public.players;
  v_captain_user_id uuid;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  select * into v_season_team
  from public.season_teams
  where id=p_season_team_id and registration_status='pending'
  for update;
  if not found then raise exception 'No pending team registration exists'; end if;

  select user_id into v_captain_user_id
  from public.team_memberships
  where season_team_id=p_season_team_id and status='pending' and is_captain=false
  for update;
  if v_captain_user_id is null then
    raise exception 'Team registration has no pending applicant to appoint as captain';
  end if;

  if p_decision='approved' then
    select * into v_season
    from public.seasons
    where id=v_season_team.season_id
    for share;
    if not found or v_season.status<>'registration_open' then
      raise exception 'Team registrations are closed for this season';
    end if;

    select * into v_player
    from public.players
    where user_id=v_captain_user_id
    for share;
    if not found or v_player.registration_status<>'registered' or v_player.is_banned then
      raise exception 'The proposed captain is no longer an eligible registered player';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_captain_user_id::text || ':' || v_season_team.season_id::text, 0)
    );

    if exists(
      select 1
      from public.team_memberships tm
      join public.season_teams other_team on other_team.id=tm.season_team_id
      where tm.user_id=v_captain_user_id
        and tm.status='active'
        and other_team.season_id=v_season_team.season_id
        and tm.season_team_id<>p_season_team_id
    ) then
      raise exception 'The proposed captain is already active in another team in this season. Resolve that membership before approving this team.';
    end if;
  end if;

  update public.season_teams set
    registration_status=p_decision,
    approved_at=case when p_decision='approved' then now() else null end,
    approved_by=case when p_decision='approved' then v_actor else null end
  where id=p_season_team_id returning * into v_season_team;

  if p_decision='approved' then
    update public.team_memberships
    set status='active',is_captain=true,joined_at=now(),left_at=null
    where season_team_id=p_season_team_id and user_id=v_captain_user_id;
  else
    update public.team_memberships
    set status='rejected',left_at=now()
    where season_team_id=p_season_team_id and user_id=v_captain_user_id;
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  values(v_actor,'team.registration.'||p_decision,'season_team',p_season_team_id::text,
    nullif(trim(p_reason),''),jsonb_build_object(
      'registration_status',v_season_team.registration_status,
      'captain_user_id',v_captain_user_id
    ));
  return v_season_team;
end;
$function$;

-- Serialize membership-request authorization against captain handovers and
-- league-admin role/location-assignment revocation. Lock order matches the
-- competing workflows: captain advisory lock -> captain membership row;
-- league_admin role row -> location assignment row; then request row.
create or replace function public.resolve_team_membership_request(
  p_membership_id uuid,
  p_decision text
)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_membership public.team_memberships;
  v_team public.season_teams;
  v_season public.seasons;
  v_player public.players;
  v_location_id uuid;
  v_captain_membership_id uuid;
  v_role_id uuid;
  v_assignment_id uuid;
  v_authorized boolean := false;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;

  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  select *
  into v_membership
  from public.team_memberships
  where id = p_membership_id
    and status = 'pending';

  if not found then
    raise exception 'No pending team request exists';
  end if;

  select l.location_id
  into v_location_id
  from public.season_teams st
  join public.seasons s on s.id = st.season_id
  join public.leagues l on l.id = s.league_id
  where st.id = v_membership.season_team_id;

  if v_location_id is null then
    raise exception 'The requested team has no valid competition location';
  end if;

  -- handover_team_captain takes this exact transaction lock before changing
  -- captain membership rows. Whichever workflow acquires it first completes
  -- its authorization-sensitive transition before the other proceeds.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'captain-handover:' || v_membership.season_team_id::text,
      0
    )
  );

  select tm.id
  into v_captain_membership_id
  from public.team_memberships tm
  where tm.season_team_id = v_membership.season_team_id
    and tm.user_id = v_actor
    and tm.status = 'active'
    and tm.is_captain = true
  for share;

  if v_captain_membership_id is not null then
    v_authorized := true;
  else
    -- Role revocation locks this same user_roles row FOR UPDATE before
    -- removing location assignments. FOR SHARE makes the authorization
    -- stable until this transaction commits.
    select ur.id
    into v_role_id
    from public.user_roles ur
    where ur.user_id = v_actor
      and ur.role in ('admin','super_admin')
    for share;

    if v_role_id is not null then
      v_authorized := true;
    else
      select ur.id
      into v_role_id
      from public.user_roles ur
      where ur.user_id = v_actor
        and ur.role = 'league_admin'
      for share;

      if v_role_id is not null then
        -- Assignment revocation deletes this row; this lock prevents access
        -- being revoked between authorization and the membership write.
        select la.id
        into v_assignment_id
        from public.location_admin_assignments la
        where la.user_id = v_actor
          and la.location_id = v_location_id
        for share;

        v_authorized := v_assignment_id is not null;
      end if;
    end if;
  end if;

  if not v_authorized then
    raise exception 'Captain or assigned location administrator permission required';
  end if;

  -- Re-read and lock the request after stable authorization. A concurrent
  -- decision on the same request cannot be applied twice.
  select *
  into v_membership
  from public.team_memberships
  where id = p_membership_id
    and status = 'pending'
  for update;

  if not found then
    raise exception 'No pending team request exists';
  end if;

  if p_decision = 'approved' then
    select *
    into v_team
    from public.season_teams
    where id = v_membership.season_team_id
    for share;

    if not found or v_team.registration_status <> 'approved' then
      raise exception 'Only approved teams can accept players';
    end if;

    select *
    into v_season
    from public.seasons
    where id = v_team.season_id
    for share;

    if not found or v_season.status not in ('registration_open','active') then
      raise exception 'Membership approvals are closed for this season';
    end if;

    select *
    into v_player
    from public.players
    where user_id = v_membership.user_id
    for share;

    if not found or v_player.registration_status <> 'registered' or v_player.is_banned then
      raise exception 'Only registered, eligible players can join a team';
    end if;

    -- Serialize approvals for the same player/season across different teams.
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        v_membership.user_id::text || ':' || v_team.season_id::text,
        0
      )
    );

    if exists (
      select 1
      from public.team_memberships tm
      join public.season_teams other_team on other_team.id = tm.season_team_id
      where tm.user_id = v_membership.user_id
        and tm.status = 'active'
        and other_team.season_id = v_team.season_id
        and tm.season_team_id <> v_membership.season_team_id
    ) then
      raise exception 'This player is already active in another team in this season. Use the transfer workflow.';
    end if;
  end if;

  update public.team_memberships
  set
    status = case
      when p_decision = 'approved' then 'active'::public.membership_status
      else 'rejected'::public.membership_status
    end,
    joined_at = case when p_decision = 'approved' then now() else joined_at end,
    left_at = case when p_decision = 'rejected' then now() else null end
  where id = p_membership_id
  returning * into v_membership;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values (
    v_actor,
    'team.membership.' || p_decision,
    'team_membership',
    p_membership_id::text,
    jsonb_build_object('status',v_membership.status)
  );

  return v_membership;
end;
$function$;

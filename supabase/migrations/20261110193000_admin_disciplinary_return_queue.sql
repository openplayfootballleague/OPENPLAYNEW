-- Location-scoped queue and reactivation workflow for the existing referee discipline ledger.
-- Strike counts remain on public.players and approved incidents remain in referee_disciplinary_events.

create or replace function public.admin_list_disciplinary_suspensions(
  p_location_id uuid default null
)
returns table (
  competition_player_id uuid,
  player_name text,
  disciplinary_strikes integer,
  last_straight_red_at timestamptz,
  last_fixture_id uuid,
  last_gameweek integer,
  last_team_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_location_id is not null
     and not public.has_global_admin_role()
     and not public.can_administer_location(p_location_id) then
    raise exception 'You are not assigned to this location';
  end if;

  return query
  select
    p.competition_player_id,
    coalesce(nullif(btrim(cpi.display_name), ''), p.full_name)::text,
    p.disciplinary_strikes,
    last_incident.created_at,
    last_incident.fixture_id,
    last_incident.gameweek,
    last_incident.team_name
  from public.players p
  left join public.competition_player_identities cpi
    on cpi.id = p.competition_player_id
  join lateral (
    select e.created_at, f.id as fixture_id, f.gameweek, st.name as team_name
    from public.referee_disciplinary_events e
    join public.referee_match_reports r
      on r.id = e.report_id and r.status = 'approved'
    join public.fixtures f on f.id = e.fixture_id
    join public.seasons s on s.id = f.season_id
    join public.leagues l on l.id = s.league_id
    join public.season_teams st on st.id = e.season_team_id
    where e.competition_player_id = p.competition_player_id
      and e.strike_applied is true
      and e.voided_at is null
      and (p_location_id is null or l.location_id = p_location_id)
      and (public.has_global_admin_role() or public.can_administer_location(l.location_id))
    order by e.created_at desc
    limit 1
  ) last_incident on true
  where p.disciplinary_inactive is true
    and p.competition_player_id is not null
  order by p.disciplinary_strikes desc, last_incident.created_at desc;
end;
$$;
revoke all on function public.admin_list_disciplinary_suspensions(uuid) from public, anon;
grant execute on function public.admin_list_disciplinary_suspensions(uuid) to authenticated;

create or replace function public.admin_reactivate_disciplined_player(
  p_competition_player_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_player public.players;
  v_allowed boolean := false;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if length(btrim(coalesce(p_reason, ''))) not between 5 and 500 then
    raise exception 'A reactivation reason of 5 to 500 characters is required';
  end if;

  select * into v_player
  from public.players
  where competition_player_id = p_competition_player_id
  for update;
  if not found then
    raise exception 'Active player account not found for this competition identity';
  end if;
  if v_player.disciplinary_inactive is not true then
    raise exception 'This player is not awaiting disciplinary return approval';
  end if;

  select exists (
    select 1
    from public.referee_disciplinary_events e
    join public.referee_match_reports r
      on r.id = e.report_id and r.status = 'approved'
    join public.fixtures f on f.id = e.fixture_id
    join public.seasons s on s.id = f.season_id
    join public.leagues l on l.id = s.league_id
    where e.competition_player_id = p_competition_player_id
      and e.strike_applied is true
      and e.voided_at is null
      and (public.has_global_admin_role() or public.can_administer_location(l.location_id))
  ) into v_allowed;

  if not v_allowed then
    raise exception 'Administrator access to a location in this player''s disciplinary history is required';
  end if;

  update public.players
  set disciplinary_inactive = false, updated_at = now()
  where user_id = v_player.user_id;

  insert into public.audit_log(
    actor_user_id, action, entity_type, entity_id, reason, before_data, after_data
  )
  values (
    v_actor,
    'player.disciplinary_reactivated',
    'player',
    v_player.user_id::text,
    btrim(p_reason),
    jsonb_build_object(
      'disciplinary_strikes', v_player.disciplinary_strikes,
      'disciplinary_inactive', true
    ),
    jsonb_build_object(
      'disciplinary_strikes', v_player.disciplinary_strikes,
      'disciplinary_inactive', false
    )
  );

  perform public.enqueue_notification_event(
    v_player.user_id,
    'player_disciplinary_return_approved',
    jsonb_build_object(
      'competition_player_id', p_competition_player_id::text,
      'title', 'Approved to return to play',
      'message', 'An Open Play administrator has approved your return. Your disciplinary history remains on your competition record.',
      'reason', btrim(p_reason),
      'changed_at', now()::text,
      'url', '/player-hub'
    )
  );
end;
$$;
revoke all on function public.admin_reactivate_disciplined_player(uuid, text) from public, anon;
grant execute on function public.admin_reactivate_disciplined_player(uuid, text) to authenticated;

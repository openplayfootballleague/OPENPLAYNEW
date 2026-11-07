-- Administrators can review submitted sheets and make a reasoned, auditable amendment.
create or replace function public.get_admin_team_sheets()
returns table(
  team_sheet_id uuid,
  fixture_id uuid,
  season_team_id uuid,
  team_name text,
  opponent_name text,
  gameweek integer,
  scheduled_at timestamptz,
  competition_format public.competition_format,
  is_locked boolean,
  submitted_at timestamptz,
  players jsonb,
  roster jsonb
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

  return query
  select
    s.id,
    s.fixture_id,
    s.season_team_id,
    st.name,
    opponent.name,
    f.gameweek,
    f.scheduled_at,
    l.format,
    s.is_locked,
    s.submitted_at,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'membership_id', tm.id,
        'player_name', p.full_name,
        'role', tsp.role,
        'is_goalkeeper', tsp.is_goalkeeper,
        'squad_number_snapshot', tsp.squad_number_snapshot
      ) order by case when tsp.role = 'starter' then 0 else 1 end, p.full_name)
      from public.fixture_team_sheet_players tsp
      join public.team_memberships tm
        on tm.user_id = tsp.user_id and tm.season_team_id = s.season_team_id
      join public.players p on p.user_id = tsp.user_id
      where tsp.team_sheet_id = s.id
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'membership_id', tm.id,
        'player_name', p.full_name,
        'squad_number', tm.squad_number
      ) order by p.full_name)
      from public.team_memberships tm
      join public.players p on p.user_id = tm.user_id
      where tm.season_team_id = s.season_team_id
        and tm.status = 'active'
        and p.registration_status = 'registered'
        and p.is_banned = false
    ), '[]'::jsonb)
  from public.fixture_team_sheets s
  join public.fixtures f on f.id = s.fixture_id
  join public.seasons se on se.id = f.season_id
  join public.leagues l on l.id = se.league_id
  join public.season_teams st on st.id = s.season_team_id
  join public.season_teams opponent
    on opponent.id = case when f.home_team_id = s.season_team_id then f.away_team_id else f.home_team_id end
  order by f.scheduled_at desc nulls last, f.gameweek desc, st.name;
end;
$$;

create or replace function public.admin_amend_team_sheet(
  p_team_sheet_id uuid,
  p_starters uuid[],
  p_substitutes uuid[] default '{}'::uuid[],
  p_goalkeeper_membership_id uuid default null,
  p_reason text default null
)
returns public.fixture_team_sheets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_sheet public.fixture_team_sheets;
  v_fixture public.fixtures;
  v_format public.competition_format;
  v_expected_starters integer;
  v_max_substitutes integer;
  v_all_memberships uuid[];
  v_before jsonb;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'Enter a reason of at least 5 characters for this amendment';
  end if;

  select * into v_sheet
  from public.fixture_team_sheets
  where id = p_team_sheet_id
  for update;
  if not found then raise exception 'Team sheet not found'; end if;
  if not v_sheet.is_locked then raise exception 'Only submitted, locked team sheets can be amended here'; end if;

  select * into v_fixture from public.fixtures where id = v_sheet.fixture_id;
  if not found then raise exception 'Fixture not found'; end if;
  if v_sheet.season_team_id not in (v_fixture.home_team_id, v_fixture.away_team_id) then
    raise exception 'Team sheet does not belong to this fixture';
  end if;

  select l.format into v_format
  from public.seasons s join public.leagues l on l.id = s.league_id
  where s.id = v_fixture.season_id;
  v_expected_starters := case when v_format = 'six_a_side' then 6 else 7 end;
  v_max_substitutes := case when v_format = 'six_a_side' then 3 else 4 end;

  if coalesce(cardinality(p_starters), 0) <> v_expected_starters then
    raise exception 'Select exactly % starting players', v_expected_starters;
  end if;
  if coalesce(cardinality(p_substitutes), 0) > v_max_substitutes then
    raise exception 'Select no more than % substitutes', v_max_substitutes;
  end if;
  if p_goalkeeper_membership_id is null or not (p_goalkeeper_membership_id = any(coalesce(p_starters, '{}'::uuid[]))) then
    raise exception 'Select one goalkeeper from your starting players';
  end if;

  v_all_memberships := coalesce(p_starters, '{}'::uuid[]) || coalesce(p_substitutes, '{}'::uuid[]);
  if (select count(distinct x) from unnest(v_all_memberships) x) <> cardinality(v_all_memberships) then
    raise exception 'A player can only appear once on a team sheet';
  end if;

  if exists (
    select 1 from unnest(v_all_memberships) x
    where not exists (
      select 1 from public.team_memberships tm
      join public.players p on p.user_id = tm.user_id
      where tm.id = x and tm.season_team_id = v_sheet.season_team_id
        and tm.status = 'active' and p.registration_status = 'registered' and p.is_banned = false
    )
  ) then raise exception 'Every selected player must have an active, approved membership in this team'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', tsp.user_id, 'role', tsp.role, 'is_goalkeeper', tsp.is_goalkeeper,
    'squad_number_snapshot', tsp.squad_number_snapshot
  )), '[]'::jsonb)
  into v_before
  from public.fixture_team_sheet_players tsp
  where tsp.team_sheet_id = v_sheet.id;

  delete from public.fixture_team_sheet_players where team_sheet_id = v_sheet.id;

  insert into public.fixture_team_sheet_players(team_sheet_id, user_id, role, squad_number_snapshot, is_goalkeeper)
  select v_sheet.id, tm.user_id, 'starter', tm.squad_number, tm.id = p_goalkeeper_membership_id
  from public.team_memberships tm
  where tm.id = any(coalesce(p_starters, '{}'::uuid[]))
    and tm.season_team_id = v_sheet.season_team_id and tm.status = 'active';

  insert into public.fixture_team_sheet_players(team_sheet_id, user_id, role, squad_number_snapshot, is_goalkeeper)
  select v_sheet.id, tm.user_id, 'substitute', tm.squad_number, false
  from public.team_memberships tm
  where tm.id = any(coalesce(p_substitutes, '{}'::uuid[]))
    and tm.season_team_id = v_sheet.season_team_id and tm.status = 'active';

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, before_data, after_data)
  values (
    v_actor, 'fixture.team_sheet.admin_amended', 'fixture_team_sheet', v_sheet.id::text,
    btrim(p_reason), v_before,
    jsonb_build_object(
      'starters', p_starters,
      'substitutes', p_substitutes,
      'goalkeeper_membership_id', p_goalkeeper_membership_id,
      'reason', btrim(p_reason),
      'is_locked', true
    )
  );

  return v_sheet;
end;
$$;

revoke all on function public.get_admin_team_sheets() from public, anon;
grant execute on function public.get_admin_team_sheets() to authenticated;
revoke all on function public.admin_amend_team_sheet(uuid, uuid[], uuid[], uuid, text) from public, anon;
grant execute on function public.admin_amend_team_sheet(uuid, uuid[], uuid[], uuid, text) to authenticated;

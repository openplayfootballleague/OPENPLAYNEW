-- Enforce one next-required fixture per captain team. A fixture advances only
-- when its status is authoritatively completed or cancelled; submitted sheets
-- and calendar dates do not advance the sequence.
create or replace function public.captain_next_required_fixture(p_season_team_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_fixture_id uuid;
begin
  if v_actor is null or not public.is_active_team_captain(p_season_team_id) then
    raise exception 'Active team captain permission required';
  end if;

  select f.id
    into v_fixture_id
  from public.fixtures f
  join public.season_teams st on st.id = p_season_team_id
  where f.season_id = st.season_id
    and p_season_team_id in (f.home_team_id, f.away_team_id)
    and f.status not in ('completed', 'cancelled')
  order by f.gameweek, f.fixture_number
  limit 1;

  return v_fixture_id;
end;
$$;

revoke all on function public.captain_next_required_fixture(uuid) from public, anon, authenticated;

-- The captain projection exposes only the next required fixture for each
-- captain-controlled season team. It never exposes earlier or later choices.
create or replace function public.get_captain_fixtures()
returns table(
  fixture_id uuid,
  season_team_id uuid,
  team_name text,
  opponent_name text,
  gameweek integer,
  scheduled_at timestamptz,
  competition_format text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.team_memberships tm
    where tm.user_id = v_user_id and tm.is_captain = true and tm.status = 'active'
  ) then raise exception 'Active captain permission required'; end if;

  return query
  select f.id, own.id, own.name, opp.name, f.gameweek, f.scheduled_at, l.format::text
  from public.team_memberships captain
  join public.season_teams own on own.id = captain.season_team_id
  cross join lateral (
    select next_fixture.id
    from public.fixtures next_fixture
    where next_fixture.season_id = own.season_id
      and own.id in (next_fixture.home_team_id, next_fixture.away_team_id)
      and next_fixture.status not in ('completed', 'cancelled')
    order by next_fixture.gameweek, next_fixture.fixture_number
    limit 1
  ) next_required
  join public.fixtures f on f.id = next_required.id and f.status = 'scheduled'
  join public.season_teams opp
    on opp.id = case when f.home_team_id = own.id then f.away_team_id else f.home_team_id end
  join public.seasons s on s.id = f.season_id
  join public.leagues l on l.id = s.league_id
  where captain.user_id = v_user_id
    and captain.is_captain = true
    and captain.status = 'active'
  order by own.name;
end;
$$;

-- Lock down every captain-side write at the database boundary, including
-- direct table writes that might bypass the UI or an RPC.
create or replace function public.enforce_captain_next_fixture_team_sheet()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fixture_id uuid;
  v_team_id uuid;
  v_fixture_status public.fixture_status;
begin
  -- Trusted service-role erasure jobs may detach the submitter account link
  -- from historical sheets. Ordinary clients still need captain permission.
  if coalesce(pg_catalog.current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    return new;
  end if;

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if tg_op = 'DELETE' then
    select s.fixture_id, s.season_team_id into v_fixture_id, v_team_id
    from public.fixture_team_sheets s where s.id = old.id;
  else
    v_fixture_id := new.fixture_id;
    v_team_id := new.season_team_id;
  end if;

  -- A location administrator who is also the active team captain keeps the
  -- captain workflow. Non-captain administrators must use the audited
  -- post-match amendment RPC instead of writing sheet rows directly.
  if public.has_platform_role() and not public.is_active_team_captain(v_team_id) then
    raise exception 'Administrators must amend submitted sheets through admin_amend_team_sheet';
  end if;

  if not public.is_active_team_captain(v_team_id) then
    raise exception 'Active team captain permission required';
  end if;

  select f.status into v_fixture_status
  from public.fixtures f
  where f.id = v_fixture_id
    and v_team_id in (f.home_team_id, f.away_team_id)
  for update;

  if not found then raise exception 'Fixture not found or team is not a participant'; end if;
  if v_fixture_status <> 'scheduled' then
    raise exception 'Captain team sheets are available only before a scheduled fixture';
  end if;
  if public.captain_next_required_fixture(v_team_id) is distinct from v_fixture_id then
    raise exception 'Only the next required fixture can be edited by a captain';
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists fixture_team_sheets_next_fixture_guard on public.fixture_team_sheets;
create trigger fixture_team_sheets_next_fixture_guard
before insert or update on public.fixture_team_sheets
for each row execute function public.enforce_captain_next_fixture_team_sheet();

-- The sheet-player trigger protects the child rows and permits administrator
-- amendments only through the dedicated, reasoned RPC after a fixture is played.
create or replace function public.enforce_team_sheet_player_amendment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sheet_id uuid;
  v_fixture_id uuid;
  v_team_id uuid;
  v_status public.fixture_status;
  v_locked boolean;
begin
  -- Trusted service-role erasure jobs must be able to detach account-linked
  -- child rows while preserving the immutable competition identity. This
  -- bypass is limited to the service-role JWT; ordinary clients still require
  -- an authenticated captain or an authorised administrator.
  if coalesce(pg_catalog.current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if auth.uid() is null then raise exception 'Authentication required'; end if;
  v_sheet_id := case when tg_op = 'DELETE' then old.team_sheet_id else new.team_sheet_id end;

  select s.fixture_id, s.season_team_id, s.is_locked, f.status
    into v_fixture_id, v_team_id, v_locked, v_status
  from public.fixture_team_sheets s
  join public.fixtures f on f.id = s.fixture_id
  where s.id = v_sheet_id
  for update of s;

  if not found then raise exception 'Team sheet not found'; end if;

  if public.has_platform_role() then
    -- Administrators may use the post-match amendment RPC for completed,
    -- locked sheets. An administrator who is also the active team captain
    -- can still use the captain workflow for the next scheduled fixture.
    if v_locked and v_status = 'completed' then
      if tg_op = 'DELETE' then return old; end if;
      return new;
    end if;
    if not public.is_active_team_captain(v_team_id) then
      raise exception 'Administrators may amend only locked sheets for completed fixtures';
    end if;
  end if;

  if not public.is_active_team_captain(v_team_id) then
    raise exception 'Active team captain permission required';
  end if;
  if v_status <> 'scheduled' or public.captain_next_required_fixture(v_team_id) is distinct from v_fixture_id then
    raise exception 'Only the next required scheduled fixture can be edited by a captain';
  end if;
  -- The RPC layer enforces the submitted lock before it changes child rows;
  -- submission itself must be able to replace draft rows after locking the parent.
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists fixture_team_sheet_players_next_fixture_guard on public.fixture_team_sheet_players;
create trigger fixture_team_sheet_players_next_fixture_guard
before insert or update or delete on public.fixture_team_sheet_players
for each row execute function public.enforce_team_sheet_player_amendment();

-- Trigger execution does not require client EXECUTE privileges. Keep these
-- SECURITY DEFINER trigger functions unavailable as direct PostgREST RPCs.
revoke all on function public.enforce_captain_next_fixture_team_sheet() from public, anon, authenticated;
revoke all on function public.enforce_team_sheet_player_amendment() from public, anon, authenticated;

-- Captain reads are restricted to the same next-required scheduled fixture.
create or replace function public.get_captain_team_sheet(p_fixture_id uuid)
returns table(
  season_team_id uuid,
  starters uuid[],
  substitutes uuid[],
  goalkeeper_membership_id uuid,
  is_locked boolean,
  submitted_at timestamptz,
  draft_saved_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'Authentication required'; end if;

  return query
  select
    s.season_team_id,
    coalesce(array_agg(tm.id) filter (where tsp.role = 'starter'), '{}'::uuid[]),
    coalesce(array_agg(tm.id) filter (where tsp.role = 'substitute'), '{}'::uuid[]),
    (array_agg(tm.id) filter (where tsp.is_goalkeeper))[1],
    s.is_locked,
    s.submitted_at,
    s.draft_saved_at
  from public.fixture_team_sheets s
  join public.fixtures f on f.id = s.fixture_id
  join public.team_memberships captain
    on captain.season_team_id = s.season_team_id
    and captain.user_id = v_actor
    and captain.is_captain = true
    and captain.status = 'active'
  left join public.fixture_team_sheet_players tsp on tsp.team_sheet_id = s.id
  left join public.team_memberships tm
    on tm.user_id = tsp.user_id
    and tm.season_team_id = s.season_team_id
    and tm.status = 'active'
  where s.fixture_id = p_fixture_id
    and f.status = 'scheduled'
    and public.captain_next_required_fixture(s.season_team_id) = p_fixture_id
  group by s.id;
end;
$$;

-- Explicitly keep the admin amendment API as the only post-match correction
-- route. Its existing reason and audit requirements remain in force.
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
  if not public.can_administer_location((
    select l.location_id
    from public.fixture_team_sheets sh
    join public.fixtures f on f.id = sh.fixture_id
    join public.seasons s on s.id = f.season_id
    join public.leagues l on l.id = s.league_id
    where sh.id = p_team_sheet_id
  )) then
    raise exception 'You are not assigned to this location';
  end if;
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'Enter a reason of at least 5 characters for this amendment';
  end if;

  select * into v_sheet from public.fixture_team_sheets where id = p_team_sheet_id for update;
  if not found then raise exception 'Team sheet not found'; end if;
  if not v_sheet.is_locked then raise exception 'Only submitted, locked team sheets can be amended here'; end if;

  select * into v_fixture from public.fixtures where id = v_sheet.fixture_id;
  if not found then raise exception 'Fixture not found'; end if;
  if v_fixture.status <> 'completed' then
    raise exception 'A team sheet can be amended only after its fixture is marked completed';
  end if;
  if v_sheet.season_team_id not in (v_fixture.home_team_id, v_fixture.away_team_id) then
    raise exception 'Team sheet does not belong to this fixture';
  end if;

  select l.format into v_format from public.seasons s join public.leagues l on l.id = s.league_id where s.id = v_fixture.season_id;
  v_expected_starters := case when v_format = 'six_a_side' then 6 else 7 end;
  v_max_substitutes := case when v_format = 'six_a_side' then 3 else 4 end;
  if coalesce(cardinality(p_starters), 0) <> v_expected_starters then raise exception 'Select exactly % starting players', v_expected_starters; end if;
  if coalesce(cardinality(p_substitutes), 0) > v_max_substitutes then raise exception 'Select no more than % substitutes', v_max_substitutes; end if;
  if p_goalkeeper_membership_id is null or not (p_goalkeeper_membership_id = any(coalesce(p_starters, '{}'::uuid[]))) then raise exception 'Select one goalkeeper from your starting players'; end if;

  v_all_memberships := coalesce(p_starters, '{}'::uuid[]) || coalesce(p_substitutes, '{}'::uuid[]);
  if (select count(distinct x) from unnest(v_all_memberships) x) <> cardinality(v_all_memberships) then raise exception 'A player can only appear once on a team sheet'; end if;
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
  into v_before from public.fixture_team_sheet_players tsp where tsp.team_sheet_id = v_sheet.id;

  delete from public.fixture_team_sheet_players where team_sheet_id = v_sheet.id;
  insert into public.fixture_team_sheet_players(team_sheet_id, user_id, role, squad_number_snapshot, is_goalkeeper)
  select v_sheet.id, tm.user_id, 'starter', tm.squad_number, tm.id = p_goalkeeper_membership_id
  from public.team_memberships tm where tm.id = any(coalesce(p_starters, '{}'::uuid[]))
    and tm.season_team_id = v_sheet.season_team_id and tm.status = 'active';
  insert into public.fixture_team_sheet_players(team_sheet_id, user_id, role, squad_number_snapshot, is_goalkeeper)
  select v_sheet.id, tm.user_id, 'substitute', tm.squad_number, false
  from public.team_memberships tm where tm.id = any(coalesce(p_substitutes, '{}'::uuid[]))
    and tm.season_team_id = v_sheet.season_team_id and tm.status = 'active';

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, reason, before_data, after_data)
  values (
    v_actor, 'fixture.team_sheet.admin_amended', 'fixture_team_sheet', v_sheet.id::text,
    btrim(p_reason), v_before,
    jsonb_build_object('starters', p_starters, 'substitutes', p_substitutes,
      'goalkeeper_membership_id', p_goalkeeper_membership_id, 'reason', btrim(p_reason), 'is_locked', true)
  );
  return v_sheet;
end;
$$;

revoke all on function public.get_captain_fixtures() from public, anon;
grant execute on function public.get_captain_fixtures() to authenticated;
revoke all on function public.get_captain_team_sheet(uuid) from public, anon;
grant execute on function public.get_captain_team_sheet(uuid) to authenticated;
revoke all on function public.admin_amend_team_sheet(uuid, uuid[], uuid[], uuid, text) from public, anon;
grant execute on function public.admin_amend_team_sheet(uuid, uuid[], uuid[], uuid, text) to authenticated;

-- Captains and administrators must use the protected RPCs for every sheet
-- write. Keep SELECT access governed by RLS, but remove direct client DML so
-- callers cannot bypass the next-fixture and audited-amendment boundaries.
revoke insert, update, delete on table
  public.fixture_team_sheets,
  public.fixture_team_sheet_players
from public, anon, authenticated;

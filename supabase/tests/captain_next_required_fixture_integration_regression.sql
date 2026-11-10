-- Regression assertions for the captain next-fixture and post-match amendment
-- migration. Run after replaying all migrations in an isolated Supabase database.
do $captain_fixture_workflow$
declare
  v_projection text;
  v_sheet_reader text;
  v_admin_amendment text;
begin
  if to_regprocedure('public.captain_next_required_fixture(uuid)') is null then
    raise exception 'Missing next-required fixture resolver';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.fixture_team_sheets'::regclass
      and tgname = 'fixture_team_sheets_next_fixture_guard'
      and not tgisinternal
  ) then
    raise exception 'Missing parent team-sheet next-fixture guard';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.fixture_team_sheet_players'::regclass
      and tgname = 'fixture_team_sheet_players_next_fixture_guard'
      and not tgisinternal
  ) then
    raise exception 'Missing team-sheet player amendment guard';
  end if;

  select pg_get_functiondef('public.get_captain_fixtures()'::regprocedure)
    into v_projection;
  if position('next_fixture.status not in' in lower(v_projection)) = 0
     or position('next_fixture.fixture_number' in lower(v_projection)) = 0 then
    raise exception 'Captain fixture projection does not use ordered non-terminal fixtures';
  end if;

  select pg_get_functiondef('public.get_captain_team_sheet(uuid)'::regprocedure)
    into v_sheet_reader;
  -- Normalize pg_get_functiondef formatting across PostgreSQL versions.
  v_sheet_reader := regexp_replace(lower(v_sheet_reader), E'\\s+', '', 'g');
  if position('captain_next_required_fixture' in v_sheet_reader) = 0
     or position('f.status=''scheduled''' in v_sheet_reader) = 0 then
    raise exception 'Captain sheet reader does not enforce next scheduled fixture';
  end if;

  select pg_get_functiondef(
    'public.admin_amend_team_sheet(uuid,uuid[],uuid[],uuid,text)'::regprocedure
  ) into v_admin_amendment;
  -- Normalize catalog formatting so the assertions test policy, not whitespace.
  v_admin_amendment := regexp_replace(lower(v_admin_amendment), E'\\s+', '', 'g');
  if position('v_fixture.status<>''completed''' in v_admin_amendment) = 0
     or position('length(btrim(p_reason))<5' in v_admin_amendment) = 0
     or position('fixture.team_sheet.admin_amended' in v_admin_amendment) = 0
     or position('assert_admin_location_context' in v_admin_amendment) = 0 then
    raise exception 'Admin amendment is missing completed-fixture, reason, audit, or location-scope safeguards';
  end if;

  raise notice 'Captain next-fixture and post-match amendment regression assertions passed';
end;
$captain_fixture_workflow$;

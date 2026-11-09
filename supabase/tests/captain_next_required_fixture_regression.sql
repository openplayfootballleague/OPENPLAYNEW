-- Regression assertions for next-required captain fixtures and safe post-match amendments.
-- Run after replaying all migrations in an isolated Supabase database.
do $captain_fixture_workflow$
declare
  v_projection text;
  v_sheet_reader text;
  v_admin_amendment text;
  v_parent_guard text;
  v_child_guard text;
  v_draft_writer text;
  v_submit_writer text;
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

  select pg_get_functiondef('public.enforce_captain_next_fixture_team_sheet()'::regprocedure)
    into v_parent_guard;
  if position('is_active_team_captain' in lower(v_parent_guard)) = 0
     or position('captain_next_required_fixture' in lower(v_parent_guard)) = 0
     or position('scheduled' in lower(v_parent_guard)) = 0 then
    raise exception 'Parent team-sheet writes do not enforce active captain, scheduled fixture and next-required sequence';
  end if;

  select pg_get_functiondef('public.enforce_team_sheet_player_amendment()'::regprocedure)
    into v_child_guard;
  if position('is_active_team_captain' in lower(v_child_guard)) = 0
     or position('captain_next_required_fixture' in lower(v_child_guard)) = 0
     or position('v_locked' in lower(v_child_guard)) = 0
     or position('v_status <> ''completed''' in lower(v_child_guard)) = 0 then
    raise exception 'Team-sheet child writes do not preserve captain sequence and completed/locked admin amendment boundary';
  end if;

  if has_function_privilege('anon','public.enforce_captain_next_fixture_team_sheet()','EXECUTE')
     or has_function_privilege('authenticated','public.enforce_captain_next_fixture_team_sheet()','EXECUTE')
     or has_function_privilege('anon','public.enforce_team_sheet_player_amendment()','EXECUTE')
     or has_function_privilege('authenticated','public.enforce_team_sheet_player_amendment()','EXECUTE') then
    raise exception 'SECURITY DEFINER trigger functions must not be directly executable by client roles';
  end if;

  if has_table_privilege('authenticated','public.fixture_team_sheets','INSERT')
     or has_table_privilege('authenticated','public.fixture_team_sheets','UPDATE')
     or has_table_privilege('authenticated','public.fixture_team_sheets','DELETE')
     or has_table_privilege('authenticated','public.fixture_team_sheet_players','INSERT')
     or has_table_privilege('authenticated','public.fixture_team_sheet_players','UPDATE')
     or has_table_privilege('authenticated','public.fixture_team_sheet_players','DELETE') then
    raise exception 'Captains must not bypass the protected team-sheet RPCs with direct table writes';
  end if;

  select pg_get_functiondef('public.save_team_sheet_draft(uuid,uuid,uuid[],uuid[],uuid)'::regprocedure)
    into v_draft_writer;
  if position('v_sheet.is_locked' in lower(v_draft_writer)) = 0 then
    raise exception 'Draft saving must reject an already locked team sheet';
  end if;

  select pg_get_functiondef('public.submit_team_sheet(uuid,uuid,uuid[],uuid[],uuid)'::regprocedure)
    into v_submit_writer;
  if position('v_sheet.is_locked' in lower(v_submit_writer)) = 0 then
    raise exception 'Submission must reject an already locked team sheet';
  end if;

  select pg_get_functiondef('public.get_captain_fixtures()'::regprocedure)
    into v_projection;
  if position('next_fixture.status not in' in lower(v_projection)) = 0
     or position('next_fixture.fixture_number' in lower(v_projection)) = 0 then
    raise exception 'Captain fixture projection does not use ordered non-terminal fixtures';
  end if;

  select pg_get_functiondef('public.get_captain_team_sheet(uuid)'::regprocedure)
    into v_sheet_reader;
  if position('captain_next_required_fixture' in lower(v_sheet_reader)) = 0
     or position('f.status = ''scheduled''' in lower(v_sheet_reader)) = 0 then
    raise exception 'Captain sheet reader does not enforce the next required scheduled fixture';
  end if;

  select pg_get_functiondef(
    'public.admin_amend_team_sheet(uuid,uuid[],uuid[],uuid,text)'::regprocedure
  ) into v_admin_amendment;
  if position('v_fixture.status <> ''completed''' in lower(v_admin_amendment)) = 0
     or position('length(btrim(p_reason)) < 5' in lower(v_admin_amendment)) = 0
     or position('fixture.team_sheet.admin_amended' in lower(v_admin_amendment)) = 0
     or position('assert_admin_location_context' in lower(v_admin_amendment)) = 0 then
    raise exception 'Admin amendment is missing completed-fixture, reason, audit, or assigned-location safeguards';
  end if;

  if not has_function_privilege('authenticated','public.get_captain_fixtures()','EXECUTE')
     or has_function_privilege('anon','public.get_captain_fixtures()','EXECUTE')
     or not has_function_privilege('authenticated','public.get_captain_team_sheet(uuid)','EXECUTE')
     or has_function_privilege('anon','public.get_captain_team_sheet(uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.captain_next_required_fixture(uuid)','EXECUTE')
     or has_function_privilege('anon','public.captain_next_required_fixture(uuid)','EXECUTE') then
    raise exception 'Captain fixture RPC grants do not match the intended authenticated-only boundary';
  end if;

  raise notice 'Captain next-required fixture and post-match amendment regression assertions passed';
end;
$captain_fixture_workflow$;

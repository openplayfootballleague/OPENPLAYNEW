-- Run after 20261109001000_restrict_legacy_unscoped_admin_rpcs.sql.
-- Unfiltered legacy endpoints must be global-admin-only. Location admins use
-- the contextual variants, which enforce an explicit assigned location.
do $legacy_admin_scope$
declare
  v_dashboard text := lower(pg_catalog.pg_get_functiondef('public.get_admin_dashboard()'::regprocedure));
  v_players text := lower(pg_catalog.pg_get_functiondef('public.get_admin_player_register(text,text,integer,integer)'::regprocedure));
  v_transfers text := lower(pg_catalog.pg_get_functiondef('public.admin_get_transfer_requests(text)'::regprocedure));
  v_sheets text := lower(pg_catalog.pg_get_functiondef('public.get_admin_team_sheets()'::regprocedure));
  v_contextual text;
begin
  if pg_catalog.strpos(v_dashboard, 'role in (''admin'',''super_admin'')') = 0
     or pg_catalog.strpos(v_dashboard, 'has_platform_role()') > 0 then
    raise exception 'Unfiltered dashboard is not restricted to global administrators';
  end if;
  if pg_catalog.strpos(v_players, 'role in (''admin'',''super_admin'')') = 0
     or pg_catalog.strpos(v_players, 'has_platform_role()') > 0 then
    raise exception 'Unfiltered player register is not restricted to global administrators';
  end if;
  if pg_catalog.strpos(v_transfers, 'role in (''admin'',''super_admin'')') = 0
     or pg_catalog.strpos(v_transfers, 'has_platform_role()') > 0 then
    raise exception 'Unfiltered transfer queue is not restricted to global administrators';
  end if;
  if pg_catalog.strpos(v_sheets, 'role in (''admin'',''super_admin'')') = 0
     or pg_catalog.strpos(v_sheets, 'has_platform_role()') > 0 then
    raise exception 'Unfiltered team-sheet endpoint is not restricted to global administrators';
  end if;

  v_contextual := lower(pg_catalog.pg_get_functiondef('public.get_admin_dashboard_contextual(uuid,uuid,uuid)'::regprocedure));
  if pg_catalog.strpos(v_contextual, 'assert_admin_location_context(v_location)') = 0 then
    raise exception 'Contextual dashboard lost its assigned-location guard';
  end if;
  v_contextual := lower(pg_catalog.pg_get_functiondef('public.get_admin_player_register_contextual(text,text,integer,integer,uuid,uuid,uuid)'::regprocedure));
  if pg_catalog.strpos(v_contextual, 'assert_admin_location_context(v_location)') = 0 then
    raise exception 'Contextual player register lost its assigned-location guard';
  end if;
  v_contextual := lower(pg_catalog.pg_get_functiondef('public.admin_get_transfer_requests_contextual(text,uuid,uuid,uuid)'::regprocedure));
  if pg_catalog.strpos(v_contextual, 'assert_admin_location_context(v_location)') = 0 then
    raise exception 'Contextual transfer queue lost its assigned-location guard';
  end if;
  v_contextual := lower(pg_catalog.pg_get_functiondef('public.get_admin_team_sheets_contextual(uuid,uuid,uuid)'::regprocedure));
  if pg_catalog.strpos(v_contextual, 'assert_admin_location_context(v_location)') = 0 then
    raise exception 'Contextual team-sheet endpoint lost its assigned-location guard';
  end if;

  raise notice 'Legacy unscoped admin RPC scope assertions passed';
end;
$legacy_admin_scope$;

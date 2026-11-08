-- Run after applying 20261109000000_correct_membership_location_and_finance_authorization.sql.
-- Static authorization-shape checks. Full positive/negative role tests must also
-- run with authenticated identities in an isolated Supabase database.
select
  not (
    pg_catalog.strpos(
      pg_catalog.pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure),
      'if not public.can_administer_location((select l.location_id'
    ) > 0
  ) as captain_approval_has_no_premature_location_guard,
  (
    pg_catalog.strpos(
      pg_catalog.pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure),
      'public.is_active_team_captain(v_membership.season_team_id)'
    ) > 0
    and pg_catalog.strpos(
      pg_catalog.pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure),
      'ur.role=''league_admin'''
    ) > 0
    and pg_catalog.strpos(
      pg_catalog.pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure),
      'ur.role in (''admin'',''super_admin'')'
    ) > 0
  ) as membership_resolution_checks_captain_and_scoped_admin,
  (
    pg_catalog.strpos(
      pg_catalog.pg_get_functiondef('public.admin_set_location_active(uuid,boolean,text)'::regprocedure),
      'ur.role in (''admin'',''super_admin'')'
    ) > 0
    and pg_catalog.strpos(
      pg_catalog.pg_get_functiondef('public.admin_set_location_active(uuid,boolean,text)'::regprocedure),
      'has_platform_role()'
    ) = 0
  ) as location_activation_is_global_admin_only,
  (
    pg_catalog.strpos(
      pg_catalog.pg_get_functiondef('public.admin_set_player_fixture_fee(uuid,integer,integer,text)'::regprocedure),
      'can_administer_location'
    ) = 0
    and pg_catalog.strpos(
      pg_catalog.pg_get_functiondef('public.admin_set_player_fixture_fee(uuid,integer,integer,text)'::regprocedure),
      'has_finance_access()'
    ) > 0
  ) as player_fee_uses_global_finance_role_without_league_assignment_gate;

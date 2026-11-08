-- Run after applying the forward-only authorization correction migration.
-- These are executable catalog/source assertions: any missing invariant raises an
-- exception and makes the SQL test command fail. They do not replace authenticated
-- role-matrix tests in an isolated Supabase database.
do $authorization_regression$
declare
  v_membership text := lower(pg_catalog.pg_get_functiondef(
    'public.resolve_team_membership_request(uuid,text)'::regprocedure
  ));
  v_location text := lower(pg_catalog.pg_get_functiondef(
    'public.admin_set_location_active(uuid,boolean,text)'::regprocedure
  ));
  v_fee text := lower(pg_catalog.pg_get_functiondef(
    'public.admin_set_player_fixture_fee(uuid,integer,integer,text)'::regprocedure
  ));
begin
  -- Membership resolution: captains may act for their own team and assigned
  -- location administrators may act within their location. The dedicated
  -- forward migration retains the row lock, player/season eligibility checks,
  -- same-season duplicate prevention and audit write.
  if pg_catalog.strpos(v_membership,
       'if not public.is_active_team_captain(v_membership.season_team_id)') = 0
     or pg_catalog.strpos(v_membership, 'and not public.can_administer_location(v_location_id)') = 0
     or pg_catalog.strpos(v_membership, 'captain or assigned location administrator permission required') = 0
     or pg_catalog.strpos(v_membership, 'for update') = 0
     or pg_catalog.strpos(v_membership, 'pg_advisory_xact_lock') = 0
     or pg_catalog.strpos(v_membership, 'tm.status = ''active''') = 0
     or pg_catalog.strpos(v_membership, 'other_team.season_id = v_team.season_id') = 0
     or pg_catalog.strpos(v_membership, 'public.membership_status') = 0
     or pg_catalog.strpos(v_membership, 'insert into public.audit_log') = 0 then
    raise exception 'Membership captain/location authorization or a required workflow invariant is missing';
  end if;

  -- Location activation/deactivation is global-admin-only, while preserving
  -- the first-release Bideford and safe-deactivation controls.
  if pg_catalog.strpos(v_location, 'ur.role in (''admin'',''super_admin'')') = 0
     or pg_catalog.strpos(v_location, 'has_platform_role()') > 0
     or pg_catalog.strpos(v_location, 'can_administer_location') > 0
     or pg_catalog.strpos(v_location, 'pg_advisory_xact_lock') = 0
     or pg_catalog.strpos(v_location, 'bideford') = 0
     or pg_catalog.strpos(v_location, 'only one location may be active') = 0
     or pg_catalog.strpos(v_location, 'registration_open') = 0
     or pg_catalog.strpos(v_location, 'p_reason') = 0
     or pg_catalog.strpos(v_location, 'insert into public.audit_log') = 0 then
    raise exception 'Location activation authorization or a required safeguard is missing';
  end if;

  -- Finance administration is global by the agreed role model. A finance admin
  -- must not be blocked by a league-admin location assignment check.
  if pg_catalog.strpos(v_fee, 'public.has_finance_access()') = 0
     or pg_catalog.strpos(v_fee, 'can_administer_location') > 0
     or pg_catalog.strpos(v_fee, 'player fee must be between 1p') = 0
     or pg_catalog.strpos(v_fee, 'effective gameweek must be between 1 and 100') = 0
     or pg_catalog.strpos(v_fee, 'season not found') = 0
     or pg_catalog.strpos(v_fee, 'insert into public.audit_log') = 0 then
    raise exception 'Player-fee finance authorization or a required validation/audit invariant is missing';
  end if;

  raise notice 'Authorization scope regression assertions passed';
end;
$authorization_regression$;

-- Run after applying the forward-only authorization correction migration.
-- These are executable catalog/source assertions: any missing invariant raises an
-- exception and makes the SQL test command fail. They do not replace authenticated
-- role-matrix tests in an isolated Supabase database.
do $authorization_regression$
declare
  v_membership text := lower(pg_catalog.pg_get_functiondef(
    'public.resolve_team_membership_request(uuid,text)'::regprocedure
  ));
  v_membership_compact text;
  v_handover_lock integer;
  v_captain_lock integer;
  v_role_lock integer;
  v_assignment_lock integer;
  v_request_lock integer;
  v_location text := lower(pg_catalog.pg_get_functiondef(
    'public.admin_set_location_active(uuid,boolean,text)'::regprocedure
  ));
  v_fee text := lower(pg_catalog.pg_get_functiondef(
    'public.admin_set_player_fixture_fee(uuid,integer,integer,text)'::regprocedure
  ));
begin
  v_membership_compact := pg_catalog.regexp_replace(v_membership, E'\\s+', '', 'g');
  v_handover_lock := pg_catalog.strpos(v_membership_compact, 'captain-handover:');
  v_captain_lock := pg_catalog.strpos(v_membership_compact, 'andtm.is_captain=true');
  v_role_lock := pg_catalog.strpos(v_membership_compact, 'andur.role=''league_admin''');
  v_assignment_lock := pg_catalog.strpos(v_membership_compact, 'andla.location_id=v_location_id');
  v_request_lock := pg_catalog.strpos(v_membership_compact, 'whereid=p_membership_idandstatus=''pending''forupdate');

  -- Membership resolution: a captain must be active on this exact team, or an
  -- assigned league administrator must hold both the role and location rows.
  -- Approval remains one-team-per-season, serialized and audited.
  if v_handover_lock = 0
     or pg_catalog.strpos(v_membership_compact, 'pg_advisory_xact_lock') = 0
     or pg_catalog.strpos(v_membership_compact, 'andtm.user_id=v_actor') = 0
     or pg_catalog.strpos(v_membership_compact, 'andtm.status=''active''') = 0
     or v_captain_lock = 0
     or pg_catalog.strpos(v_membership_compact, 'andur.rolein(''admin'',''super_admin'')') = 0
     or v_role_lock = 0
     or v_assignment_lock = 0
     or pg_catalog.strpos(v_membership_compact, 'forshare') = 0
     or v_request_lock = 0
     or v_handover_lock > v_request_lock
     or v_captain_lock > v_request_lock
     or v_role_lock > v_request_lock
     or v_assignment_lock > v_request_lock
     or pg_catalog.strpos(v_membership_compact, 'p_decisionisnull') = 0
     or pg_catalog.strpos(v_membership_compact, 'v_player.is_banned') = 0
     or pg_catalog.strpos(v_membership_compact, 'other_team.season_id=v_team.season_id') = 0
     or pg_catalog.strpos(v_membership_compact, 'tm.season_team_id<>v_membership.season_team_id') = 0
     or pg_catalog.strpos(v_membership_compact, 'public.membership_status') = 0
     or pg_catalog.strpos(v_membership_compact, 'insertintopublic.audit_log') = 0 then
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

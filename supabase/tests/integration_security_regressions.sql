-- Additional security boundaries carried forward from the integration branch.

do $location_activation_role_boundary$
declare
  v_definition text := pg_catalog.regexp_replace(
    pg_catalog.lower(pg_catalog.pg_get_functiondef(
      'public.admin_set_location_active(uuid,boolean,text)'::regprocedure
    )),
    '[[:space:]]+', '', 'g'
  );
begin
  if v_definition not like '%public.user_rolesur%'
     or v_definition not like '%ur.rolein(''admin'',''super_admin'')%' then
    raise exception 'Location activation must explicitly require a global admin or super admin role';
  end if;
  if pg_catalog.has_function_privilege('anon',
      'public.admin_set_location_active(uuid,boolean,text)', 'EXECUTE') then
    raise exception 'Anonymous role must not execute location activation';
  end if;
end;
$location_activation_role_boundary$;

do $location_admin_rls_boundary$
declare
  v_policy text;
  v_expected text[] := array[
    'players_select_self_or_global_admin',
    'profiles_select_self_or_global_admin',
    'profiles_update_self_or_global_admin',
    'team_memberships_select_self_captain_or_scoped_admin',
    'fixture_team_sheets_select_team_or_scoped_admin',
    'fixture_team_sheet_players_select_team_or_scoped_admin',
    'fixture_availability_select_player_captain_or_scoped_admin',
    'fixture_availability_global_admin_manage',
    'notification_events_select_owner_or_global_admin',
    'audit_log_global_admin_read'
  ];
begin
  foreach v_policy in array v_expected loop
    if not exists (
      select 1 from pg_catalog.pg_policies
      where schemaname='public' and policyname=v_policy
    ) then
      raise exception 'Missing location-admin RLS boundary policy: %', v_policy;
    end if;
  end loop;

  if exists (
    select 1 from pg_catalog.pg_policies
    where schemaname='public'
      and policyname in (
        'players_select_self_or_global_admin',
        'profiles_select_self_or_global_admin',
        'profiles_update_self_or_global_admin',
        'team_memberships_select_self_captain_or_scoped_admin',
        'fixture_team_sheets_select_team_or_scoped_admin',
        'fixture_team_sheet_players_select_team_or_scoped_admin',
        'fixture_availability_select_player_captain_or_scoped_admin',
        'notification_events_select_owner_or_global_admin',
        'audit_log_global_admin_read'
      )
      and coalesce(qual,'') ilike '%has_platform_role()%'
  ) then
    raise exception 'Sensitive RLS policy still uses the platform-wide role helper';
  end if;

  if exists (
    select 1 from pg_catalog.pg_policies
    where schemaname='public' and tablename='fixture_availability'
      and policyname='fixture_availability_admin_manage'
  ) then
    raise exception 'Over-broad fixture_availability admin policy still exists';
  end if;
end;
$location_admin_rls_boundary$;

do $platform_role_rls_regression$
declare
  v_broad_policy text;
begin
  select policyname into v_broad_policy
  from pg_catalog.pg_policies
  where schemaname='public'
    and policyname = any(array[
      'fixture_results_admin_manage','fixture_team_sheet_players_admin_manage',
      'fixture_team_sheets_admin_manage','fixtures_admin_manage','leagues_admin_manage',
      'locations_admin_manage','season_registrations_admin_manage','season_teams_admin_manage',
      'seasons_admin_manage','team_memberships_admin_manage','teams_admin_manage',
      'transfer_requests_admin_manage'
    ])
    and (coalesce(qual,'') ilike '%has_platform_role()%' or coalesce(with_check,'') ilike '%has_platform_role()%')
  limit 1;
  if v_broad_policy is not null then
    raise exception 'Permissive admin policy still uses has_platform_role(): %',v_broad_policy;
  end if;

  if not exists(select 1 from pg_catalog.pg_policies where schemaname='public' and policyname='season_registrations_select_self_or_global_admin') then
    raise exception 'Season registration reads must be owner/global-admin only';
  end if;
  if exists(select 1 from pg_catalog.pg_policies where schemaname='public' and policyname='season_registrations_select_self_or_admin' and coalesce(qual,'') ilike '%has_platform_role()%') then
    raise exception 'Legacy season registration policy still exposes rows to all location admins';
  end if;
end;
$platform_role_rls_regression$;

do $user_roles_policy_recursion$
begin
  if not exists(
    select 1 from pg_catalog.pg_policies
    where schemaname='public' and tablename='user_roles'
      and policyname='user_roles_select_self_or_global_admin'
      and coalesce(qual,'') ilike '%has_global_admin_role()%'
  ) then
    raise exception 'user_roles RLS must use the non-recursive global-admin predicate';
  end if;
  if pg_catalog.has_function_privilege('anon','public.has_global_admin_role()','EXECUTE') then
    raise exception 'Anonymous role must not execute has_global_admin_role';
  end if;
end;
$user_roles_policy_recursion$;

do $legacy_admin_rpc_boundary$
declare
  v_signature text;
begin
  foreach v_signature in array array[
    'public.admin_get_transfer_requests(text)',
    'public.get_admin_dashboard()',
    'public.get_admin_player_register(text,text,integer,integer)',
    'public.get_admin_team_sheets()'
  ] loop
    if pg_catalog.has_function_privilege('anon',v_signature,'EXECUTE')
       or pg_catalog.has_function_privilege('authenticated',v_signature,'EXECUTE') then
      raise exception 'Legacy unscoped admin RPC remains executable by a client: %',v_signature;
    end if;
  end loop;
end;
$legacy_admin_rpc_boundary$;

do $fixture_venue_location_scope$
declare
  v_definition text := pg_catalog.pg_get_functiondef(
    'public.admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamp with time zone,uuid,text)'::regprocedure
  );
begin
  if v_definition not ilike '%id=p_venue_id and is_active=true and id=(select l.location_id from public.seasons s join public.leagues l on l.id=s.league_id where s.id=p_season_id)%' then
    raise exception 'Fixture venue must be constrained to the season location';
  end if;
end;
$fixture_venue_location_scope$;

do $captain_membership_approval_scope$
declare
  v_definition text := pg_catalog.regexp_replace(
    pg_catalog.lower(pg_catalog.pg_get_functiondef(
      'public.resolve_team_membership_request(uuid,text)'::regprocedure
    )),
    '[[:space:]]+', '', 'g'
  );
begin
  -- The serialized implementation now checks the captain's exact active
  -- membership and the administrator's role plus location assignment under
  -- row locks. The detailed lock-order/invariant matrix lives in
  -- authorization_scope_regression.sql; do not require the superseded helper
  -- calls that this implementation deliberately replaces.
  if pg_catalog.strpos(v_definition, 'captain-handover:') = 0
     or pg_catalog.strpos(v_definition, 'andtm.is_captain=true') = 0
     or pg_catalog.strpos(v_definition, 'andtm.user_id=v_actor') = 0
     or pg_catalog.strpos(v_definition, 'andtm.status=''active''') = 0
     or pg_catalog.strpos(v_definition, 'andur.rolein(''admin'',''super_admin'')') = 0
     or pg_catalog.strpos(v_definition, 'andur.role=''league_admin''') = 0
     or pg_catalog.strpos(v_definition, 'andla.location_id=v_location_id') = 0
     or pg_catalog.strpos(v_definition, 'forshare') = 0 then
    raise exception 'Membership approval must require an active team captain or an assigned location administrator under serialized authorization';
  end if;
end;
$captain_membership_approval_scope$;

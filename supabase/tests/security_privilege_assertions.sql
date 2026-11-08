-- Run against the development database after applying the security migrations.
-- Each row must return true; any false result is a failed security assertion.
select
  not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and not c.relrowsecurity
  ) as all_public_tables_have_rls,
  not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'
      and (
        has_table_privilege('anon',c.oid,'TRUNCATE')
        or has_table_privilege('authenticated',c.oid,'TRUNCATE')
        or has_table_privilege('anon',c.oid,'REFERENCES')
        or has_table_privilege('authenticated',c.oid,'REFERENCES')
        or has_table_privilege('anon',c.oid,'TRIGGER')
        or has_table_privilege('authenticated',c.oid,'TRIGGER')
      )
  ) as no_client_table_bypass_privileges,
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
      and has_function_privilege('anon',p.oid,'EXECUTE')
  ) as no_anon_security_definer_execution,
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
      and p.proname in (
        'claim_notification_events','complete_notification_event',
        'dispatch_notification_worker','enqueue_fixture_reminders',
        'enqueue_notification_event','fail_notification_event',
        'fail_notification_event_permanent','mark_notification_event_unconfirmed',
        'mark_stale_notification_events_unconfirmed','handle_new_auth_user',
        'notify_fixture_change','notify_fixture_result_change',
        'notify_player_ban_change','notify_team_membership_change',
        'notify_team_registration_change'
      )
      and has_function_privilege('authenticated',p.oid,'EXECUTE')
  ) as no_client_notification_worker_execution,
  exists (
    select 1 from pg_proc p
    where p.oid='public.create_player_fixture_payment(uuid,uuid)'::regprocedure
      and pg_get_functiondef(p.oid) ilike '%pg_advisory_xact_lock%'
  ) as player_fixture_payment_creation_is_serialized,
  (select pg_get_functiondef('public.create_player_fixture_payment(uuid,uuid)'::regprocedure) ilike '%is_active_team_captain(p_season_team_id)%') as fixture_payment_requires_active_captain,
  (select pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure) ilike '%pg_advisory_xact_lock%' and pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure) ilike '%v_player.is_banned%' and pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure) ilike '%tm.season_team_id<>v_membership.season_team_id%') as membership_approval_checks_eligibility_and_one_team_per_season,
  (select pg_get_functiondef('public.admin_add_player_to_team(uuid,uuid,boolean)'::regprocedure) ilike '%pg_advisory_xact_lock%' and pg_get_functiondef('public.admin_add_player_to_team(uuid,uuid,boolean)'::regprocedure) ilike '%v_player.is_banned%') as admin_team_assignment_is_serialized_and_checks_eligibility,
  (select pg_get_functiondef('public.admin_resolve_player_transfer_request(uuid,text,text)'::regprocedure) ilike '%pg_advisory_xact_lock%' and pg_get_functiondef('public.admin_resolve_player_transfer_request(uuid,text,text)'::regprocedure) ilike '%v_source.user_id<>v_request.user_id%' and pg_get_functiondef('public.admin_resolve_player_transfer_request(uuid,text,text)'::regprocedure) ilike '%tm.id<>v_source.id%') as transfer_approval_is_serialized_and_source_scoped,
  (select pg_get_functiondef('public.resolve_team_registration(uuid,text,text)'::regprocedure) ilike '%pg_advisory_xact_lock%' and pg_get_functiondef('public.resolve_team_registration(uuid,text,text)'::regprocedure) ilike '%v_player.is_banned%' and pg_get_functiondef('public.resolve_team_registration(uuid,text,text)'::regprocedure) ilike '%tm.season_team_id<>p_season_team_id%') as team_registration_captain_is_eligible_and_unique,
  (not has_function_privilege('anon','public.handover_team_captain(uuid,uuid)','EXECUTE') and has_function_privilege('authenticated','public.handover_team_captain(uuid,uuid)','EXECUTE') and (select pg_get_functiondef('public.handover_team_captain(uuid,uuid)'::regprocedure) ilike '%is_active_team_captain(p_season_team_id)%' and pg_get_functiondef('public.handover_team_captain(uuid,uuid)'::regprocedure) ilike '%team.captain.handed_over%')) as captain_handover_is_authenticated_captain_only_and_audited,
  ((select not public from storage.buckets where id='open-play-gallery')
    and (select relrowsecurity from pg_class where oid='public.gallery_items'::regclass)
    and not has_table_privilege('anon','public.gallery_items','SELECT')
    and not has_table_privilege('authenticated','public.gallery_items','SELECT')
    and not has_function_privilege('anon','public.get_admin_gallery_items(uuid)','EXECUTE')
    and not has_function_privilege('anon','public.admin_register_gallery_item(uuid,text,text)','EXECUTE')
    and not has_function_privilege('anon','public.admin_set_gallery_item_published(uuid,boolean)','EXECUTE')) as gallery_uploads_are_private_and_rpc_controlled,
  not exists(select 1 from pg_proc p where p.oid in (
    'public.get_admin_audit_history(text,integer,integer)'::regprocedure,
    'public.admin_get_notification_events(text,integer,integer)'::regprocedure,
    'public.admin_get_player_detail(uuid)'::regprocedure,
    'public.admin_set_player_ban(uuid,boolean,text)'::regprocedure,
    'public.admin_set_player_genuine(uuid,boolean,text)'::regprocedure,
    'public.admin_update_player_profile(uuid,text,text,text,text,text,text,text,text)'::regprocedure
  ) and (not (pg_get_functiondef(p.oid) ilike '%role in (''admin'',''super_admin'')%') or has_function_privilege('anon',p.oid,'EXECUTE'))) as global_admin_controls_are_restricted,
  (select c.relrowsecurity and not has_table_privilege('anon',c.oid,'SELECT') and not has_table_privilege('authenticated',c.oid,'SELECT') and not has_table_privilege('anon',c.oid,'INSERT') and not has_table_privilege('authenticated',c.oid,'INSERT') from pg_class c where c.oid='public.location_admin_assignments'::regclass) as location_admin_assignments_are_rpc_only,
  not exists(select 1 from pg_proc p where p.oid in (
    'public.get_admin_dashboard_contextual(uuid,uuid,uuid)'::regprocedure,
    'public.get_admin_player_register_contextual(text,text,integer,integer,uuid,uuid,uuid)'::regprocedure,
    'public.get_admin_team_sheets_contextual(uuid,uuid,uuid)'::regprocedure,
    'public.admin_get_transfer_requests_contextual(text,uuid,uuid,uuid)'::regprocedure,
    'public.get_admin_contextual_fixtures(uuid,uuid,uuid)'::regprocedure
  ) and (not (pg_get_functiondef(p.oid) ilike '%assert_admin_location_context(v_location)%') or has_function_privilege('anon',p.oid,'EXECUTE'))) as contextual_admin_reads_enforce_assigned_location,
  not exists(select 1 from pg_proc p where p.oid in (
    'public.admin_create_league(uuid,text,competition_format,text)'::regprocedure,
    'public.admin_create_season(uuid,text,integer,date,date,timestamp with time zone,timestamp with time zone)'::regprocedure,
    'public.admin_create_season_team(uuid,text,text,text)'::regprocedure,
    'public.admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamp with time zone,uuid,text)'::regprocedure,
    'public.admin_record_fixture_result_with_appearances(uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],text)'::regprocedure,
    'public.admin_set_fixture_status(uuid,fixture_status,text)'::regprocedure,
    'public.admin_transition_season(uuid,season_status)'::regprocedure,
    'public.resolve_team_membership_request(uuid,text)'::regprocedure,
    'public.resolve_team_registration(uuid,text,text)'::regprocedure
  ) and (not (pg_get_functiondef(p.oid) ilike '%can_administer_location%') or has_function_privilege('anon',p.oid,'EXECUTE'))) as location_admin_mutations_check_assigned_location,
  has_column_privilege('authenticated','public.profiles','first_name','UPDATE')
    and has_column_privilege('authenticated','public.profiles','last_name','UPDATE')
    and has_column_privilege('authenticated','public.profiles','display_name','UPDATE')
    and has_column_privilege('authenticated','public.profiles','phone','UPDATE')
    and has_column_privilege('authenticated','public.profiles','preferred_position','UPDATE')
    and has_column_privilege('authenticated','public.profiles','avatar_path','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','date_of_birth','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','emergency_contact_name','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','emergency_contact_phone','UPDATE')
    and not has_table_privilege('authenticated','public.profiles','UPDATE')
    as profile_self_service_columns_are_restricted,
  (exists(select 1 from pg_proc p where p.oid='public.get_my_team_request_statuses()'::regprocedure and p.prosecdef)
    and not has_function_privilege('anon','public.get_my_team_request_statuses()','EXECUTE')) as team_request_status_rpc_is_security_definer_and_denies_anon,
  has_function_privilege('authenticated','public.get_my_team_request_statuses()','EXECUTE') as team_request_status_rpc_allows_authenticated,
  (select pg_get_functiondef('public.get_my_team_request_statuses()'::regprocedure) ilike '%auth.uid() is not null%'
    and pg_get_functiondef('public.get_my_team_request_statuses()'::regprocedure) ilike '%tm.user_id = auth.uid()%'
    and pg_get_functiondef('public.get_my_team_request_statuses()'::regprocedure) ilike '%limit 100%') as team_request_status_rpc_is_self_scoped_and_bounded,
  (select count(*) = 0 from public.get_my_team_request_statuses()) as team_request_status_rpc_returns_no_rows_without_auth_claim;

-- Location activation/deactivation is a platform-wide control, not a
-- location-admin capability. A league_admin must never pass this RPC.
do $location_activation_role_boundary$
declare
  v_definition text := pg_catalog.pg_get_functiondef(
    'public.admin_set_location_active(uuid,boolean,text)'::regprocedure
  );
begin
  if v_definition not ilike '%role in (''admin'', ''super_admin'')%' then
    raise exception 'Location activation must explicitly require a global admin or super admin role';
  end if;
  if pg_catalog.has_function_privilege('anon',
      'public.admin_set_location_active(uuid,boolean,text)', 'EXECUTE') then
    raise exception 'Anonymous role must not execute location activation';
  end if;
end;
$location_activation_role_boundary$;

-- Location-scoped league administrators must not inherit platform-wide
-- direct-table access to personal data, team sheets or notification payloads.
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

-- Permissive ALL policies also apply to SELECT; assert they no longer
-- grant every league_admin platform-wide visibility.
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

-- The user_roles policy must use a SECURITY DEFINER predicate to avoid
-- recursive self-query evaluation.
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

-- Retired unscoped admin RPCs must not remain callable through PostgREST.
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

-- A fixture venue must belong to the same location as its season.
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

-- Captain membership approvals must remain scoped to the exact active team.
do $captain_membership_approval_scope$
declare
  v_definition text := pg_catalog.pg_get_functiondef(
    'public.resolve_team_membership_request(uuid,text)'::regprocedure
  );
begin
  if v_definition not ilike '%not public.is_active_team_captain((select tm.season_team_id from public.team_memberships tm where tm.id=p_membership_id))%' then
    raise exception 'Membership approval must allow the active captain of the requested membership team';
  end if;
  if v_definition not ilike '%not public.has_platform_role()%' then
    raise exception 'Membership approval must retain the platform-admin/captain role boundary';
  end if;
end;
$captain_membership_approval_scope$;

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
  (select pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure) ilike '%pg_advisory_xact_lock%' and pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure) ilike '%v_player.is_banned%' and (pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure) ilike '%can_administer_location%' or (pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure) ilike '%location_admin_assignments%' and pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure) ilike '%for share%')) and pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure) ilike '%other_team.season_id%' and pg_get_functiondef('public.resolve_team_membership_request(uuid,text)'::regprocedure) ilike '%tm.season_team_id%') as membership_approval_checks_eligibility_and_one_club_per_league,
  (select pg_get_functiondef('public.admin_add_player_to_team(uuid,uuid,boolean)'::regprocedure) ilike '%pg_advisory_xact_lock%' and pg_get_functiondef('public.admin_add_player_to_team(uuid,uuid,boolean)'::regprocedure) ilike '%v_player.is_banned%') as admin_team_assignment_is_serialized_and_checks_eligibility,
  (select pg_get_functiondef('public._resolve_player_transfer_request(uuid,text,text,uuid,boolean)'::regprocedure) ilike '%pg_advisory_xact_lock%' and pg_get_functiondef('public._resolve_player_transfer_request(uuid,text,text,uuid,boolean)'::regprocedure) ilike '%v_source.user_id is distinct from v_request.user_id%' and pg_get_functiondef('public._resolve_player_transfer_request(uuid,text,text,uuid,boolean)'::regprocedure) ilike '%v_source.season_team_id is distinct from v_request.source_season_team_id%' and regexp_replace(pg_get_functiondef('public._resolve_player_transfer_request(uuid,text,text,uuid,boolean)'::regprocedure), E'\\s+', '', 'g') ilike '%tm.id<>v_source.id%' and pg_get_functiondef('public._resolve_player_transfer_request(uuid,text,text,uuid,boolean)'::regprocedure) ilike '%is_active_team_captain%' and pg_get_functiondef('public.admin_resolve_player_transfer_request(uuid,text,text)'::regprocedure) ilike '%can_administer_location%') as transfer_approval_is_serialized_and_source_scoped,
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
  ) and (not (pg_get_functiondef(p.oid) ilike '%can_administer_location%' or pg_get_functiondef(p.oid) ilike '%assert_admin_location_context%' or (p.proname='resolve_team_membership_request' and pg_get_functiondef(p.oid) ilike '%location_admin_assignments%' and pg_get_functiondef(p.oid) ilike '%for share%' and pg_get_functiondef(p.oid) ilike '%and tm.is_captain = true%')) or has_function_privilege('anon',p.oid,'EXECUTE'))) as location_admin_mutations_check_assigned_location,
  not exists(select 1 from pg_proc p where p.oid in (
    'public.get_admin_season_statistics(uuid)'::regprocedure,
    'public.get_admin_fixture_scorer_options(uuid)'::regprocedure,
    'public.admin_amend_team_sheet(uuid,uuid[],uuid[],uuid,text)'::regprocedure
  ) and (
    not (pg_get_functiondef(p.oid) ilike '%assert_admin_location_context%'
      or pg_get_functiondef(p.oid) ilike '%can_administer_location%')
    or has_function_privilege('anon',p.oid,'EXECUTE')
  )) as admin_statistics_scorer_and_sheet_amendments_are_location_scoped,
  has_column_privilege('authenticated','public.profiles','avatar_path','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','first_name','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','last_name','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','display_name','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','phone','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','preferred_position','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','date_of_birth','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','emergency_contact_name','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','emergency_contact_phone','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','created_at','UPDATE')
    and not has_column_privilege('authenticated','public.profiles','updated_at','UPDATE')
    and not has_table_privilege('authenticated','public.profiles','UPDATE')
    as profile_self_service_columns_are_restricted,
  not exists (
    select 1 from pg_policies
    where schemaname='public'
      and (
        coalesce(qual,'') ilike '%has_platform_role%'
        or coalesce(with_check,'') ilike '%has_platform_role%'
      )
  ) as public_rls_policies_do_not_use_unscoped_platform_role,
  (
    to_regprocedure('public.has_global_admin_role()') is not null
    and has_function_privilege('authenticated','public.has_global_admin_role()','EXECUTE')
    and not has_function_privilege('anon','public.has_global_admin_role()','EXECUTE')
  ) as global_admin_rls_helper_is_authenticated_only,
  (
    not has_function_privilege('authenticated','public.get_admin_dashboard()','EXECUTE')
    and not has_function_privilege('authenticated','public.get_admin_player_register(text,text,integer,integer)','EXECUTE')
    and not has_function_privilege('authenticated','public.get_admin_team_sheets()','EXECUTE')
    and not has_function_privilege('authenticated','public.admin_get_transfer_requests(text)','EXECUTE')
  ) as legacy_unscoped_admin_rpcs_are_not_client_executable,
  (
    has_function_privilege('authenticated','public.admin_list_location_assignments(uuid)','EXECUTE')
    and not has_function_privilege('anon','public.admin_list_location_assignments(uuid)','EXECUTE')
    and pg_get_functiondef('public.admin_list_location_assignments(uuid)'::regprocedure) ilike '%ur.user_id = auth.uid()%'
    and pg_get_functiondef('public.admin_list_location_assignments(uuid)'::regprocedure) ilike '%ur.role in (''admin'',''super_admin'')%'
    and has_function_privilege('authenticated','public.admin_set_location_assignment(uuid,uuid,boolean)','EXECUTE')
    and not has_function_privilege('anon','public.admin_set_location_assignment(uuid,uuid,boolean)','EXECUTE')
    and pg_get_functiondef('public.admin_set_location_assignment(uuid,uuid,boolean)'::regprocedure) ilike '%user_id = auth.uid()%'
    and pg_get_functiondef('public.admin_set_location_assignment(uuid,uuid,boolean)'::regprocedure) ilike '%role in (''admin'', ''super_admin'')%'
  ) as location_assignment_rpcs_are_global_admin_only_and_unambiguous,
  (exists(select 1 from pg_proc p where p.oid='public.get_my_team_request_statuses()'::regprocedure and p.prosecdef)
    and not has_function_privilege('anon','public.get_my_team_request_statuses()','EXECUTE')) as team_request_status_rpc_is_security_definer_and_denies_anon,
  has_function_privilege('authenticated','public.get_my_team_request_statuses()','EXECUTE') as team_request_status_rpc_allows_authenticated,
  (select pg_get_functiondef('public.get_my_team_request_statuses()'::regprocedure) ilike '%auth.uid() is not null%'
    and pg_get_functiondef('public.get_my_team_request_statuses()'::regprocedure) ilike '%tm.user_id = auth.uid()%'
    and pg_get_functiondef('public.get_my_team_request_statuses()'::regprocedure) ilike '%limit 100%') as team_request_status_rpc_is_self_scoped_and_bounded,
  (select count(*) = 0 from public.get_my_team_request_statuses()) as team_request_status_rpc_returns_no_rows_without_auth_claim;

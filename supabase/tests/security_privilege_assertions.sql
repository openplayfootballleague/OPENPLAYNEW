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
    as profile_self_service_columns_are_restricted;

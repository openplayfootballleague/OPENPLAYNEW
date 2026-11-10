-- Referee access is separate from platform administration, and match reports
-- publish only through an authorised, idempotent admin approval RPC.
do $$
declare
  v_table text;
  v_function text;
  v_definition text;
  v_role_check text;
  v_rls boolean;
begin
  foreach v_table in array array[
    'referee_applications','referee_memberships','referee_availability',
    'fixture_referee_assignments','referee_match_reports',
    'referee_match_report_goals','referee_match_report_incidents',
    'referee_match_report_versions','referee_payment_entitlements','referee_milestone_rewards','platform_feature_flags'
  ] loop
    select c.relrowsecurity into v_rls
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname=v_table;
    if coalesce(v_rls,false) is not true then
      raise exception 'RLS must be enabled on public.%',v_table;
    end if;
    if has_table_privilege('anon','public.'||v_table,'select')
      or has_table_privilege('authenticated','public.'||v_table,'select')
      or has_table_privilege('authenticated','public.'||v_table,'insert')
      or has_table_privilege('authenticated','public.'||v_table,'update')
      or has_table_privilege('authenticated','public.'||v_table,'delete') then
      raise exception 'Direct client table privileges must be revoked on public.%',v_table;
    end if;
  end loop;

  select pg_get_constraintdef(oid) into v_role_check
  from pg_constraint where conrelid='public.user_roles'::regclass and conname='user_roles_role_check';
  if v_role_check is null or position('referee' in v_role_check)>0 then
    raise exception 'Referee must not be represented as a platform user_roles privilege';
  end if;

  select pg_get_functiondef('public.get_admin_fixture_scorer_options(uuid)'::regprocedure) into v_definition;
  if position('competition_player_id' in v_definition)=0 or position('squad_number_snapshot' in v_definition)=0 then
    raise exception 'Admin report completion scorer context must use permanent player identity and locked squad number';
  end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='fixture_referee_one_active_assignment_idx'
      and indexdef ilike '%unique%' and indexdef ilike '%where (removed_at is null)%'
  ) then raise exception 'One active referee assignment per fixture must be enforced'; end if;

  if not exists (
    select 1 from pg_constraint where conrelid='public.referee_match_reports'::regclass
      and contype='u' and conkey=array[(select attnum from pg_attribute where attrelid='public.referee_match_reports'::regclass and attname='fixture_id')]::smallint[]
  ) then raise exception 'Only one canonical report per fixture is allowed'; end if;

  foreach v_function in array array[
    'referee_submit_application(text,text,text,text,uuid[])',
    'referee_get_my_status()',
    'referee_get_active_locations()',
    'referee_get_match_report(uuid)',
    'referee_get_payment_entitlements()',
    'referee_get_career_summary()',
    'referee_get_milestone_rewards()',
    'admin_list_referee_milestone_rewards(text,uuid)',
    'admin_approve_referee_milestone_reward(uuid,text)',
    'admin_list_referee_applications(text)',
    'admin_list_active_referees(uuid)',
    'admin_list_referee_availability(uuid)',
    'get_admin_fixture_scorer_options(uuid)',
    'admin_get_referee_reporting_feature()',
    'admin_set_referee_reporting_feature(boolean,text)',
    'referee_save_availability(date,time,time,uuid,text)',
    'referee_get_assigned_fixtures()',
    'referee_save_match_report(uuid,timestamptz,integer,integer,text,jsonb,jsonb,boolean,boolean)',
    'admin_save_referee_match_report(uuid,timestamptz,integer,integer,text,jsonb,jsonb,boolean)',
    'admin_assign_referee(uuid,uuid,text)',
    'admin_review_referee_application(uuid,text,text)',
    'admin_review_referee_match_report(uuid,text,text)'
  ] loop
    if not has_function_privilege('authenticated','public.'||v_function,'execute') then
      raise exception 'Authenticated users require the RPC grant: %',v_function;
    end if;
    if has_function_privilege('anon','public.'||v_function,'execute') then
      raise exception 'Anonymous users must not execute RPC: %',v_function;
    end if;
    select pg_get_functiondef(v_function::regprocedure) into v_definition;
    if position('SECURITY DEFINER' in upper(v_definition))=0 then
      raise exception 'RPC must be SECURITY DEFINER with internal authorization: %',v_function;
    end if;
  end loop;

  select pg_get_functiondef('public.referee_save_match_report(uuid,timestamptz,integer,integer,text,jsonb,jsonb,boolean,boolean)'::regprocedure)
    into v_definition;
  if position('interval ''24 hours''' in v_definition)=0
    or position('removed_at is null' in v_definition)=0
    or position('latest active gameweek' in v_definition)=0 then
    raise exception 'Referee report RPC must enforce assignment ownership, active gameweek and 24-hour deadline';
  end if;
  if position('v_report.status not in (''draft'',''returned'',''rejected'')' in v_definition)=0 then
    raise exception 'Rejected reports must remain correctable and resubmittable by the assigned referee';
  end if;
  if position('v_fixture.status not in (''scheduled'',''in_progress'',''completed'')' in v_definition)=0 then
    raise exception 'Admin report completion must support completed fixtures as well as unplayed fixtures';
  end if;
  if position('fixture_team_sheet_players' in v_definition)=0
    or position('Goalscorer must be selected from the relevant submitted team sheet' in v_definition)=0
    or position('Only an administrator may enter an unattributed goal' in v_definition)=0
    or position('if v_is_referee and not exists' in v_definition)=0 then
    raise exception 'Goalscorers must be validated against the submitted team sheets';
  end if;
  if position('Disciplinary player must be on the relevant submitted team sheet' in v_definition)=0 then
    raise exception 'Player disciplinary incidents must be validated against submitted team sheets';
  end if;

  select pg_get_functiondef('public.admin_review_referee_match_report(uuid,text,text)'::regprocedure)
    into v_definition;
  if position('fixture_results' in v_definition)=0
    or position('fixture_goal_records' in v_definition)=0
    or position('finance_entries' in v_definition)=0
    or position('referee_payment_entitlements' in v_definition)=0 then
    raise exception 'Admin approval must publish result, reconcile goals/fines and create one referee entitlement';
  end if;
  if position('Published result score differs from referee report' in v_definition)=0
    or position('v_existing_result.confirmed_at is not null' in v_definition)=0 then
    raise exception 'Admin report approval must preserve matching published results and block score mismatches';
  end if;

  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='referee_match_report_goals' and column_name='is_unattributed') then
    raise exception 'Admin fallback must preserve explicitly unattributed goals without inventing scorers';
  end if;
  if (select enabled from public.platform_feature_flags where feature_key='referee_reporting') is distinct from false then
    raise exception 'Referee reporting must default to disabled until global administrator acceptance';
  end if;
  select pg_get_functiondef('public.admin_set_referee_reporting_feature(boolean,text)'::regprocedure) into v_definition;
  if position('has_global_admin_role' in v_definition)=0
    or position('length(btrim(p_reason))<5' in v_definition)=0 then
    raise exception 'Only global administrators may change the referee reporting feature flag with a reason';
  end if;
  select pg_get_functiondef('public.admin_assign_referee(uuid,uuid,text)'::regprocedure) into v_definition;
  if position('enqueue_notification_event' in v_definition)=0 then
    raise exception 'Referee assignment changes must queue notifications for affected officials';
  end if;
  select pg_get_functiondef('public.admin_remove_referee_assignment(uuid,text)'::regprocedure) into v_definition;
  if position('enqueue_notification_event' in v_definition)=0 then
    raise exception 'Referee assignment removal must queue a notification';
  end if;
  select pg_get_functiondef('public.admin_review_referee_application(uuid,text,text)'::regprocedure) into v_definition;
  if position('enqueue_notification_event' in v_definition)=0 then
    raise exception 'Referee application decisions must notify the applicant';
  end if;
  select pg_get_functiondef('public.admin_review_referee_match_report(uuid,text,text)'::regprocedure) into v_definition;
  if position('enqueue_notification_event' in v_definition)=0 then
    raise exception 'Referee report review decisions must notify the assigned official';
  end if;
  if position('reporting_enabled' in pg_get_function_result('public.referee_get_my_status()'::regprocedure))=0 then
    raise exception 'Referee status RPC must return the feature-enabled state';
  end if;
  select pg_get_functiondef('public.referee_submit_application(text,text,text,text,uuid[])'::regprocedure) into v_definition;
  if position('is_referee_reporting_enabled' in v_definition)=0 then
    raise exception 'Referee applications must respect the global feature flag';
  end if;
  select pg_get_functiondef('public.referee_get_assigned_fixtures()'::regprocedure) into v_definition;
  if position('is_referee_reporting_enabled' in v_definition)=0 then
    raise exception 'Referee fixture access must respect the global feature flag';
  end if;
  select pg_get_functiondef('public.referee_get_career_summary()'::regprocedure) into v_definition;
  if position('is_active_referee' in v_definition)=0
    or position('Open Play Ambassador' in v_definition)=0
    or position('Bronze Official' in v_definition)=0
    or position('lifetime_games' in v_definition)=0
    or position('active_season_games' in v_definition)=0 then
    raise exception 'Referee career summary must be membership-scoped and calculate permanent milestones';
  end if;
  if not exists(select 1 from pg_trigger where tgname='referee_report_milestone_reward_after_approval' and not tgisinternal) then
    raise exception 'Approved referee reports must automatically create eligible milestone reward records';
  end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='referee_milestone_rewards' and column_name='milestone_report_id')
    or not exists(select 1 from information_schema.columns where table_schema='public' and table_name='referee_milestone_rewards' and column_name='location_id') then
    raise exception 'Milestone reward must retain the qualifying report and location';
  end if;
  select pg_get_functiondef('public.record_referee_milestone_reward()'::regprocedure) into v_definition;
  if position('on conflict(referee_user_id,milestone_games) do nothing' in v_definition)=0
    or position('500' in v_definition)=0 then
    raise exception 'Referee milestone rewards must be idempotent at 50-game thresholds through 500';
  end if;
  select pg_get_functiondef('public.admin_list_referee_milestone_rewards(text,uuid)'::regprocedure) into v_definition;
  if position('can_administer_location' in v_definition)=0 then
    raise exception 'Milestone reward queue must be location-scoped';
  end if;
  select pg_get_functiondef('public.admin_approve_referee_milestone_reward(uuid,text)'::regprocedure) into v_definition;
  if position('enqueue_notification_event' in v_definition)=0 or position('length(btrim(p_reason))<5' in v_definition)=0 then
    raise exception 'Milestone reward approval must be audited and notify the referee';
  end if;
  select pg_get_functiondef('public.referee_save_match_report(uuid,timestamptz,integer,integer,text,jsonb,jsonb,boolean,boolean)'::regprocedure) into v_definition;
  if position('v_is_referee and not public.is_referee_reporting_enabled()' in v_definition)=0 then
    raise exception 'Referee report submission must respect the global feature flag';
  end if;

  if not exists (
    select 1 from pg_constraint where conrelid='public.referee_payment_entitlements'::regclass
      and conname='referee_payment_entitlements_report_id_key'
  ) then raise exception 'Referee payment entitlement must be unique per report'; end if;
end;
$$;

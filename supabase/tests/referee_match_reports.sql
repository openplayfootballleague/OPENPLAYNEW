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
    'referee_match_report_versions','referee_payment_entitlements'
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

  select pg_get_functiondef('public.referee_save_match_report(uuid,timestamptz,integer,integer,text,jsonb,jsonb,boolean)'::regprocedure)
    into v_definition;
  if position('interval ''24 hours''' in v_definition)=0
    or position('removed_at is null' in v_definition)=0
    or position('latest active gameweek' in v_definition)=0 then
    raise exception 'Referee report RPC must enforce assignment ownership, active gameweek and 24-hour deadline';
  end if;
  if position('fixture_team_sheet_players' in v_definition)=0
    or position('Goalscorer must be selected from the relevant submitted team sheet' in v_definition)=0 then
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
  if position('This fixture already has a published result' in v_definition)=0 then
    raise exception 'Duplicate published results must be blocked pending audited correction';
  end if;

  if not exists (
    select 1 from pg_constraint where conrelid='public.referee_payment_entitlements'::regclass
      and conname='referee_payment_entitlements_report_id_key'
  ) then raise exception 'Referee payment entitlement must be unique per report'; end if;
end;
$$;

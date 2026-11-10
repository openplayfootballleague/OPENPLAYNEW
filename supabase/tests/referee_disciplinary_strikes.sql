-- Straight-red strikes are permanent competition-identity records and only
-- an approved finance-linked incident increments them.
do $$
declare v_definition text; v_trigger text;
begin
  if not (select relrowsecurity from pg_class where oid='public.competition_player_discipline'::regclass) then
    raise exception 'Disciplinary records must have RLS enabled';
  end if;
  if has_table_privilege('anon','public.competition_player_discipline','select')
    or has_table_privilege('authenticated','public.competition_player_discipline','select')
    or has_table_privilege('authenticated','public.competition_player_discipline','insert')
    or has_table_privilege('authenticated','public.competition_player_discipline','update') then
    raise exception 'Disciplinary records must not be directly accessible to clients';
  end if;
  select pg_get_functiondef('public.record_approved_referee_straight_red()'::regprocedure) into v_definition;
  if position('old.finance_entry_id is null' in v_definition)=0
    or position('new.finance_entry_id is not null' in v_definition)=0
    or position('straight_red' in v_definition)=0
    or position('inactive_pending_review' in v_definition)=0 then
    raise exception 'A straight-red strike must be recorded only when the approved fine is posted';
  end if;
  select pg_get_functiondef('public.enforce_disciplinary_inactive_team_sheet_player()'::regprocedure) into v_definition;
  if position('inactive_pending_review' in v_definition)=0
    or position('fixture_team_sheets' in v_definition)=0 then
    raise exception 'Disciplinary inactivity must block future scheduled team-sheet selection';
  end if;
  select pg_get_functiondef('public.admin_review_player_disciplinary_return(uuid,text)'::regprocedure) into v_definition;
  if position('has_platform_role' in v_definition)=0
    or position('can_administer_location' in v_definition)=0
    or position('length(btrim(p_reason))<5' in v_definition)=0 then
    raise exception 'Disciplinary return approval must be authorised, location-scoped and reasoned';
  end if;
  if not has_function_privilege('authenticated','public.admin_review_player_disciplinary_return(uuid,text)','execute')
    or has_function_privilege('anon','public.admin_review_player_disciplinary_return(uuid,text)','execute') then
    raise exception 'Disciplinary return RPC grants are incorrect';
  end if;
  select pg_get_triggerdef(oid) into v_trigger from pg_trigger
  where tgrelid='public.referee_match_report_incidents'::regclass
    and tgname='referee_report_incident_record_straight_red' and not tgisinternal;
  if v_trigger is null or position('UPDATE OF FINANCE_ENTRY_ID' in upper(v_trigger))=0 then
    raise exception 'Straight-red trigger must run only when an approved fine ledger link is written';
  end if;
end;
$$;

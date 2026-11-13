-- Guard authorization-sensitive membership decisions against concurrent
-- captain handovers and league-admin role/location assignment revocation.
do $membership_approval_authorization_lock_regression$
declare
  v_definition text := lower(pg_catalog.pg_get_functiondef(
    'public.resolve_team_membership_request(uuid,text)'::regprocedure
  ));
  v_handover_lock integer;
  v_captain_share integer;
  v_role_share integer;
  v_assignment_share integer;
  v_request_lock integer;
begin
  v_handover_lock := pg_catalog.strpos(v_definition, 'captain-handover:');
  v_captain_share := pg_catalog.strpos(v_definition, 'and tm.is_captain = true');
  v_role_share := pg_catalog.strpos(v_definition, 'and ur.role = ''league_admin''');
  v_assignment_share := pg_catalog.strpos(v_definition, 'and la.location_id = v_location_id');
  v_request_lock := pg_catalog.strpos(v_definition, 'where id = p_membership_id' || chr(10) || '    and status = ''pending''' || chr(10) || '  for update');

  if v_handover_lock = 0 or v_captain_share = 0 then
    raise exception 'Captain approval must share the handover advisory lock and lock the active captain membership';
  end if;
  if pg_catalog.strpos(v_definition, 'for share') = 0
     or pg_catalog.strpos(v_definition, 'and ur.role in (''admin'',''super_admin'')') = 0
     or v_role_share = 0 or v_assignment_share = 0 then
    raise exception 'Administrator authorization must lock the role and assigned-location rows';
  end if;
  if v_request_lock = 0 or v_handover_lock > v_request_lock
     or v_captain_share > v_request_lock or v_role_share > v_request_lock
     or v_assignment_share > v_request_lock then
    raise exception 'Stable authorization must be acquired before locking and changing the pending request';
  end if;
  if pg_catalog.strpos(v_definition, 'p_decision is null') = 0 then
    raise exception 'Null membership decisions must be rejected explicitly';
  end if;
  raise notice 'Membership approval authorization-lock regression assertions passed';
end;
$membership_approval_authorization_lock_regression$;

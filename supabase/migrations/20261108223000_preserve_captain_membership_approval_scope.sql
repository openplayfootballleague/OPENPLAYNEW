-- Preserve active-captain membership approvals while retaining location-scoped
-- administrator access. The preceding location-scope migration injects a
-- can_administer_location guard into this RPC; extend that guard to include the
-- active captain of the exact requested team.
do $$
declare
  v_definition text;
  v_original text;
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'public.resolve_team_membership_request(uuid,text)'::regprocedure
  );
  v_original := v_definition;

  v_definition := regexp_replace(
    v_definition,
    'if[[:space:]]+not[[:space:]]+public\.can_administer_location\(([^;]+)\)[[:space:]]+then[[:space:]]+raise exception ''You are not assigned to this location'';[[:space:]]+end if;',
    'if not public.can_administer_location(\1) and not public.is_active_team_captain(v_membership.season_team_id) then raise exception ''You are not assigned to this location''; end if;',
    'g'
  );

  if v_definition = v_original then
    if position('not public.can_administer_location' in v_definition) > 0
       and position('not public.is_active_team_captain' in v_definition) > 0 then
      raise notice 'Captain membership approval scope is already correct';
      return;
    end if;
    raise exception 'Expected membership-request location guard was not found; refusing an unsafe rewrite';
  end if;

  execute v_definition;
end;
$$;

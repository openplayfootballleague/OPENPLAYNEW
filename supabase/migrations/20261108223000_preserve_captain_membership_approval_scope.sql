-- Preserve active-captain membership approvals while limiting administrator
-- decisions to the relevant assigned location. Support both the older integration
-- function body and the newer feature-branch global-admin/captain guard.
do $$
declare
  v_definition text;
  v_old_feature text := E'  if not public.has_platform_role()\n     and not public.is_active_team_captain(v_membership.season_team_id) then\n    raise exception ''Captain permission required'';\n  end if;';
  v_old_integration text := 'if not public.can_administer_location((select l.location_id from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.id=p_membership_id)) then raise exception ''You are not assigned to this location''; end if;';
  v_new text := 'if not public.can_administer_location((select l.location_id from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.id=p_membership_id)) and not public.is_active_team_captain(v_membership.season_team_id) then raise exception ''You are not assigned to this location''; end if;';
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'public.resolve_team_membership_request(uuid,text)'::regprocedure
  );

  if position(v_new in v_definition) = 0 then
    if position(v_old_feature in v_definition) > 0 then
      v_definition := replace(v_definition, v_old_feature, v_new);
    elsif position(v_old_integration in v_definition) > 0 then
      v_definition := replace(v_definition, v_old_integration, v_new);
    else
      raise exception 'Expected membership-request authorization guard was not found; refusing an unsafe rewrite';
    end if;
  end if;

  execute v_definition;
end;
$$;

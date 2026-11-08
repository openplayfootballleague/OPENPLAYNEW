-- Preserve the approved captain workflow while retaining location-scoped
-- administrator access to membership-request decisions.
do $$
declare
  v_definition text;
  v_old text := 'if not public.can_administer_location((select l.location_id from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.id=p_membership_id)) then raise exception ''You are not assigned to this location''; end if;';
  v_new text := 'if not public.can_administer_location((select l.location_id from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.id=p_membership_id)) and not public.is_active_team_captain((select tm.season_team_id from public.team_memberships tm where tm.id=p_membership_id)) then raise exception ''You are not assigned to this location''; end if;';
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'public.resolve_team_membership_request(uuid,text)'::regprocedure
  );
  if position(v_old in v_definition)=0 then
    if position(v_new in v_definition)>0 then
      raise notice 'Captain membership approval scope is already correct';
      return;
    end if;
    raise exception 'Expected membership-request location guard was not found; refusing an unsafe rewrite';
  end if;
  v_definition := replace(v_definition,v_old,v_new);
  execute v_definition;
end;
$$;

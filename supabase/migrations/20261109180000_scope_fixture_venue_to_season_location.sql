-- A location-scoped administrator may only attach a venue belonging to the
-- same location as the season being scheduled.
do $$
declare
  v_definition text;
  v_old text := 'if p_venue_id is not null and not exists(select 1 from public.locations where id=p_venue_id and is_active=true) then';
  v_new text := 'if p_venue_id is not null and not exists(select 1 from public.locations where id=p_venue_id and is_active=true and id=(select l.location_id from public.seasons s join public.leagues l on l.id=s.league_id where s.id=p_season_id)) then';
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'public.admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamp with time zone,uuid,text)'::regprocedure
  );
  if position(v_old in v_definition)=0 then
    if position(v_new in v_definition)>0 then
      raise notice 'Fixture venue already constrained to the season location';
      return;
    end if;
    raise exception 'Expected fixture venue validation was not found; refusing an unsafe rewrite';
  end if;
  v_definition := replace(v_definition,v_old,v_new);
  execute v_definition;
end;
$$;

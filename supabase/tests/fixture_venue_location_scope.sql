-- Regression test: fixture venue selection must remain within the season's location.
do $$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'public.admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamp with time zone,uuid,text)'::regprocedure
  ) into v_definition;

  if position(
    'v.id=p_venue_id and v.is_active=true and loc.is_active=true'
    in v_definition
  ) = 0 then
    raise exception 'admin_create_fixture must require an active venue at an active location';
  end if;

  if position(
    'v_venue.location_id<>v_location_id'
    in v_definition
  ) = 0 then
    raise exception 'admin_create_fixture must require the venue to belong to the season location';
  end if;

  if position(
    'where id=p_venue_id and is_active=true) then'
    in v_definition
  ) > 0 then
    raise exception 'admin_create_fixture still permits an active venue from another location';
  end if;
end;
$$;

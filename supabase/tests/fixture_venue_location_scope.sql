-- Regression test: fixture venue selection must remain within the season's location.
do $$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'public.admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamp with time zone,uuid,text)'::regprocedure
  ) into v_definition;

  if v_definition !~* 'v\.id\s*=\s*p_venue_id'
     or v_definition !~* 'v\.is_active\s*=\s*true'
     or v_definition !~* 'loc\.is_active\s*=\s*true' then
    raise exception 'admin_create_fixture must require an active venue at an active location';
  end if;

  if v_definition !~* 'v_venue\.location_id\s*<>\s*v_location_id' then
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

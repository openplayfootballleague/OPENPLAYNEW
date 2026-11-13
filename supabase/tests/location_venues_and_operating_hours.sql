-- Location-scoped multi-venue and operating-hours regression tests.
-- Requires the location_admin_role_scope.sql fixtures to have run first.
do $location_venues$
declare
  v_admin constant uuid := '00000000-0000-4000-8000-000000000004';
  v_location_a constant uuid := '00000000-0000-4000-8000-000000000010';
  v_location_b constant uuid := '00000000-0000-4000-8000-000000000011';
  v_season_a constant uuid := '00000000-0000-4000-8000-000000000030';
  v_team_a constant uuid := '00000000-0000-4000-8000-000000000050';
  v_team_b constant uuid := '00000000-0000-4000-8000-000000000051';
  v_venue public.venues;
  v_fixture public.fixtures;
  v_setup jsonb;
  v_venue_name text;
  v_denied boolean;
begin
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_admin,'role','authenticated')::text,true);

  select * into v_venue
  from public.admin_create_venue(
    v_location_a,'CI Friday Astro','North Devon test address',
    array[5]::smallint[],'20:00'::time,'22:00'::time,true
  );
  if v_venue.location_id<>v_location_a
     or v_venue.operating_days<>array[5]::smallint[]
     or v_venue.opens_at<>'20:00'::time
     or v_venue.closes_at<>'22:00'::time
     or not v_venue.is_active then
    raise exception 'Venue creation did not persist its location, operating day, hours and active state';
  end if;

  -- Duplicate day values are normalised, not stored twice.
  select * into v_venue
  from public.admin_update_venue(
    v_venue.id,'CI Friday Astro','North Devon test address',
    array[5,5]::smallint[],'20:00'::time,'22:00'::time,true
  );
  if v_venue.operating_days<>array[5]::smallint[] then
    raise exception 'Operating-day values were not de-duplicated';
  end if;

  v_denied:=false;
  begin
    perform * from public.admin_create_venue(v_location_b,'Out of scope venue',null,'{}'::smallint[],null,null,false);
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Location administrator created a venue outside their assigned location'; end if;

  v_denied:=false;
  begin
    perform * from public.admin_update_venue(v_location_b,'Out of scope venue',null,'{}'::smallint[],null,null,false);
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Location administrator updated a venue outside their assigned location'; end if;

  v_denied:=false;
  begin
    perform * from public.admin_create_venue(v_location_a,'Invalid operating day',null,array[7]::smallint[],null,null,false);
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Invalid operating-day value was accepted'; end if;

  v_denied:=false;
  begin
    perform * from public.admin_create_venue(v_location_a,'Invalid opening hours',null,array[5]::smallint[],'22:00'::time,'20:00'::time,false);
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Closing time earlier than opening time was accepted'; end if;

  v_denied:=false;
  begin
    perform * from public.admin_create_fixture(
      v_season_a,99,100,v_team_a,v_team_b,'2026-11-21T20:30:00+00:00'::timestamptz,v_venue.id,'Saturday should be rejected'
    );
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Fixture was scheduled on a day when the venue is closed'; end if;

  v_denied:=false;
  begin
    perform * from public.admin_create_fixture(
      v_season_a,99,101,v_team_a,v_team_b,'2026-11-20T22:00:00+00:00'::timestamptz,v_venue.id,'After closing should be rejected'
    );
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Fixture was scheduled outside venue operating hours'; end if;

  v_denied:=false;
  begin
    perform * from public.admin_create_fixture(
      v_season_a,99,102,v_team_a,v_team_b,'2026-11-20T20:30:00+00:00'::timestamptz,v_location_b,'Cross-location venue should be rejected'
    );
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Fixture accepted a venue from another location'; end if;

  select * into v_fixture
  from public.admin_create_fixture(
    v_season_a,99,99,v_team_a,v_team_b,'2026-11-20T20:30:00+00:00'::timestamptz,v_venue.id,'Friday venue test'
  );
  if v_fixture.venue_id is distinct from v_venue.id then
    raise exception 'Fixture did not retain the selected venue';
  end if;

  select venue_name into v_venue_name
  from public.get_admin_contextual_fixtures(v_location_a,null,null)
  where id=v_fixture.id;
  if v_venue_name is distinct from v_venue.name then
    raise exception 'Contextual fixture report did not resolve the selected venue name';
  end if;

  v_setup:=public.get_admin_competition_setup();
  if not exists(
    select 1 from jsonb_array_elements(v_setup->'venues') venue
    where venue->>'id'=v_venue.id::text
      and venue->>'location_id'=v_location_a::text
      and venue->>'name'=v_venue.name
  ) then
    raise exception 'Administrator setup did not include the venue and its operating details';
  end if;
  if exists(
    select 1 from jsonb_array_elements(v_setup->'venues') venue
    where venue->>'location_id'=v_location_b::text
  ) then
    raise exception 'Location administrator received venues from an unassigned location';
  end if;

  if not (select relrowsecurity from pg_catalog.pg_class where oid='public.venues'::regclass) then
    raise exception 'Venue table must have row-level security enabled';
  end if;
  if pg_catalog.has_table_privilege('anon','public.venues','insert')
     or pg_catalog.has_table_privilege('authenticated','public.venues','insert')
     or pg_catalog.has_table_privilege('authenticated','public.venues','update') then
    raise exception 'Venue writes must be performed only through permission-checked RPCs';
  end if;
  if pg_catalog.has_function_privilege('anon','public.admin_create_venue(uuid,text,text,smallint[],time without time zone,time without time zone,boolean)','EXECUTE')
     or not pg_catalog.has_function_privilege('authenticated','public.admin_create_venue(uuid,text,text,smallint[],time without time zone,time without time zone,boolean)','EXECUTE') then
    raise exception 'Venue creation RPC grants are incorrect';
  end if;

  raise notice 'Multi-venue management, location isolation, operating-day/time validation and fixture venue selection passed';
end;
$location_venues$;

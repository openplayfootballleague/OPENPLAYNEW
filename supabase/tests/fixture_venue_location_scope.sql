-- Regression test: a fixture's venue must belong to the season's location.
-- Behavioural (calls the RPC) rather than matching function source text, so it
-- survives implementation changes such as the move from location-as-venue to
-- dedicated public.venues rows. Uses the location/season/team fixtures created
-- by location_admin_role_scope.sql (run earlier in CI).
do $fixture_venue_location_scope$
declare
  v_super uuid := gen_random_uuid();
  v_location_a constant uuid := '00000000-0000-4000-8000-000000000010';
  v_location_b constant uuid := '00000000-0000-4000-8000-000000000011';
  v_season_a constant uuid := '00000000-0000-4000-8000-000000000030';
  v_team_a constant uuid := '00000000-0000-4000-8000-000000000050';
  v_team_b constant uuid := '00000000-0000-4000-8000-000000000051';
  v_foreign_venue public.venues;
  v_local_venue public.venues;
  v_message text;
  v_release_check text;
  v_release_index text;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values(v_super,'authenticated','authenticated','ci-venue-scope-'||substr(v_super::text,1,8)||'@openplay.invalid','','{}'::jsonb,now(),now());
  insert into public.user_roles(user_id,role,granted_by) values(v_super,'super_admin',v_super);
  -- Location B is inactive under the Bideford-only first-release policy. Activate it for
  -- this transaction only so the location-scope check, not the active check, is exercised.
  -- Only Bideford may be active (locations_first_release_active_bideford_check), so a foreign
  -- venue is also stopped by the active-location check today. Lift the constraint inside this
  -- transaction so the season-location check itself is exercised; it is restored verbatim below.
  select pg_get_constraintdef(oid) into v_release_check from pg_constraint
  where conname='locations_first_release_active_bideford_check' and conrelid='public.locations'::regclass;
  if v_release_check is not null then
    alter table public.locations drop constraint locations_first_release_active_bideford_check;
  end if;
  select pg_get_indexdef(i.indexrelid) into v_release_index from pg_index i
  join pg_class c on c.oid=i.indexrelid where c.relname='locations_single_active_first_release_idx';
  if v_release_index is not null then
    drop index public.locations_single_active_first_release_idx;
  end if;
  update public.locations set is_active=true where id=v_location_b;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_super::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_super,'role','authenticated')::text,true);

  -- Venues with no operating-day restriction, so only location scope is tested.
  select * into v_foreign_venue from public.admin_create_venue(
    v_location_b,'CI scope venue B '||substr(v_super::text,1,8),null,'{}'::smallint[],null,null,true);
  select * into v_local_venue from public.admin_create_venue(
    v_location_a,'CI scope venue A '||substr(v_super::text,1,8),null,'{}'::smallint[],null,null,true);

  begin
    perform public.admin_create_fixture(v_season_a,98,1,v_team_a,v_team_b,'2026-11-27T20:00:00+00:00'::timestamptz,v_foreign_venue.id,'cross-location venue');
    raise exception 'ASSERTION: admin_create_fixture accepted a venue from another location';
  exception when others then
    v_message := sqlerrm;
  end;
  if v_message like 'ASSERTION:%' or v_message not ilike '%venue must belong to the season location%' then
    raise exception 'admin_create_fixture must require an active venue belonging to the season location (got: %)', v_message;
  end if;

  -- The same call with a venue at the season's own location succeeds.
  perform public.admin_create_fixture(v_season_a,98,1,v_team_a,v_team_b,'2026-11-27T20:00:00+00:00'::timestamptz,v_local_venue.id,'same-location venue');
  if not exists (select 1 from public.fixtures where season_id=v_season_a and gameweek=98 and venue_id=v_local_venue.id) then
    raise exception 'admin_create_fixture rejected a valid venue at the season location';
  end if;

  execute 'reset role';
  delete from public.fixtures where season_id=v_season_a and gameweek=98;
  update public.venues set is_active=false where id in (v_foreign_venue.id,v_local_venue.id);
  update public.locations set is_active=false where id=v_location_b;
  if v_release_index is not null then
    execute v_release_index;
  end if;
  if v_release_check is not null then
    execute 'alter table public.locations add constraint locations_first_release_active_bideford_check '||v_release_check;
  end if;
end;
$fixture_venue_location_scope$;

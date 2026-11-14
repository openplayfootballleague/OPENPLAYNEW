-- Regression: get_admin_contextual_fixtures must return rows (including scores)
-- instead of failing on smallint/integer result-type mismatch.
do $admin_contextual_fixture_scores$
declare
  v_super uuid := gen_random_uuid();
  v_season constant uuid := '00000000-0000-4000-8000-000000000030';
  v_team_a constant uuid := '00000000-0000-4000-8000-000000000050';
  v_team_b constant uuid := '00000000-0000-4000-8000-000000000051';
  v_fixture uuid := gen_random_uuid();
  v_row record;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values(v_super,'authenticated','authenticated','ci-ctx-fixtures-'||substr(v_super::text,1,8)||'@openplay.invalid','','{}'::jsonb,now(),now());
  insert into public.user_roles(user_id,role,granted_by) values(v_super,'super_admin',v_super);
  insert into public.fixtures(id,season_id,gameweek,fixture_number,home_team_id,away_team_id,status)
  values(v_fixture,v_season,97,1,v_team_a,v_team_b,'completed');
  insert into public.fixture_results(fixture_id,home_score,away_score) values(v_fixture,3,2);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_super::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_super,'role','authenticated')::text,true);

  select * into v_row from public.get_admin_contextual_fixtures(null,null,v_season) f where f.id=v_fixture;
  if v_row.id is null or v_row.home_score<>3 or v_row.away_score<>2 then
    raise exception 'get_admin_contextual_fixtures did not return the scored fixture';
  end if;

  execute 'reset role';
  delete from public.fixture_results where fixture_id=v_fixture;
  delete from public.fixtures where id=v_fixture;
end;
$admin_contextual_fixture_scores$;

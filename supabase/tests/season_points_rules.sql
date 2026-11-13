-- Configurable season points (competition spec) feeding the league table and the
-- title-final rule (owner decision D7). Uses the active location/league fixtures from
-- location_admin_role_scope.sql. Ids are generated, so the test can rerun.
do $season_points$
declare
  v_super uuid := gen_random_uuid();
  v_player uuid := gen_random_uuid();
  v_league constant uuid := '00000000-0000-4000-8000-000000000020';
  v_season uuid := gen_random_uuid();
  v_a uuid := gen_random_uuid(); v_b uuid := gen_random_uuid(); v_c uuid := gen_random_uuid(); v_d uuid := gen_random_uuid();
  v_row public.seasons;
  v_stats jsonb;
  v_message text;
  v_team uuid; i integer := 0;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at) values
    (v_super,'authenticated','authenticated','ci-points-admin-'||substr(v_super::text,1,8)||'@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_player,'authenticated','authenticated','ci-points-player-'||substr(v_player::text,1,8)||'@openplay.invalid','','{}'::jsonb,now(),now());
  insert into public.user_roles(user_id,role,granted_by) values(v_super,'super_admin',v_super);
  insert into public.seasons(id,league_id,name,season_number,is_public,status)
  values(v_season,v_league,'CI Points Season '||substr(v_season::text,1,8),997,false,'active');
  foreach v_team in array array[v_a,v_b,v_c,v_d] loop
    i := i + 1;
    insert into public.teams(id,created_by) values(v_team,v_super);
    insert into public.season_teams(id,team_id,season_id,name,slug,registration_status)
    values(v_team,v_team,v_season,'CI Points '||chr(64+i),'ci-points-'||i||'-'||substr(v_team::text,1,8),'approved');
  end loop;

  select * into v_row from public.seasons where id=v_season;
  if (v_row.points_for_win,v_row.points_for_draw,v_row.points_for_loss) is distinct from (3::smallint,1::smallint,0::smallint) then
    raise exception 'New seasons must default to 3/1/0 points';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player,'role','authenticated')::text,true);
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  v_message := null;
  begin perform public.admin_set_season_points(v_season,2,1,0,'player attempt'); exception when others then v_message := sqlerrm; end;
  if v_message is null then raise exception 'A non-administrator changed season points'; end if;

  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_super,'role','authenticated')::text,true);
  perform set_config('request.jwt.claim.sub',v_super::text,true);
  v_message := null;
  begin perform public.admin_set_season_points(v_season,1,2,0,'invalid ordering'); exception when others then v_message := sqlerrm; end;
  if v_message is null or v_message not ilike '%win >= draw >= loss%' then raise exception 'Invalid points ordering accepted: %', v_message; end if;

  v_row := public.admin_set_season_points(v_season,2,1,0,'Two points for a win this season');
  if v_row.points_for_win <> 2 then raise exception 'Points update not persisted'; end if;
  execute 'reset role';
  if not exists (select 1 from public.audit_log where action='season.points_rules_updated' and entity_id=v_season::text) then
    raise exception 'Points change must be audited';
  end if;

  -- A beats D (2 pts); B draws C and D (2 pts): level only under 2/1/0.
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,status) values
    (v_season,1,1,v_a,v_d,'completed'),(v_season,1,2,v_b,v_c,'completed'),(v_season,2,1,v_b,v_d,'completed');
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at)
  select f.id, case when f.home_team_id=v_a then 1 else 0 end, 0, now() from public.fixtures f where f.season_id=v_season;

  if public.season_joint_leaders(v_season) <> (select array_agg(x order by x) from unnest(array[v_a,v_b]) x) then
    raise exception 'Title-final leaders must use the season points rules';
  end if;

  execute 'set local role authenticated';
  v_stats := public.get_admin_season_statistics(v_season);
  if (select (t->>'points')::integer from jsonb_array_elements(v_stats->'teams') t where (t->>'team_id')::uuid=v_a) <> 2
     or (select (t->>'points')::integer from jsonb_array_elements(v_stats->'teams') t where (t->>'team_id')::uuid=v_b) <> 2 then
    raise exception 'League table must use the season points rules: %', v_stats->'teams';
  end if;

  v_message := null;
  begin perform public.admin_set_season_points(v_season,3,1,0,'change after results'); exception when others then v_message := sqlerrm; end;
  if v_message is null or v_message not ilike '%locked once a result%' then raise exception 'Points changed after a published result: %', v_message; end if;
  execute 'reset role';
end;
$season_points$;

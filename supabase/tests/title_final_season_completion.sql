-- Owner decision D7: teams level on points in first place play a final; the season
-- cannot be completed until a decisive final result exists. The final does not add
-- league points. Uses the active location/league created by location_admin_role_scope.sql.
do $title_final$
declare
  v_super uuid := gen_random_uuid();
  v_league constant uuid := '00000000-0000-4000-8000-000000000020';
  v_season uuid := gen_random_uuid();
  v_a uuid := gen_random_uuid();
  v_b uuid := gen_random_uuid();
  v_c uuid := gen_random_uuid();
  v_f1 uuid := gen_random_uuid();
  v_f2 uuid := gen_random_uuid();
  v_f3 uuid := gen_random_uuid();
  v_final public.fixtures;
  v_stats jsonb;
  v_message text;
  v_team uuid;
  i integer := 0;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values(v_super,'authenticated','authenticated','ci-title-final-'||substr(v_super::text,1,8)||'@openplay.invalid','','{}'::jsonb,now(),now());
  insert into public.user_roles(user_id,role,granted_by) values(v_super,'super_admin',v_super);

  insert into public.seasons(id,league_id,name,season_number,is_public,status,starts_on,ends_on)
  values(v_season,v_league,'CI Title Final Season '||substr(v_season::text,1,8),998,false,'active',date '2026-09-01',date '2027-06-30');
  foreach v_team in array array[v_a,v_b,v_c] loop
    i := i + 1;
    insert into public.teams(id,created_by) values(v_team,v_super);
    insert into public.season_teams(id,team_id,season_id,name,slug,registration_status)
    values(v_team,v_team,v_season,'CI Final Team '||chr(64+i),'ci-final-'||i||'-'||substr(v_team::text,1,8),'approved');
  end loop;

  -- A 1-0 C, B 2-0 C, A 1-1 B  =>  A 4 pts, B 4 pts, C 0 pts (A has the better goal difference).
  insert into public.fixtures(id,season_id,gameweek,fixture_number,home_team_id,away_team_id,status) values
    (v_f1,v_season,1,1,v_a,v_c,'completed'),(v_f2,v_season,2,1,v_b,v_c,'completed'),(v_f3,v_season,3,1,v_a,v_b,'completed');
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at) values
    (v_f1,1,0,now()),(v_f2,2,0,now()),(v_f3,1,1,now());

  if public.season_joint_leaders(v_season) <> (select array_agg(x order by x) from unnest(array[v_a,v_b]) x) then
    raise exception 'Joint leaders must be the two teams level on points, ignoring goal difference';
  end if;

  -- Completion is blocked while first place is shared and no final is decided.
  begin
    update public.seasons set status='completed' where id=v_season;
    raise exception 'ASSERTION: season completed with a shared first place';
  exception when others then v_message := sqlerrm; end;
  if v_message not ilike '%level on points in first place%' then
    raise exception 'Expected the title-final completion guard, got: %', v_message;
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_super::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_super,'role','authenticated')::text,true);

  -- Clients cannot call the internal standings helpers.
  begin
    perform public.season_league_points(v_season);
    raise exception 'ASSERTION: season_league_points is client-callable';
  exception when others then v_message := sqlerrm; end;
  if v_message like 'ASSERTION:%' then raise exception '%', v_message; end if;

  -- The final must be between the two joint leaders.
  begin
    perform public.admin_create_title_final(v_season,v_a,v_c,now()+interval '7 days',null,'Title decider');
    raise exception 'ASSERTION: final accepted a team outside first place';
  exception when others then v_message := sqlerrm; end;
  if v_message not ilike '%two teams level on points in first place%' then
    raise exception 'Expected final team validation, got: %', v_message;
  end if;

  v_final := public.admin_create_title_final(v_season,v_a,v_b,now()+interval '7 days',null,'Title decider');
  if not v_final.is_title_final or v_final.gameweek <> 4 or v_final.status <> 'scheduled' then
    raise exception 'Title final not created as gameweek 4 scheduled final: %', row_to_json(v_final);
  end if;

  begin
    perform public.admin_create_title_final(v_season,v_b,v_a,now()+interval '8 days',null,'Duplicate decider');
    raise exception 'ASSERTION: a second active title final was accepted';
  exception when others then v_message := sqlerrm; end;
  if v_message like 'ASSERTION:%' then raise exception '%', v_message; end if;

  execute 'reset role';
  if not exists (select 1 from public.audit_log where action='season.title_final_created' and entity_id=v_final.id::text) then
    raise exception 'Title final creation must be audited';
  end if;

  -- A drawn final does not decide the title.
  update public.fixtures set status='completed' where id=v_final.id;
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at) values(v_final.id,2,2,now());
  begin
    update public.seasons set status='completed' where id=v_season;
    raise exception 'ASSERTION: season completed after a drawn final';
  exception when others then v_message := sqlerrm; end;
  if v_message not ilike '%level on points in first place%' then
    raise exception 'Expected the guard after a drawn final, got: %', v_message;
  end if;

  -- A decisive final allows completion, and the final does not change league points.
  update public.fixture_results set home_score=3, away_score=2 where fixture_id=v_final.id;
  update public.seasons set status='completed' where id=v_season;

  execute 'set local role authenticated';
  v_stats := public.get_admin_season_statistics(v_season);
  execute 'reset role';
  if (select (t->>'points')::integer from jsonb_array_elements(v_stats->'teams') t where (t->>'team_id')::uuid=v_a) <> 4
     or (select (t->>'points')::integer from jsonb_array_elements(v_stats->'teams') t where (t->>'team_id')::uuid=v_b) <> 4 then
    raise exception 'The title final must not add league points: %', v_stats->'teams';
  end if;
end;
$title_final$;

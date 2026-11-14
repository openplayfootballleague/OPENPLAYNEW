-- Assists, own goals and goal contributions (Blueprint 7.5, 11.2, 12.2).
-- Runs against the disposable CI database; ids use the 9b000000- prefix.
do $goal_events$
declare
  v_admin constant uuid:='9b000000-0000-4000-8000-000000000001';
  v_home_captain constant uuid:='9b000000-0000-4000-8000-000000000002';
  v_home_player constant uuid:='9b000000-0000-4000-8000-000000000003';
  v_away_captain constant uuid:='9b000000-0000-4000-8000-000000000005';
  v_away_player constant uuid:='9b000000-0000-4000-8000-000000000006';
  v_location uuid;
  v_league constant uuid:='9b000000-0000-4000-8000-000000000020';
  v_season constant uuid:='9b000000-0000-4000-8000-000000000030';
  v_home_team constant uuid:='9b000000-0000-4000-8000-000000000040';
  v_away_team constant uuid:='9b000000-0000-4000-8000-000000000041';
  v_home_st constant uuid:='9b000000-0000-4000-8000-000000000050';
  v_away_st constant uuid:='9b000000-0000-4000-8000-000000000051';
  v_fixture constant uuid:='9b000000-0000-4000-8000-000000000060';
  v_home_sheet uuid;
  v_away_sheet uuid;
  hc uuid; hp uuid; ac uuid; ap uuid;   -- competition identities
  v_events jsonb;
  v_result jsonb;
  v_stats jsonb;
  v_club jsonb;
  v_message text;
  v_player jsonb;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at) values
    (v_admin,'authenticated','authenticated','ci-goals-admin@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_home_captain,'authenticated','authenticated','ci-goals-hc@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_home_player,'authenticated','authenticated','ci-goals-hp@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_away_captain,'authenticated','authenticated','ci-goals-ac@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_away_player,'authenticated','authenticated','ci-goals-ap@openplay.invalid','','{}'::jsonb,now(),now());

  select id into v_location from public.locations where is_active is true order by created_at limit 1;
  if not found then
    insert into public.locations(name,slug,town,region,is_active)
    values('Goals Test Location','ci-goals-location','Bideford','Devon',true) returning id into v_location;
  end if;
  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'admin',v_admin);
  insert into public.leagues(id,location_id,name,slug,format,is_published)
  values(v_league,v_location,'Goals Test League','ci-goals-league','six_a_side',true);
  insert into public.seasons(id,league_id,name,season_number,is_public,status)
  values(v_season,v_league,'Goals Test Season',1,true,'active');
  insert into public.teams(id,created_by) values(v_home_team,v_home_captain),(v_away_team,v_away_captain);
  insert into public.season_teams(id,team_id,season_id,name,slug,registration_status) values
    (v_home_st,v_home_team,v_season,'Goals Home','ci-goals-home','approved'),
    (v_away_st,v_away_team,v_season,'Goals Away','ci-goals-away','approved');
  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_genuine,is_banned) values
    (v_home_captain,'Goals Home Captain','+447700962002','ci-goals-hc@openplay.invalid',date '1990-01-01','registered',true,false),
    (v_home_player,'Goals Home Player','+447700962003','ci-goals-hp@openplay.invalid',date '1990-01-02','registered',true,false),
    (v_away_captain,'Goals Away Captain','+447700962005','ci-goals-ac@openplay.invalid',date '1990-01-04','registered',true,false),
    (v_away_player,'Goals Away Player','+447700962006','ci-goals-ap@openplay.invalid',date '1990-01-05','registered',true,false);
  select competition_player_id into hc from public.players where user_id=v_home_captain;
  select competition_player_id into hp from public.players where user_id=v_home_player;
  select competition_player_id into ac from public.players where user_id=v_away_captain;
  select competition_player_id into ap from public.players where user_id=v_away_player;
  insert into public.team_memberships(id,season_team_id,user_id,status,is_captain) values
    ('9b000000-0000-4000-8000-000000000070',v_home_st,v_home_captain,'active',true),
    ('9b000000-0000-4000-8000-000000000071',v_home_st,v_home_player,'active',false),
    ('9b000000-0000-4000-8000-000000000073',v_away_st,v_away_captain,'active',true),
    ('9b000000-0000-4000-8000-000000000074',v_away_st,v_away_player,'active',false);
  insert into public.fixtures(id,season_id,gameweek,fixture_number,home_team_id,away_team_id,scheduled_at,status)
  values(v_fixture,v_season,1,1,v_home_st,v_away_st,now()+interval '2 hours','scheduled');

  -- Team-sheet triggers require the submitting captain's context.
  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_home_captain)::text,true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked,submitted_at)
  values(v_fixture,v_home_st,v_home_captain,true,now()) returning id into v_home_sheet;
  insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role)
  values(v_home_sheet,v_home_captain,'starter'),(v_home_sheet,v_home_player,'starter');
  update public.fixture_team_sheet_players set did_appear=true where team_sheet_id=v_home_sheet;

  perform set_config('request.jwt.claim.sub',v_away_captain::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_away_captain)::text,true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked,submitted_at)
  values(v_fixture,v_away_st,v_away_captain,true,now()) returning id into v_away_sheet;
  insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role)
  values(v_away_sheet,v_away_captain,'starter'),(v_away_sheet,v_away_player,'starter');
  update public.fixture_team_sheet_players set did_appear=true where team_sheet_id=v_away_sheet;

  update public.fixtures set scheduled_at=now()-interval '2 hours', status='completed' where id=v_fixture;
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by)
  values(v_fixture,3,1,now(),v_admin);

  -- Non-administrators are refused.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_home_captain,'role','authenticated')::text,true);
  v_message:=null;
  begin perform public.admin_record_fixture_goal_events(v_fixture,'[]'::jsonb,'captain attempt'); exception when others then v_message:=sqlerrm; end;
  if v_message is null then raise exception 'A captain recorded goal events'; end if;

  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_admin,'role','authenticated')::text,true);

  -- Validation cases: each must be rejected with its specific message.
  foreach v_events in array array[
    jsonb_build_array(jsonb_build_object('team_side','home','scorer_competition_player_id',ap,'is_own_goal',true,'assist_competition_player_id',hp)),
    jsonb_build_array(jsonb_build_object('team_side','home','scorer_competition_player_id',ap)),
    jsonb_build_array(jsonb_build_object('team_side','home','scorer_competition_player_id',hp,'is_own_goal',true)),
    jsonb_build_array(jsonb_build_object('team_side','home','scorer_competition_player_id',hp,'assist_competition_player_id',ac)),
    jsonb_build_array(jsonb_build_object('team_side','home','scorer_competition_player_id',hp,'assist_competition_player_id',hp)),
    jsonb_build_array(jsonb_build_object('team_side','away','scorer_competition_player_id',ac),jsonb_build_object('team_side','away','scorer_competition_player_id',ap))
  ] loop
    v_message:=null;
    begin perform public.admin_record_fixture_goal_events(v_fixture,v_events,'validation case'); exception when others then v_message:=sqlerrm; end;
    if v_message is null then raise exception 'Invalid goal events were accepted: %', v_events; end if;
  end loop;

  -- Home 3: home player (assist home captain), home captain, own goal by the away player. Away 1: away captain (assist away player).
  v_events:=jsonb_build_array(
    jsonb_build_object('team_side','home','scorer_competition_player_id',hp,'assist_competition_player_id',hc),
    jsonb_build_object('team_side','home','scorer_competition_player_id',hc),
    jsonb_build_object('team_side','home','scorer_competition_player_id',ap,'is_own_goal',true),
    jsonb_build_object('team_side','away','scorer_competition_player_id',ac,'assist_competition_player_id',ap));
  v_result:=public.admin_record_fixture_goal_events(v_fixture,v_events,'Initial goal events');
  if (v_result->>'recorded')::integer<>4 or (v_result->>'unattributed_home')::integer<>0 then
    raise exception 'Unexpected recording result: %', v_result;
  end if;
  -- Recording again voids, never deletes, the earlier records.
  perform public.admin_record_fixture_goal_events(v_fixture,v_events,'Correction re-entry');

  execute 'reset role';
  if (select count(*) from public.fixture_goal_records where fixture_id=v_fixture and voided_at is null)<>4
     or (select count(*) from public.fixture_goal_records where fixture_id=v_fixture and voided_at is not null and void_reason='Correction re-entry')<>4 then
    raise exception 'Correction must void the previous four records and keep four active';
  end if;
  if (select count(*) from public.audit_log where action='fixture.goal_events_recorded' and entity_id=v_fixture::text)<>2 then
    raise exception 'Goal event recording must be audited';
  end if;

  execute 'set local role authenticated';
  v_stats:=public.get_admin_season_statistics(v_season);
  v_club:=public.get_admin_season_player_club_statistics(v_season);
  execute 'reset role';

  select p into v_player from jsonb_array_elements(v_stats->'players') p where (p->>'competition_player_id')::uuid=ap;
  if (v_player->>'goals')::integer<>0 or (v_player->>'assists')::integer<>1 or (v_player->>'goal_contributions')::integer<>1 then
    raise exception 'Own goal must not count for the scorer; assist must count: %', v_player;
  end if;
  select p into v_player from jsonb_array_elements(v_stats->'players') p where (p->>'competition_player_id')::uuid=hc;
  if (v_player->>'goals')::integer<>1 or (v_player->>'assists')::integer<>1 or (v_player->>'goal_contributions')::integer<>2 then
    raise exception 'Home captain should have 1 goal, 1 assist, 2 contributions: %', v_player;
  end if;
  if exists (select 1 from jsonb_array_elements(v_club) c
             where (c->>'competition_player_id')::uuid=ap and (c->>'team_id')::uuid=v_home_st) then
    raise exception 'An own goal must not create a club row for the benefiting team: %', v_club;
  end if;

  -- Player Hub (self-service) statistics.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_home_captain,'role','authenticated')::text,true);
  v_stats:=public.get_my_player_statistics(v_season);
  execute 'reset role';
  if (v_stats->'season'->>'goals')::integer<>1 or (v_stats->'season'->>'assists')::integer<>1
     or (v_stats->'season'->>'goal_contributions')::integer<>2 or v_stats->'season'->>'appearances_display'<>'1(0)'
     or (v_stats->'career'->>'goal_contributions')::integer<>2 then
    raise exception 'Player Hub statistics missing assists/contributions/display: %', v_stats;
  end if;

  if pg_catalog.has_function_privilege('anon','public.admin_record_fixture_goal_events(uuid,jsonb,text)','EXECUTE') then
    raise exception 'Anonymous clients must not record goal events';
  end if;
end;
$goal_events$;

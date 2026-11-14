-- Fixture match report: signed-in only, published scope only, events only once the result is
-- confirmed, voided goals and unlocked sheets excluded, display names only.
begin;

do $test$
declare
  v_admin uuid:=gen_random_uuid();
  v_viewer uuid:=gen_random_uuid();
  v_location uuid; v_league uuid; v_season uuid; v_hidden_season uuid;
  v_team uuid; v_opp_team uuid; v_pending_team uuid; v_st uuid; v_opp uuid; v_hidden_st uuid; v_hidden_opp uuid; v_pending uuid;
  v_users uuid[]:='{}'; v_ids uuid[]:='{}'; v_user uuid; v_identity uuid; i integer;
  v_fixture uuid; v_unconfirmed uuid; v_scheduled uuid; v_hidden_fixture uuid; v_pending_fixture uuid;
  v_sheet uuid; v_away_sheet uuid;
  v_report jsonb; v_failed text; v_count integer; v_goal jsonb; v_text text;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values(v_admin,'authenticated','authenticated','ci-report-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
        (v_viewer,'authenticated','authenticated','ci-report-viewer@openplay.invalid','','{}'::jsonb,now(),now(),now());
  -- First release allows one active location; reuse it when an earlier suite created it.
  select id into v_location from public.locations where is_active is true limit 1;
  if v_location is null then
    insert into public.locations(name,slug,town,region,is_active)
    values('Report Test Location','ci-report-location','Bideford','Devon',true) returning id into v_location;
  end if;
  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Report League','ci-report-league',true) returning id into v_league;
  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Report Season',1,'active',true) returning id into v_season;
  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Report Hidden Season',2,'draft',false) returning id into v_hidden_season;
  insert into public.teams(created_by) values(v_admin) returning id into v_team;
  insert into public.teams(created_by) values(v_admin) returning id into v_opp_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values(v_team,v_season,'Report Home','ci-report-home','approved',now(),v_admin) returning id into v_st;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values(v_opp_team,v_season,'Report Away','ci-report-away','approved',now(),v_admin) returning id into v_opp;
  insert into public.teams(created_by) values(v_admin) returning id into v_pending_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values(v_pending_team,v_season,'Report Pending','ci-report-pending','approved',now(),v_admin) returning id into v_pending;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values(v_team,v_hidden_season,'Report Hidden Home','ci-report-hidden-home','approved',now(),v_admin) returning id into v_hidden_st;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values(v_opp_team,v_hidden_season,'Report Hidden Away','ci-report-hidden-away','approved',now(),v_admin) returning id into v_hidden_opp;

  -- Players 1-7 for the home side, 8-9 for the away side.
  for i in 1..9 loop
    v_user:=gen_random_uuid();
    insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
    values(v_user,'authenticated','authenticated',format('ci-report-%s@openplay.invalid',i),'','{}'::jsonb,now(),now(),now());
    insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
    values(v_user,format('Report Player %s',i),format('+447700944%s',lpad(i::text,3,'0')),format('ci-report-%s@openplay.invalid',i),date '1993-04-04','registered',false);
    insert into public.team_memberships(season_team_id,user_id,status,is_captain,squad_number,joined_at)
    values(case when i<=7 then v_st else v_opp end,v_user,'active',i in (1,8),i::smallint,now());
    select competition_player_id into v_identity from public.players where user_id=v_user;
    v_users:=v_users||v_user; v_ids:=v_ids||v_identity;
  end loop;

  perform set_config('request.jwt.claim.role','service_role',true);
  -- Published fixture: home 2-1. Player 2 scores twice (one assisted by player 3); player 4's
  -- goal was voided; home player 5 scores an own goal credited to the away side.
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,scheduled_at,status)
  values(v_season,1,1,v_st,v_opp,now()-interval '3 days','completed') returning id into v_fixture;
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by) values(v_fixture,2,1,now(),v_admin);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,submitted_at,is_locked)
  values(v_fixture,v_st,v_users[1],now(),true) returning id into v_sheet;
  for i in 1..6 loop
    insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,is_goalkeeper,did_appear,competition_player_id,squad_number_snapshot)
    values(v_sheet,v_users[i],'starter',i=1,true,v_ids[i],i::smallint);
  end loop;
  -- Named substitute who did not appear: not part of the report.
  insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,is_goalkeeper,did_appear,competition_player_id,squad_number_snapshot)
  values(v_sheet,v_users[7],'substitute',false,false,v_ids[7],7);
  -- Away sheet saved but never locked: not part of the report.
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,submitted_at,is_locked)
  values(v_fixture,v_opp,v_users[8],now(),false) returning id into v_away_sheet;
  insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,is_goalkeeper,did_appear,competition_player_id)
  values(v_away_sheet,v_users[8],'starter',true,true,v_ids[8]);
  insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,created_by,competition_player_id,assist_competition_player_id,created_at)
  values(v_fixture,v_st,v_users[2],v_admin,v_ids[2],v_ids[3],now()-interval '3 minutes'),
        (v_fixture,v_st,v_users[2],v_admin,v_ids[2],null,now()-interval '2 minutes');
  insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,created_by,competition_player_id,is_own_goal,created_at)
  values(v_fixture,v_opp,v_users[5],v_admin,v_ids[5],true,now()-interval '1 minute');
  insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,created_by,competition_player_id,voided_at,voided_by,void_reason)
  values(v_fixture,v_st,v_users[4],v_admin,v_ids[4],now(),v_admin,'CI voided goal');
  insert into public.fixture_motm_nominations(fixture_id,season_team_id,competition_player_id,nominated_by)
  values(v_fixture,v_st,v_ids[2],v_users[1]),(v_fixture,v_opp,v_ids[9],v_users[8]);

  -- Completed but unconfirmed: nothing may leak, although a goal record exists.
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,scheduled_at,status)
  values(v_season,2,1,v_st,v_opp,now()-interval '2 days','completed') returning id into v_unconfirmed;
  insert into public.fixture_results(fixture_id,home_score,away_score) values(v_unconfirmed,4,0);
  insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,created_by,competition_player_id)
  values(v_unconfirmed,v_st,v_users[6],v_admin,v_ids[6]);
  -- Scheduled fixture, a fixture in an unpublished season, and one against an unapproved team.
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,scheduled_at,status)
  values(v_season,3,1,v_st,v_opp,now()+interval '4 days','scheduled') returning id into v_scheduled;
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,scheduled_at,status)
  values(v_hidden_season,1,1,v_hidden_st,v_hidden_opp,now()-interval '1 day','completed') returning id into v_hidden_fixture;
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by) values(v_hidden_fixture,1,0,now(),v_admin);
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,scheduled_at,status)
  values(v_season,4,1,v_st,v_pending,now()+interval '9 days','scheduled') returning id into v_pending_fixture;
  -- The opponent's registration is later rejected, so the fixture leaves the published scope.
  update public.season_teams set registration_status='rejected' where id=v_pending;

  perform set_config('request.jwt.claim.role','authenticated',true);

  -- Negative: visitors cannot execute the function.
  if has_function_privilege('anon','public.get_public_fixture_match_report(uuid)','EXECUTE') then
    raise exception 'Match report must not be executable by anon';
  end if;
  if not has_function_privilege('authenticated','public.get_public_fixture_match_report(uuid)','EXECUTE') then
    raise exception 'Match report must be executable by signed-in members';
  end if;
  -- Negative: unauthenticated callers are refused inside the function too.
  perform set_config('request.jwt.claim.sub','',true);
  v_failed:=null;
  begin perform public.get_public_fixture_match_report(v_fixture); exception when others then v_failed:=sqlstate; end;
  if v_failed is distinct from '42501' then raise exception 'Unauthenticated report read must be refused, got %',v_failed; end if;

  perform set_config('request.jwt.claim.sub',v_viewer::text,true);
  -- Negative: unpublished season, unapproved opponent, unknown and null fixtures are not found.
  foreach v_identity in array array[v_hidden_fixture,v_pending_fixture,gen_random_uuid()] loop
    v_failed:=null;
    begin perform public.get_public_fixture_match_report(v_identity); exception when others then v_failed:=sqlstate; end;
    if v_failed is distinct from 'P0002' then raise exception 'Out-of-scope fixture % must be refused, got %',v_identity,v_failed; end if;
  end loop;
  v_failed:=null;
  begin perform public.get_public_fixture_match_report(null); exception when others then v_failed:=sqlstate; end;
  if v_failed is distinct from 'P0002' then raise exception 'Null fixture must be refused, got %',v_failed; end if;

  -- Negative: an unconfirmed result and a scheduled fixture expose no events.
  foreach v_identity in array array[v_unconfirmed,v_scheduled] loop
    v_report:=public.get_public_fixture_match_report(v_identity);
    if (v_report->>'published')::boolean is not false
       or jsonb_array_length(v_report->'goals')<>0 or jsonb_array_length(v_report->'motm')<>0
       or jsonb_array_length(v_report->'lineups')<>0 then
      raise exception 'Unpublished fixture must not expose events: %',v_report;
    end if;
  end loop;

  -- Positive: the published report.
  v_report:=public.get_public_fixture_match_report(v_fixture);
  if (v_report->>'published')::boolean is not true then raise exception 'Published report expected: %',v_report; end if;
  if jsonb_array_length(v_report->'goals')<>3 then raise exception 'Expected 3 non-voided goals, got %',v_report->'goals'; end if;
  v_goal:=v_report->'goals'->0;
  if v_goal->>'team_side'<>'home' or v_goal->>'scorer_name'<>'Report Player 2' or v_goal->>'assist_name'<>'Report Player 3'
     or (v_goal->>'is_own_goal')::boolean then
    raise exception 'First goal wrong: %',v_goal;
  end if;
  v_goal:=v_report->'goals'->1;
  if v_goal->>'team_side'<>'home' or v_goal->'assist_name'<>'null'::jsonb then raise exception 'Second goal wrong: %',v_goal; end if;
  v_goal:=v_report->'goals'->2;
  if v_goal->>'team_side'<>'away' or v_goal->>'scorer_name'<>'Report Player 5' or not (v_goal->>'is_own_goal')::boolean then
    raise exception 'Own goal must be credited to the away side with the home scorer named: %',v_goal;
  end if;
  if exists(select 1 from jsonb_array_elements(v_report->'goals') g where g->>'scorer_name'='Report Player 4') then
    raise exception 'Voided goal must not be reported';
  end if;
  -- Goals per side never exceed the confirmed score.
  if (select count(*) from jsonb_array_elements(v_report->'goals') g where g->>'team_side'='home')<>2
     or (select count(*) from jsonb_array_elements(v_report->'goals') g where g->>'team_side'='away')<>1 then
    raise exception 'Goal sides do not match the 2-1 result: %',v_report->'goals';
  end if;

  if jsonb_array_length(v_report->'motm')<>2
     or v_report->'motm'->0->>'team_side'<>'home' or v_report->'motm'->0->>'player_name'<>'Report Player 2'
     or v_report->'motm'->1->>'team_side'<>'away' or v_report->'motm'->1->>'player_name'<>'Report Player 9' then
    raise exception 'Man of the Match wrong: %',v_report->'motm';
  end if;

  select count(*) into v_count from jsonb_array_elements(v_report->'lineups');
  if v_count<>6 then raise exception 'Expected 6 appearances from the locked home sheet only, got %: %',v_count,v_report->'lineups'; end if;
  if v_report->'lineups'->0->>'player_name'<>'Report Player 1' or not (v_report->'lineups'->0->>'is_goalkeeper')::boolean
     or v_report->'lineups'->0->>'role'<>'starter' or (v_report->'lineups'->0->>'squad_number')::int<>1 then
    raise exception 'Goalkeeper must lead the line-up: %',v_report->'lineups'->0;
  end if;
  if exists(select 1 from jsonb_array_elements(v_report->'lineups') p where p->>'player_name' in ('Report Player 7','Report Player 8')) then
    raise exception 'Non-appearing substitutes and unlocked sheets must be excluded';
  end if;

  -- Negative: no account identifiers or contact details anywhere in the payload.
  v_text:=v_report::text;
  if v_text like '%@%' or v_text like '%+44%' or v_text like '%1993%' then raise exception 'Report leaks contact data: %',v_text; end if;
  for i in 1..9 loop
    if v_text like '%'||v_users[i]::text||'%' or v_text like '%'||v_ids[i]::text||'%' then
      raise exception 'Report leaks account or identity ids';
    end if;
  end loop;

  -- Anonymised identities keep the historical record under the anonymised label.
  perform set_config('request.jwt.claim.role','service_role',true);
  update public.competition_player_identities set display_name='Former player',anonymised_at=now() where id=v_ids[3];
  perform set_config('request.jwt.claim.role','authenticated',true);
  v_report:=public.get_public_fixture_match_report(v_fixture);
  if v_report->'goals'->0->>'assist_name'<>'Former player' then
    raise exception 'Anonymised assist must read Former player: %',v_report->'goals'->0;
  end if;

  perform set_config('request.jwt.claim.sub','',true);
end;
$test$;

rollback;

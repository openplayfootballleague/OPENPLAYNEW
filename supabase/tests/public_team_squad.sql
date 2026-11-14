-- Team hub squad and directory counts: published-scope, signed-in only, no contact data,
-- statistics from completed fixtures with confirmed results only.
begin;

do $test$
declare
  v_admin uuid:=gen_random_uuid();
  v_viewer uuid:=gen_random_uuid();
  v_location uuid; v_league uuid; v_season uuid; v_hidden_season uuid;
  v_team uuid; v_opp_team uuid; v_st uuid; v_opp uuid; v_hidden_st uuid;
  v_users uuid[]:='{}'; v_ids uuid[]:='{}'; v_user uuid; v_identity uuid; i integer;
  v_fixture uuid; v_unconfirmed uuid; v_sheet uuid;
  v_row record; v_failed text; v_count bigint;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values(v_admin,'authenticated','authenticated','ci-squad-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
        (v_viewer,'authenticated','authenticated','ci-squad-viewer@openplay.invalid','','{}'::jsonb,now(),now(),now());
  -- First release allows one active location; reuse it when an earlier suite created it.
  select id into v_location from public.locations where is_active is true limit 1;
  if v_location is null then
    insert into public.locations(name,slug,town,region,is_active)
    values('Squad Test Location','ci-squad-location','Bideford','Devon',true) returning id into v_location;
  end if;
  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Squad League','ci-squad-league',true) returning id into v_league;
  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Squad Season',1,'active',true) returning id into v_season;
  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Hidden Season',2,'draft',false) returning id into v_hidden_season;
  insert into public.teams(created_by) values(v_admin) returning id into v_team;
  insert into public.teams(created_by) values(v_admin) returning id into v_opp_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values(v_team,v_season,'Squad Home','ci-squad-home','approved',now(),v_admin) returning id into v_st;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values(v_opp_team,v_season,'Squad Away','ci-squad-away','approved',now(),v_admin) returning id into v_opp;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values(v_team,v_hidden_season,'Squad Hidden','ci-squad-hidden','approved',now(),v_admin) returning id into v_hidden_st;

  -- Seven players; player 7 is banned and must not be listed or counted.
  for i in 1..7 loop
    v_user:=gen_random_uuid();
    insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
    values(v_user,'authenticated','authenticated',format('ci-squad-%s@openplay.invalid',i),'','{}'::jsonb,now(),now(),now());
    insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
    values(v_user,format('Squad Player %s',i),format('+447700943%s',lpad(i::text,3,'0')),format('ci-squad-%s@openplay.invalid',i),date '1994-05-05','registered',false);
    insert into public.team_memberships(season_team_id,user_id,status,is_captain,squad_number,joined_at)
    values(v_st,v_user,'active',i=1,i::smallint,now());
    select competition_player_id into v_identity from public.players where user_id=v_user;
    v_users:=v_users||v_user; v_ids:=v_ids||v_identity;
  end loop;
  update public.players set is_banned=true,banned_at=now(),banned_reason='CI banned player' where user_id=v_users[7];
  -- Players 1-5 have passed identity review; player 6 has not, so is listed with zero totals.
  update public.competition_player_identities set counts_for_statistics=true where id=any(v_ids[1:5]);
  update public.competition_player_identities set counts_for_statistics=false where id=v_ids[6];

  -- Historical match data is inserted as the service role, as other regression suites do.
  perform set_config('request.jwt.claim.role','service_role',true);
  -- Completed fixture with a confirmed 2-0 home win; player 1 in goal, players 1-6 appear.
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,scheduled_at,status)
  values(v_season,1,1,v_st,v_opp,now()-interval '3 days','completed') returning id into v_fixture;
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by) values(v_fixture,2,0,now(),v_admin);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,submitted_at,is_locked)
  values(v_fixture,v_st,v_users[1],now(),true) returning id into v_sheet;
  for i in 1..6 loop
    insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,is_goalkeeper,did_appear,competition_player_id)
    values(v_sheet,v_users[i],'starter',i=1,true,v_ids[i]);
  end loop;
  insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,created_by,competition_player_id,assist_competition_player_id)
  values(v_fixture,v_st,v_users[2],v_admin,v_ids[2],v_ids[3]),(v_fixture,v_st,v_users[2],v_admin,v_ids[2],null);
  insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,created_by,competition_player_id,voided_at,voided_by,void_reason)
  values(v_fixture,v_st,v_users[4],v_admin,v_ids[4],now(),v_admin,'CI voided goal');
  insert into public.fixture_motm_nominations(fixture_id,season_team_id,competition_player_id,nominated_by)
  values(v_fixture,v_st,v_ids[2],v_users[1]);

  -- A completed fixture whose result is NOT confirmed must not count.
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,scheduled_at,status)
  values(v_season,2,1,v_st,v_opp,now()-interval '2 days','completed') returning id into v_unconfirmed;
  insert into public.fixture_results(fixture_id,home_score,away_score) values(v_unconfirmed,5,0);
  insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,created_by,competition_player_id)
  values(v_unconfirmed,v_st,v_users[5],v_admin,v_ids[5]);

  perform set_config('request.jwt.claim.role','authenticated',true);
  -- Negative: visitors cannot execute either function.
  if has_function_privilege('anon','public.get_public_team_squad(uuid)','EXECUTE')
     or has_function_privilege('anon','public.get_public_season_team_squad_counts(uuid)','EXECUTE') then
    raise exception 'Squad functions must not be executable by anon';
  end if;
  -- Negative: no contact or identity columns in the result.
  if exists(select 1 from pg_proc p, unnest(p.proargnames) a where p.proname in ('get_public_team_squad','get_public_season_team_squad_counts')
            and a in ('phone','email','date_of_birth','user_id','full_name')) then
    raise exception 'Squad functions must not return contact or account fields';
  end if;
  -- Negative: unauthenticated callers are refused inside the function too.
  perform set_config('request.jwt.claim.sub','',true);
  v_failed:=null;
  begin perform public.get_public_team_squad(v_st); exception when others then v_failed:=sqlstate; end;
  if v_failed is distinct from '42501' then raise exception 'Unauthenticated squad read must be refused, got %',v_failed; end if;

  perform set_config('request.jwt.claim.sub',v_viewer::text,true);
  -- Negative: an unpublished season's team is not exposed.
  v_failed:=null;
  begin perform public.get_public_team_squad(v_hidden_st); exception when others then v_failed:=sqlstate; end;
  if v_failed is distinct from 'P0002' then raise exception 'Unpublished team squad must be refused, got %',v_failed; end if;
  v_failed:=null;
  begin perform public.get_public_season_team_squad_counts(v_hidden_season); exception when others then v_failed:=sqlstate; end;
  if v_failed is distinct from 'P0002' then raise exception 'Unpublished season counts must be refused, got %',v_failed; end if;

  -- Positive: counts and squad exclude the banned player.
  select registered_players into v_count from public.get_public_season_team_squad_counts(v_season) where season_team_id=v_st;
  if v_count<>6 then raise exception 'Expected 6 registered players, got %',v_count; end if;
  select count(*) into v_count from public.get_public_team_squad(v_st);
  if v_count<>6 then raise exception 'Expected 6 squad rows, got %',v_count; end if;
  if exists(select 1 from public.get_public_team_squad(v_st) where competition_player_id=v_ids[7]) then
    raise exception 'Banned player must not be listed';
  end if;

  -- Positive: statistics follow the agreed definitions.
  select * into v_row from public.get_public_team_squad(v_st) where competition_player_id=v_ids[1];
  if not v_row.is_captain or v_row.appearances<>1 or v_row.clean_sheets<>1 or v_row.goals<>0 then
    raise exception 'Captain/goalkeeper row wrong: %',v_row;
  end if;
  select * into v_row from public.get_public_team_squad(v_st) where competition_player_id=v_ids[2];
  if v_row.goals<>2 or v_row.motm_awards<>1 or v_row.appearances<>1 then raise exception 'Scorer row wrong: %',v_row; end if;
  select * into v_row from public.get_public_team_squad(v_st) where competition_player_id=v_ids[3];
  if v_row.assists<>1 or v_row.goals<>0 then raise exception 'Assist row wrong: %',v_row; end if;
  select * into v_row from public.get_public_team_squad(v_st) where competition_player_id=v_ids[4];
  if v_row.goals<>0 then raise exception 'Voided goal must not count: %',v_row; end if;
  select * into v_row from public.get_public_team_squad(v_st) where competition_player_id=v_ids[5];
  if v_row.goals<>0 or v_row.appearances<>1 then raise exception 'Unconfirmed result must not count: %',v_row; end if;
  select * into v_row from public.get_public_team_squad(v_st) where competition_player_id=v_ids[6];
  if v_row.appearances<>0 then raise exception 'Identity not eligible for statistics must show zero totals: %',v_row; end if;
  perform set_config('request.jwt.claim.sub','',true);
end;
$test$;

rollback;

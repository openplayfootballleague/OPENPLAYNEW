-- Manual season recruitment activation is location-scoped and blocked until
-- the prior season's final fixture is completed with a result.
begin;

do $season_recruitment$
declare
  v_admin uuid:=gen_random_uuid();
  v_nonadmin uuid:=gen_random_uuid();
  v_location uuid;
  v_league uuid;
  v_previous uuid;
  v_upcoming uuid;
  v_blocked uuid;
  v_no_result uuid;
  v_home uuid;
  v_away uuid;
  v_home_team uuid;
  v_away_team uuid;
  v_fixture uuid;
  v_blocked_home uuid;
  v_blocked_away uuid;
  v_blocked_home_team uuid;
  v_blocked_away_team uuid;
  v_blocked_fixture uuid;
  v_opened public.seasons;
  v_failed boolean;
begin
  if pg_catalog.has_function_privilege('anon','public.admin_publish_upcoming_season(uuid,text)','EXECUTE')
     or not pg_catalog.has_function_privilege('authenticated','public.admin_publish_upcoming_season(uuid,text)','EXECUTE')
     or pg_catalog.has_function_privilege('anon','public.admin_open_season_recruitment(uuid,text)','EXECUTE')
     or not pg_catalog.has_function_privilege('authenticated','public.admin_open_season_recruitment(uuid,text)','EXECUTE')
     or pg_catalog.has_function_privilege('anon','public.admin_close_season_recruitment(uuid,text)','EXECUTE')
     or not pg_catalog.has_function_privilege('authenticated','public.admin_close_season_recruitment(uuid,text)','EXECUTE') then
    raise exception 'Season recruitment mutation RPC grants are not least-privilege';
  end if;
  if position('recruitment_status' in pg_catalog.pg_get_functiondef('public.get_admin_competition_setup()'::regprocedure))=0 then
    raise exception 'Admin season setup does not expose the persisted recruitment state';
  end if;

  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values(v_admin,'authenticated','authenticated','ci-season-admin@openplay.invalid','','{}'::jsonb,now(),now(),now());
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values(v_nonadmin,'authenticated','authenticated','ci-season-nonadmin@openplay.invalid','','{}'::jsonb,now(),now(),now());
  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'admin',v_admin);

  insert into public.locations(name,slug,town,region,is_active)
  values('Manual Season Recruitment Test','ci-manual-season-recruitment','Bideford','Devon',false)
  returning id into v_location;
  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location,'Manual Season Recruitment League','ci-manual-season-recruitment','six_a_side',false)
  returning id into v_league;

  insert into public.seasons(league_id,name,season_number,status,is_public,starts_on)
  values(v_league,'Previous Season',1,'active',false,date '2026-01-01')
  returning id into v_previous;
  insert into public.seasons(league_id,name,season_number,status,is_public,starts_on)
  values(v_league,'Upcoming Season',2,'draft',false,date '2027-01-01')
  returning id into v_upcoming;
  insert into public.seasons(league_id,name,season_number,status,is_public,starts_on)
  values(v_league,'Blocked Following Season',3,'draft',false,date '2027-06-01')
  returning id into v_blocked;
  insert into public.seasons(league_id,name,season_number,status,is_public,starts_on)
  values(v_league,'Missing Result Season',4,'draft',false,date '2027-12-01')
  returning id into v_no_result;

  insert into public.teams(created_by) values(v_admin) returning id into v_home;
  insert into public.teams(created_by) values(v_admin) returning id into v_away;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values
    (v_home,v_previous,'Previous Home','ci-prev-home','approved',now(),v_admin),
    (v_away,v_previous,'Previous Away','ci-prev-away','approved',now(),v_admin)
  ;

  select id into v_home_team from public.season_teams where season_id=v_previous and name='Previous Home';
  select id into v_away_team from public.season_teams where season_id=v_previous and name='Previous Away';
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_previous,14,1,v_home_team,v_away_team,v_location,now()-interval '1 day','completed')
  returning id into v_fixture;
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by)
  values(v_fixture,3,2,now(),v_admin);

  insert into public.teams(created_by) values(v_admin) returning id into v_blocked_home;
  insert into public.teams(created_by) values(v_admin) returning id into v_blocked_away;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values
    (v_blocked_home,v_blocked,'Blocked Home','ci-blocked-home','approved',now(),v_admin),
    (v_blocked_away,v_blocked,'Blocked Away','ci-blocked-away','approved',now(),v_admin);
  select id into v_blocked_home_team from public.season_teams where season_id=v_blocked and name='Blocked Home';
  select id into v_blocked_away_team from public.season_teams where season_id=v_blocked and name='Blocked Away';
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_blocked,14,1,v_blocked_home_team,v_blocked_away_team,v_location,now()-interval '1 hour','completed')
  returning id into v_blocked_fixture;

  v_failed:=false;
  begin
    update public.seasons set status='registration_open' where id=v_blocked;
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then raise exception 'A direct status update bypassed the audited recruitment activation'; end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  select * into v_opened from public.admin_publish_upcoming_season(v_upcoming,'Publish next season coming soon');
  if v_opened.is_public is not true or v_opened.recruitment_status<>'closed' then
    raise exception 'Publishing the upcoming season must not open recruitment';
  end if;
  select * into v_opened from public.admin_open_season_recruitment(v_upcoming,'Previous season final match completed');
  if v_opened.recruitment_status<>'open' or v_opened.status::text<>'registration_open' or v_opened.is_public is not true then
    raise exception 'Manual activation did not open recruitment for the upcoming season';
  end if;

  perform set_config('request.jwt.claim.sub',v_nonadmin::text,true);
  v_failed:=false;
  begin
    perform public.admin_open_season_recruitment(v_blocked,'Unauthorised activation attempt');
  exception when sqlstate '42501' then v_failed:=true;
  end;
  if not v_failed then raise exception 'An unassigned non-admin account opened season recruitment'; end if;
  perform set_config('request.jwt.claim.sub',v_admin::text,true);

  v_failed:=false;
  begin
    perform public.admin_open_season_recruitment(v_blocked,'Must remain closed until season two finishes');
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then raise exception 'A following season opened before the previous season final fixture existed'; end if;

  v_failed:=false;
  begin
    perform public.admin_open_season_recruitment(v_no_result,'Final fixture must have a published result');
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then raise exception 'A season opened when the previous final fixture had no published result'; end if;

  execute 'reset role';

  v_failed:=false;
  begin
    insert into public.season_registrations(season_id,user_id,status)
    values(v_blocked,v_admin,'pending');
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then raise exception 'A player registration was accepted for a closed upcoming season'; end if;

  insert into public.teams(created_by) values(v_admin) returning id into v_home;
  v_failed:=false;
  begin
    insert into public.season_teams(team_id,season_id,name,slug,registration_status)
    values(v_home,v_blocked,'Closed Team','ci-closed-team','pending');
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then raise exception 'A team application was accepted for a closed upcoming season'; end if;

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_genuine,is_banned)
  values(v_admin,'Season Recruitment Admin','+447700969991','ci-season-admin@openplay.invalid',date '1990-01-01','registered',true,false);
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values(v_home,v_blocked,'Closed Membership Team','ci-closed-membership-team','approved',now(),v_admin);
  v_failed:=false;
  begin
    insert into public.team_memberships(season_team_id,user_id,status,is_captain)
    values((select id from public.season_teams where slug='ci-closed-membership-team'),v_admin,'pending',false);
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then raise exception 'A future season membership was created before recruitment opened'; end if;

  if (select recruitment_status from public.seasons where id=v_upcoming)<>'open' then
    raise exception 'Manual activation did not persist';
  end if;
  if (select recruitment_status from public.seasons where id=v_blocked)<>'closed' then
    raise exception 'Blocked season recruitment state was changed';
  end if;
end;
$season_recruitment$;

rollback;

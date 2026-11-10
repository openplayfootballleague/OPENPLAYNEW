-- Referee fixture assignment, availability, authorization and history regression.
-- Disposable local Supabase database only.
do $referee_fixture_assignment$
declare
  v_admin constant uuid:='94100000-0000-4000-8000-000000000001';
  v_referee constant uuid:='94100000-0000-4000-8000-000000000002';
  v_unprivileged constant uuid:='94100000-0000-4000-8000-000000000003';
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_home uuid;
  v_away uuid;
  v_fixture uuid;
  v_second_fixture uuid;
  v_third_fixture uuid;
  v_application uuid;
  v_assignment public.referee_fixture_assignments;
  v_start timestamptz;
  v_weekday integer;
  v_rejected boolean;
  v_count integer;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-referee-assign-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_referee,'authenticated','authenticated','ci-referee-assign-referee@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_unprivileged,'authenticated','authenticated','ci-referee-assign-player@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
  values
    (v_referee,'Fixture Test Referee','07700900702','ci-referee-assign-referee@openplay.invalid',date '1990-02-02','registered',false),
    (v_unprivileged,'Fixture Test Player','07700900703','ci-referee-assign-player@openplay.invalid',date '1990-02-03','registered',false);

  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'admin',v_admin);
  select id into v_location from public.locations where is_active=true order by created_at limit 1;
  if v_location is null then raise exception 'Expected an active fixture location from earlier regression'; end if;

  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Referee Appointment League','ci-referee-appointment-league',false)
  returning id into v_league;
  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Referee Appointment Season',991,'active',false)
  returning id into v_season;

  insert into public.teams(created_by) values(v_admin) returning id into v_home;
  insert into public.teams(created_by) values(v_admin) returning id into v_away;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values
    (v_home,v_season,'Appointment Home','ci-appointment-home','approved',now(),v_admin),
    (v_away,v_season,'Appointment Away','ci-appointment-away','approved',now(),v_admin)
  returning id into v_home;

  select id into v_home from public.season_teams where slug='ci-appointment-home';
  select id into v_away from public.season_teams where slug='ci-appointment-away';

  v_start:=(date_trunc('day',now() at time zone 'Europe/London')+interval '2 days'+interval '20 hours') at time zone 'Europe/London';
  v_weekday:=extract(isodow from v_start at time zone 'Europe/London')::integer;

  insert into public.referee_applications(
    user_id,status,experience_summary,qualifications,availability,contact_phone,preferred_location_ids,
    submitted_at,reviewed_at,reviewed_by,review_reason
  ) values (
    v_referee,'approved','Test appointment availability','{}'::text[],
    jsonb_build_array(jsonb_build_object('weekday',v_weekday,'start_time','00:00','end_time','23:59')),
    '+44770090702',array[v_location],now(),now(),v_admin,'CI approved referee'
  ) returning id into v_application;

  insert into public.referee_memberships(user_id,application_id,status,approved_by,status_changed_by,status_reason)
  values(v_referee,v_application,'active',v_admin,v_admin,'CI approved referee membership');

  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,991,1,v_home,v_away,v_location,v_start,'scheduled') returning id into v_fixture;
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,991,2,v_home,v_away,v_location,v_start,'scheduled') returning id into v_second_fixture;
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,991,3,v_home,v_away,v_location,v_start+interval '1 day','scheduled') returning id into v_third_fixture;

  -- Unprivileged player cannot allocate even when the referee and venue are valid.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_unprivileged::text,true);
  v_rejected:=false;
  begin
    perform public.admin_assign_referee_to_fixture(v_fixture,v_referee,'lead');
  exception when others then v_rejected:=true;
  end;
  if not v_rejected then raise exception 'Non-admin user was allowed to appoint a referee'; end if;
  execute 'reset role';

  -- Location admin can appoint an eligible referee to the lead role.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_assignment:=public.admin_assign_referee_to_fixture(v_fixture,v_referee,'lead');
  if v_assignment.cancelled_at is not null or v_assignment.assignment_role<>'lead' then
    raise exception 'Referee appointment was not created as an active lead assignment';
  end if;

  -- The same referee cannot be double-booked at the same kickoff.
  v_rejected:=false;
  begin
    perform public.admin_assign_referee_to_fixture(v_second_fixture,v_referee,'lead');
  exception when others then v_rejected:=true;
  end;
  if not v_rejected then raise exception 'Referee was double-booked at an identical kickoff'; end if;

  -- Declared availability is checked server-side before an appointment is stored.
  update public.referee_applications
  set availability=jsonb_build_array(jsonb_build_object('weekday',case when v_weekday=7 then 1 else v_weekday+1 end,'start_time','00:00','end_time','23:59'))
  where id=v_application;
  v_rejected:=false;
  begin
    perform public.admin_assign_referee_to_fixture(v_third_fixture,v_referee,'lead');
  exception when others then v_rejected:=true;
  end;
  if not v_rejected then raise exception 'Referee without declared availability was appointed'; end if;
  update public.referee_applications
  set availability=jsonb_build_array(jsonb_build_object('weekday',v_weekday,'start_time','00:00','end_time','23:59'))
  where id=v_application;

  select count(*) into v_count from public.admin_list_referee_appointments(v_location,false);
  if v_count<>1 then raise exception 'Admin appointment register did not return the active assignment'; end if;

  perform public.admin_cancel_referee_fixture_assignment(v_assignment.id,'Fixture appointment test cancellation');
  if not exists(select 1 from public.referee_fixture_assignments where id=v_assignment.id and cancelled_at is not null) then
    raise exception 'Appointment cancellation was not retained in history';
  end if;
  if (select count(*) from public.admin_list_referee_appointments(v_location,false))<>0 then
    raise exception 'Cancelled appointment was returned as active';
  end if;
  if (select count(*) from public.admin_list_referee_appointments(v_location,true))<>1 then
    raise exception 'Cancelled appointment history was not visible to administrators';
  end if;
  execute 'reset role';

  -- Only an active referee can access their own appointment list.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_referee::text,true);
  select count(*) into v_count from public.get_my_referee_assignments();
  if v_count<>0 then raise exception 'Cancelled appointment appeared in referee active appointments'; end if;
  execute 'reset role';
end;
$referee_fixture_assignment$;

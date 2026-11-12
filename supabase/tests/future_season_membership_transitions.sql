-- Future-season membership, captaincy and location-scope regression tests.
-- Runs only against the disposable local Supabase database in CI.

do $future_season_membership_transitions$
declare
  v_admin uuid:=gen_random_uuid();
  v_future_captain uuid:=gen_random_uuid();
  v_player uuid:=gen_random_uuid();
  v_player_two uuid:=gen_random_uuid();
  v_opponent_captain uuid:=gen_random_uuid();
  v_second_area_captain uuid:=gen_random_uuid();
  v_conflict_player uuid:=gen_random_uuid();

  v_location uuid;
  v_location_two uuid;
  v_league uuid;
  v_league_two uuid;
  v_previous_season uuid;
  v_future_season uuid;
  v_other_area_season uuid;

  v_old_team uuid;
  v_opponent_team uuid;
  v_future_team uuid;
  v_second_future_team uuid;
  v_conflict_team uuid;
  v_other_area_team uuid;

  v_old_st uuid;
  v_opponent_st uuid;
  v_future_st uuid;
  v_second_future_st uuid;
  v_conflict_st uuid;
  v_other_area_st uuid;

  v_old_captain_membership uuid;
  v_player_old_membership uuid;
  v_player_two_old_membership uuid;
  v_future_captain_membership uuid;
  v_player_future_membership uuid;
  v_fixture_one uuid;
  v_fixture_two uuid;
  v_fixture_cancelled uuid;
  v_count integer;
  v_other_area_membership uuid;
  v_error text;
begin
  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-future-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_future_captain,'authenticated','authenticated','ci-future-captain@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player,'authenticated','authenticated','ci-future-player@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player_two,'authenticated','authenticated','ci-future-player-two@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_opponent_captain,'authenticated','authenticated','ci-future-opponent-captain@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_second_area_captain,'authenticated','authenticated','ci-future-second-area-captain@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_conflict_player,'authenticated','authenticated','ci-future-conflict-player@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_genuine)
  values
    (v_future_captain,'Future Captain','+447700920001','ci-future-captain@openplay.invalid',date '1990-02-01','registered',true),
    (v_player,'Future Member','+447700920002','ci-future-player@openplay.invalid',date '1990-02-02','registered',true),
    (v_player_two,'Other Area Member','+447700920003','ci-future-player-two@openplay.invalid',date '1990-02-03','registered',true),
    (v_opponent_captain,'Opponent Captain','+447700920004','ci-future-opponent-captain@openplay.invalid',date '1990-02-04','registered',true),
    (v_second_area_captain,'Second Area Captain','+447700920005','ci-future-second-area-captain@openplay.invalid',date '1990-02-05','registered',true),
    (v_conflict_player,'Conflict Player','+447700920006','ci-future-conflict-player@openplay.invalid',date '1990-02-06','registered',true);

  insert into public.user_roles(user_id,role,granted_by)
  values(v_admin,'admin',v_admin);

  insert into public.locations(name,slug,town)
  values('Future Membership Test Area','future-membership-test-area','Bideford')
  returning id into v_location;

  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location,'Future Membership Test League','future-membership-test-league','six_a_side',true)
  returning id into v_league;

  insert into public.seasons(league_id,name,season_number,starts_on,ends_on,status,is_public)
  values(v_league,'Future Membership Previous Season',1,date '2026-01-01',date '2026-03-01','active',true)
  returning id into v_previous_season;

  insert into public.seasons(league_id,name,season_number,starts_on,ends_on,status,is_public)
  values(v_league,'Future Membership Upcoming Season',2,date '2026-04-01',date '2026-06-01','registration_open',true)
  returning id into v_future_season;

  insert into public.teams(created_by) values(v_future_captain) returning id into v_old_team;
  insert into public.teams(created_by) values(v_opponent_captain) returning id into v_opponent_team;
  insert into public.teams(created_by) values(v_future_captain) returning id into v_future_team;
  insert into public.teams(created_by) values(v_future_captain) returning id into v_second_future_team;
  insert into public.teams(created_by) values(v_opponent_captain) returning id into v_conflict_team;

  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values
    (v_old_team,v_previous_season,'Previous Season Club','future-old-club','approved',v_admin),
    (v_opponent_team,v_previous_season,'Previous Season Opponent','future-old-opponent','approved',v_admin),
    (v_future_team,v_future_season,'Future Season Club','future-new-club','pending',null),
    (v_second_future_team,v_future_season,'Second Future Club','future-second-club','pending',null),
    (v_conflict_team,v_future_season,'Existing Future Club','future-existing-club','approved',v_admin);

  select id into v_old_st from public.season_teams where team_id=v_old_team and season_id=v_previous_season;
  select id into v_opponent_st from public.season_teams where team_id=v_opponent_team and season_id=v_previous_season;
  select id into v_future_st from public.season_teams where team_id=v_future_team and season_id=v_future_season;
  select id into v_second_future_st from public.season_teams where team_id=v_second_future_team and season_id=v_future_season;
  select id into v_conflict_st from public.season_teams where team_id=v_conflict_team and season_id=v_future_season;

  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values
    (v_old_st,v_future_captain,'active',true),
    (v_old_st,v_player,'active',false),
    (v_old_st,v_player_two,'active',false),
    (v_opponent_st,v_opponent_captain,'active',true),
    (v_conflict_st,v_conflict_player,'active',false);

  select id into v_old_captain_membership from public.team_memberships
  where season_team_id=v_old_st and user_id=v_future_captain;
  select id into v_player_old_membership from public.team_memberships
  where season_team_id=v_old_st and user_id=v_player;
  select id into v_player_two_old_membership from public.team_memberships
  where season_team_id=v_old_st and user_id=v_player_two;

  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_future_st,v_future_captain,'pending',false)
  returning id into v_future_captain_membership;

  -- Administrator approval reserves the applicant as future captain without
  -- granting current-season captain privileges.
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);
  perform public.resolve_team_registration(v_future_st,'approved','Approved for the upcoming season');

  if not exists(
    select 1 from public.team_memberships
    where id=v_future_captain_membership
      and status='pending'
      and is_captain=true
      and future_approved_at is not null
      and activation_after_season_id=v_previous_season
      and future_activated_at is null
  ) then
    raise exception 'Approved future team applicant was not reserved as a future captain';
  end if;

  -- A player can request an upcoming-season club while remaining attached to
  -- the current club. The captain approves it as a future membership.
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  perform public.request_team_membership(v_future_st);

  select id into v_player_future_membership
  from public.team_memberships
  where season_team_id=v_future_st and user_id=v_player;

  perform set_config('request.jwt.claim.sub',v_future_captain::text,true);
  select count(*) into v_count
  from public.get_my_future_captain_requests()
  where membership_id=v_player_future_membership;

  if v_count<>1 then
    raise exception 'Future captain could not see the pending future-season player request';
  end if;

  perform public.resolve_future_team_membership_request(v_player_future_membership,'approved');

  if not exists(
    select 1 from public.team_memberships
    where id=v_player_future_membership
      and status='pending'
      and future_approved_at is not null
      and activation_after_season_id=v_previous_season
      and future_activated_at is null
  ) then
    raise exception 'Future player approval activated before the previous season finished';
  end if;

  -- The same person cannot reserve two captaincies in one area/season.
  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_second_future_st,v_future_captain,'pending',false);

  begin
    perform set_config('request.jwt.claim.sub',v_admin::text,true);
    perform public.resolve_team_registration(v_second_future_st,'approved','Duplicate future captaincy attempt');
    raise exception 'A player was incorrectly approved as captain of two clubs in the same area and season';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'The proposed captain already holds a captaincy in this area for this season%' then
      raise;
    end if;
  end;

  -- An existing active membership in a different club for the same area and
  -- season prevents a second membership request.
  perform set_config('request.jwt.claim.sub',v_conflict_player::text,true);
  begin
    perform public.request_team_membership(v_future_st);
    raise exception 'A player was incorrectly allowed to request a second club in the same area and season';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'You must leave your existing club before joining another club in the same area for this season%' then
      raise;
    end if;
  end;

  -- A different area is independent: an active membership in Area One does
  -- not prevent joining a club in Area Two.
  insert into public.locations(name,slug,town)
  values('Future Membership Other Area','future-membership-other-area','Barnstaple')
  returning id into v_location_two;

  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location_two,'Future Membership Other League','future-membership-other-league','six_a_side',true)
  returning id into v_league_two;

  insert into public.seasons(league_id,name,season_number,starts_on,ends_on,status,is_public)
  values(v_league_two,'Other Area First Season',1,date '2026-04-01',date '2026-06-01','registration_open',true)
  returning id into v_other_area_season;

  insert into public.teams(created_by) values(v_second_area_captain) returning id into v_other_area_team;

  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_other_area_team,v_other_area_season,'Other Area Club','future-other-area-club','approved',v_admin)
  returning id into v_other_area_st;

  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_other_area_st,v_second_area_captain,'active',true);

  perform set_config('request.jwt.claim.sub',v_player_two::text,true);
  perform public.request_team_membership(v_other_area_st);

  perform set_config('request.jwt.claim.sub',v_second_area_captain::text,true);
  select id into v_other_area_membership from public.team_memberships
  where season_team_id=v_other_area_st and user_id=v_player_two;

  perform public.resolve_team_membership_request(v_other_area_membership,'approved');

  if not exists(
    select 1 from public.team_memberships
    where season_team_id=v_other_area_st and user_id=v_player_two and status='active'
  ) then
    raise exception 'A player membership in a different area was incorrectly blocked';
  end if;

  -- A postponed fixture in the previous season delays all future activations,
  -- even after the other final-gameweek result has been confirmed.
  insert into public.fixtures(season_id,home_team_id,away_team_id,gameweek,fixture_number,status,scheduled_at)
  values(v_previous_season,v_old_st,v_opponent_st,14,1,'completed',now()-interval '2 hours')
  returning id into v_fixture_one;

  insert into public.fixtures(season_id,home_team_id,away_team_id,gameweek,fixture_number,status,scheduled_at)
  values(v_previous_season,v_opponent_st,v_old_st,14,2,'postponed',now()-interval '1 hour')
  returning id into v_fixture_two;

  insert into public.fixtures(season_id,home_team_id,away_team_id,gameweek,fixture_number,status,scheduled_at)
  values(v_previous_season,v_old_st,v_opponent_st,14,3,'cancelled',now()-interval '45 minutes')
  returning id into v_fixture_cancelled;

  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by)
  values(v_fixture_one,2,1,now(),v_admin);

  if exists(
    select 1 from public.team_memberships
    where id in (v_future_captain_membership,v_player_future_membership)
      and status='active'
  ) then
    raise exception 'Future memberships activated while a postponed previous-season fixture remained incomplete';
  end if;

  update public.fixtures
  set status='completed',scheduled_at=now()-interval '30 minutes'
  where id=v_fixture_two;

  if exists(
    select 1 from public.team_memberships
    where id in (v_future_captain_membership,v_player_future_membership)
      and status='active'
  ) then
    raise exception 'Future memberships activated before the postponed fixture result was confirmed';
  end if;

  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by)
  values(v_fixture_two,0,0,now(),v_admin);

  if not exists(
    select 1 from public.team_memberships
    where id=v_old_captain_membership and status='left' and voluntarily_left_at is null
  ) then
    raise exception 'Previous-season captain membership was not closed as a season transition';
  end if;

  if not exists(
    select 1 from public.team_memberships
    where id=v_player_old_membership and status='left' and voluntarily_left_at is null
  ) then
    raise exception 'Previous-season player membership was not closed as a season transition';
  end if;

  if not exists(
    select 1 from public.team_memberships
    where id=v_future_captain_membership
      and status='active'
      and is_captain=true
      and future_approved_at is not null
      and future_activated_at is not null
  ) then
    raise exception 'Future captaincy did not activate after all previous-season results were confirmed';
  end if;

  if not exists(
    select 1 from public.team_memberships
    where id=v_player_future_membership
      and status='active'
      and future_approved_at is not null
      and future_activated_at is not null
  ) then
    raise exception 'Future player membership did not activate after all previous-season results were confirmed';
  end if;

  perform set_config('request.jwt.claim.sub',v_future_captain::text,true);
  select count(*) into v_count
  from public.get_captain_dashboard()
  where season_team_id=v_future_st
    and membership_status='active';

  if v_count<>2 then
    raise exception 'Activated future captain could not see the active future squad; expected 2 rows, found %',v_count;
  end if;
end;
$future_season_membership_transitions$;

-- Season completion and next-season recruitment must wait for every
-- postponed/unfinished fixture and every published result.
begin;

do $season_completion_guards$
declare
  v_actor uuid:=gen_random_uuid();
  v_location uuid;
  v_league uuid;
  v_previous uuid;
  v_upcoming uuid;
  v_home uuid;
  v_away uuid;
  v_home_st uuid;
  v_away_st uuid;
  v_fixture uuid;
  v_failed boolean;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values(v_actor,'authenticated','authenticated','ci-season-guard@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.locations(name,slug,town,region,is_active)
  values('Season Completion Guard Test','ci-season-completion-guard','Bideford','Devon',false)
  returning id into v_location;

  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location,'Season Completion Guard League','ci-season-completion-guard','six_a_side',false)
  returning id into v_league;

  insert into public.seasons(league_id,name,season_number,status,is_public,starts_on)
  values(v_league,'Guard Previous Season',1,'active',false,date '2026-01-01')
  returning id into v_previous;

  insert into public.seasons(league_id,name,season_number,status,is_public,starts_on)
  values(v_league,'Guard Upcoming Season',2,'draft',false,date '2027-01-01')
  returning id into v_upcoming;

  insert into public.teams(created_by) values(v_actor) returning id into v_home;
  insert into public.teams(created_by) values(v_actor) returning id into v_away;

  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values
    (v_home,v_previous,'Guard Home','ci-guard-home','approved',now(),v_actor),
    (v_away,v_previous,'Guard Away','ci-guard-away','approved',now(),v_actor);

  select id into v_home_st from public.season_teams where season_id=v_previous and team_id=v_home;
  select id into v_away_st from public.season_teams where season_id=v_previous and team_id=v_away;

  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_previous,14,1,v_home_st,v_away_st,v_location,now()-interval '1 day','postponed')
  returning id into v_fixture;

  -- Neither marking the old season complete nor opening the next season may
  -- bypass a postponed fixture.
  v_failed:=false;
  begin
    update public.seasons set status='completed' where id=v_previous;
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then
    raise exception 'A season with a postponed fixture was incorrectly marked completed';
  end if;

  v_failed:=false;
  begin
    update public.seasons
    set status='registration_open',recruitment_status='open',
        recruitment_opened_at=now(),recruitment_opened_by=v_actor
    where id=v_upcoming;
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then
    raise exception 'Next-season recruitment opened while the previous season had a postponed fixture';
  end if;

  -- Once the postponed fixture is actually completed and has a published
  -- result, both guarded transitions may proceed.
  update public.fixtures set status='completed' where id=v_fixture;
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by)
  values(v_fixture,2,1,now(),v_actor);

  update public.seasons set status='completed' where id=v_previous;
  update public.seasons
  set status='registration_open',recruitment_status='open',
      recruitment_opened_at=now(),recruitment_opened_by=v_actor
  where id=v_upcoming;

  if (select status::text from public.seasons where id=v_previous)<>'completed'
     or (select recruitment_status from public.seasons where id=v_upcoming)<>'open' then
    raise exception 'Season completion/recruitment transitions did not succeed after fixture completion';
  end if;
end;
$season_completion_guards$;

rollback;

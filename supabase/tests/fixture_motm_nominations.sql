-- Captain MOTM nomination eligibility, lock, correction, stats and public club leaders.
-- Runs only against the disposable local Supabase database created by CI.
do $fixture_motm$
declare
  v_admin constant uuid:='96000000-0000-4000-8000-000000000001';
  v_home_captain constant uuid:='96000000-0000-4000-8000-000000000002';
  v_home_teammate constant uuid:='96000000-0000-4000-8000-000000000003';
  v_home_sub constant uuid:='96000000-0000-4000-8000-000000000004';
  v_away_captain constant uuid:='96000000-0000-4000-8000-000000000005';
  v_away_teammate constant uuid:='96000000-0000-4000-8000-000000000006';
  v_location constant uuid:='96000000-0000-4000-8000-000000000010';
  v_league constant uuid:='96000000-0000-4000-8000-000000000020';
  v_season constant uuid:='96000000-0000-4000-8000-000000000030';
  v_home_team constant uuid:='96000000-0000-4000-8000-000000000040';
  v_away_team constant uuid:='96000000-0000-4000-8000-000000000041';
  v_home_season_team constant uuid:='96000000-0000-4000-8000-000000000050';
  v_away_season_team constant uuid:='96000000-0000-4000-8000-000000000051';
  v_fixture constant uuid:='96000000-0000-4000-8000-000000000060';
  v_late_fixture constant uuid:='96000000-0000-4000-8000-000000000061';
  v_home_sheet uuid;
  v_away_sheet uuid;
  v_late_home_sheet uuid;
  v_late_away_sheet uuid;
  v_home_captain_identity uuid;
  v_home_teammate_identity uuid;
  v_home_sub_identity uuid;
  v_away_captain_identity uuid;
  v_nomination_id uuid;
  v_count integer;
  v_denied boolean;
  v_stats jsonb;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-motm-admin@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_home_captain,'authenticated','authenticated','ci-motm-home-captain@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_home_teammate,'authenticated','authenticated','ci-motm-home-player@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_home_sub,'authenticated','authenticated','ci-motm-home-sub@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_away_captain,'authenticated','authenticated','ci-motm-away-captain@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_away_teammate,'authenticated','authenticated','ci-motm-away-player@openplay.invalid','','{}'::jsonb,now(),now());

  insert into public.locations(id,name,slug,town,region,is_active)
  values(v_location,'MOTM Test Location','ci-motm-location','Bideford','Devon',false);
  insert into public.user_roles(user_id,role,granted_by)
  values(v_admin,'admin',v_admin);
  insert into public.leagues(id,location_id,name,slug,format,is_published)
  values(v_league,v_location,'MOTM Test League','ci-motm-league','six_a_side',true);
  insert into public.seasons(id,league_id,name,season_number,is_public,status)
  values(v_season,v_league,'MOTM Test Season',1,true,'active');
  insert into public.teams(id,created_by)
  values(v_home_team,v_home_captain),(v_away_team,v_away_captain);
  insert into public.season_teams(id,team_id,season_id,name,slug,registration_status)
  values
    (v_home_season_team,v_home_team,v_season,'MOTM Home','ci-motm-home','approved'),
    (v_away_season_team,v_away_team,v_season,'MOTM Away','ci-motm-away','approved');

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_genuine,is_banned)
  values
    (v_home_captain,'MOTM Home Captain','+447700961002','ci-motm-home-captain@openplay.invalid',date '1990-01-01','registered',true,false),
    (v_home_teammate,'MOTM Home Teammate','+447700961003','ci-motm-home-player@openplay.invalid',date '1990-01-02','registered',true,false),
    (v_home_sub,'MOTM Home Substitute','+447700961004','ci-motm-home-sub@openplay.invalid',date '1990-01-03','registered',true,false),
    (v_away_captain,'MOTM Away Captain','+447700961005','ci-motm-away-captain@openplay.invalid',date '1990-01-04','registered',true,false),
    (v_away_teammate,'MOTM Away Teammate','+447700961006','ci-motm-away-player@openplay.invalid',date '1990-01-05','registered',true,false);

  select competition_player_id into v_home_captain_identity from public.players where user_id=v_home_captain;
  select competition_player_id into v_home_teammate_identity from public.players where user_id=v_home_teammate;
  select competition_player_id into v_home_sub_identity from public.players where user_id=v_home_sub;
  select competition_player_id into v_away_captain_identity from public.players where user_id=v_away_captain;

  insert into public.team_memberships(id,season_team_id,user_id,status,is_captain)
  values
    ('96000000-0000-4000-8000-000000000070',v_home_season_team,v_home_captain,'active',true),
    ('96000000-0000-4000-8000-000000000071',v_home_season_team,v_home_teammate,'active',false),
    ('96000000-0000-4000-8000-000000000072',v_home_season_team,v_home_sub,'active',false),
    ('96000000-0000-4000-8000-000000000073',v_away_season_team,v_away_captain,'active',true),
    ('96000000-0000-4000-8000-000000000074',v_away_season_team,v_away_teammate,'active',false);

  insert into public.fixtures(id,season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values
    (v_fixture,v_season,1,1,v_home_season_team,v_away_season_team,v_location,now()+interval '2 hours','scheduled'),
    (v_late_fixture,v_season,2,1,v_home_season_team,v_away_season_team,v_location,now()+interval '2 hours','scheduled');

  -- Protected team-sheet triggers require the acting captain's JWT context,
  -- including during isolated fixture setup performed by the database owner.
  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_home_captain)::text,true);

  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked,submitted_at)
  values(v_fixture,v_home_season_team,v_home_captain,true,now())
  returning id into v_home_sheet;

  perform set_config('request.jwt.claim.sub',v_away_captain::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_away_captain)::text,true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked,submitted_at)
  values(v_fixture,v_away_season_team,v_away_captain,true,now())
  returning id into v_away_sheet;

  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_home_captain)::text,true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked,submitted_at)
  values(v_late_fixture,v_home_season_team,v_home_captain,true,now())
  returning id into v_late_home_sheet;

  perform set_config('request.jwt.claim.sub',v_away_captain::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_away_captain)::text,true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked,submitted_at)
  values(v_late_fixture,v_away_season_team,v_away_captain,true,now())
  returning id into v_late_away_sheet;

  insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role)
  values
    (v_home_sheet,v_home_captain,'starter'),
    (v_home_sheet,v_home_teammate,'starter'),
    (v_home_sheet,v_home_sub,'substitute'),
    (v_away_sheet,v_away_captain,'starter'),
    (v_away_sheet,v_away_teammate,'starter'),
    (v_late_home_sheet,v_home_captain,'starter'),
    (v_late_home_sheet,v_home_teammate,'starter'),
    (v_late_away_sheet,v_away_captain,'starter'),
    (v_late_away_sheet,v_away_teammate,'starter');

  -- Team sheets must be submitted while the fixture is still scheduled and in the future.
  -- Then close both fixtures and attach their confirmed results for the MOTM workflow.
  update public.fixtures set status='completed' where id in (v_fixture,v_late_fixture);
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by)
  values(v_fixture,1,0,now(),v_admin),(v_late_fixture,0,0,now(),v_admin);

  -- Mirror the official result workflow: starters are confirmed appearances;
  -- the named substitute remains unplayed and must not be eligible.
  update public.fixture_team_sheet_players tsp
  set did_appear=true
  where tsp.team_sheet_id in (v_home_sheet,v_away_sheet,v_late_home_sheet,v_late_away_sheet)
    and tsp.role='starter';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_home_captain)::text,true);

  select count(*) into v_count
  from public.get_captain_motm_nomination_options() options
  where options.fixture_id=v_fixture
    and options.can_nominate is true
    and jsonb_array_length(options.eligible_players)=2;
  if v_count<>1 then
    raise exception 'Captain nomination options must include only the two actual home-team appearances';
  end if;

  v_nomination_id:=public.submit_fixture_motm_nomination(v_fixture,v_home_captain_identity);
  if v_nomination_id is null then raise exception 'Captain could not nominate themselves despite being an eligible actual appearance'; end if;

  select count(*) into v_count
  from public.get_captain_motm_nomination_options() options
  where options.fixture_id=v_fixture and options.can_nominate is false
    and options.nomination_id=v_nomination_id;
  if v_count<>1 then raise exception 'A submitted team nomination must be locked'; end if;

  v_denied:=false;
  begin
    perform public.submit_fixture_motm_nomination(v_fixture,v_home_teammate_identity);
  exception when others then
    v_denied:=sqlerrm like '%already submitted%';
  end;
  if not v_denied then raise exception 'A team submitted more than one MOTM nomination for the same fixture'; end if;

  v_denied:=false;
  begin
    perform public.submit_fixture_motm_nomination(v_fixture,v_home_sub_identity);
  exception when others then
    v_denied:=sqlerrm like '%actually appeared%';
  end;
  if not v_denied then raise exception 'A substitute who did not appear was eligible for MOTM'; end if;

  v_denied:=false;
  begin
    perform public.submit_fixture_motm_nomination(v_fixture,v_away_captain_identity);
  exception when others then
    v_denied:=sqlerrm like '%your team’s locked sheet%';
  end;
  if not v_denied then raise exception 'A captain nominated a player from the opposing team'; end if;

  v_denied:=false;
  begin
    perform public.submit_fixture_motm_nomination(v_late_fixture,v_home_captain_identity);
  exception when others then
    v_denied:=sqlerrm like '%24 hours%';
  end;
  if not v_denied then raise exception 'A captain submitted an MOTM nomination after the 24-hour deadline'; end if;

  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_admin)::text,true);

  select count(*) into v_count
  from public.admin_list_fixture_motm_nominations(v_location) rows
  where rows.nomination_id=v_nomination_id
    and rows.season_team_id=v_home_season_team;
  if v_count<>1 then raise exception 'Location administrator queue did not return the submitted MOTM nomination'; end if;

  v_denied:=false;
  begin
    perform public.admin_correct_fixture_motm_nomination(v_nomination_id,v_away_captain_identity,'Invalid opposing player correction');
  exception when others then
    v_denied:=sqlerrm like '%nominated team’s locked sheet%';
  end;
  if not v_denied then raise exception 'Admin correction accepted a player from the opposing team'; end if;

  perform public.admin_correct_fixture_motm_nomination(
    v_nomination_id,v_home_teammate_identity,'Corrected after referee review'
  );
  if not exists(
    select 1 from public.fixture_motm_nominations
    where id=v_nomination_id
      and competition_player_id=v_home_teammate_identity
      and corrected_by=v_admin
      and correction_reason='Corrected after referee review'
  ) then raise exception 'Admin correction did not preserve its actor and reason'; end if;

  select count(*) into v_count from public.audit_log
  where actor_user_id=v_admin and action='fixture.motm.corrected'
    and entity_type='fixture_motm_nomination' and entity_id=v_nomination_id::text;
  if v_count<>1 then raise exception 'MOTM admin correction was not audited'; end if;

  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_home_teammate::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_home_teammate)::text,true);
  v_stats:=public.get_my_player_motm_awards(v_season);
  if (v_stats->>'season_awards')::integer<>1 or (v_stats->>'career_awards')::integer<>1 then
    raise exception 'Player Hub MOTM season and career totals did not include the corrected nomination';
  end if;
  execute 'reset role';

  select count(*) into v_count
  from public.get_public_season_club_leaders(v_season) leaders
  where leaders.competition_player_id=v_home_teammate_identity
    and leaders.season_team_id=v_home_season_team
    and leaders.motm_awards=1
    and leaders.appearances=2;
  if v_count<>1 then raise exception 'Public Club Leaders did not reflect the corrected MOTM and appearance totals'; end if;
end;
$fixture_motm$;

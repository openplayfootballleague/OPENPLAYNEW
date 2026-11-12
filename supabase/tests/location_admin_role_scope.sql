-- Disposable role/RLS integration test. The local CI database is isolated.
-- The location admin is assigned to Location A only; Location B must stay private.
do $role_matrix$
declare
  v_count integer;
  v_setup jsonb;
  v_denied boolean;
  v_cross_location_sheet uuid;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values
   ('00000000-0000-4000-8000-000000000001','authenticated','authenticated','ci-player-a@openplay.invalid','','{}'::jsonb,now(),now()),
   ('00000000-0000-4000-8000-000000000002','authenticated','authenticated','ci-captain-a@openplay.invalid','','{}'::jsonb,now(),now()),
   ('00000000-0000-4000-8000-000000000003','authenticated','authenticated','ci-player-b@openplay.invalid','','{}'::jsonb,now(),now()),
   ('00000000-0000-4000-8000-000000000004','authenticated','authenticated','ci-location-admin@openplay.invalid','','{}'::jsonb,now(),now()),
   ('00000000-0000-4000-8000-000000000005','authenticated','authenticated','ci-global-admin@openplay.invalid','','{}'::jsonb,now(),now()),
   ('00000000-0000-4000-8000-000000000006','authenticated','authenticated','ci-player-c@openplay.invalid','','{}'::jsonb,now(),now()),
   ('00000000-0000-4000-8000-000000000007','authenticated','authenticated','ci-finance-admin@openplay.invalid','','{}'::jsonb,now(),now()),
   ('00000000-0000-4000-8000-000000000008','authenticated','authenticated','ci-super-admin@openplay.invalid','','{}'::jsonb,now(),now()),
   ('00000000-0000-4000-8000-000000000009','authenticated','authenticated','ci-unassigned-league-admin@openplay.invalid','','{}'::jsonb,now(),now());

  insert into public.locations (id,name,slug,town,region,is_active)
  values
   ('00000000-0000-4000-8000-000000000010','CI Location A','ci-location-a','Bideford','Devon',true),
   ('00000000-0000-4000-8000-000000000011','CI Location B','ci-location-b','CI Test','CI',false),
   ('00000000-0000-4000-8000-000000000012','CI Location C','ci-location-c','Bideford','Devon',false);

  insert into public.user_roles (user_id,role,granted_by)
  values
   ('00000000-0000-4000-8000-000000000004','league_admin','00000000-0000-4000-8000-000000000005'),
   ('00000000-0000-4000-8000-000000000005','admin','00000000-0000-4000-8000-000000000005'),
   ('00000000-0000-4000-8000-000000000007','finance_admin','00000000-0000-4000-8000-000000000005'),
   ('00000000-0000-4000-8000-000000000008','super_admin','00000000-0000-4000-8000-000000000005');

  insert into public.location_admin_assignments (user_id,location_id,assigned_by)
  values ('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000005');

  insert into public.leagues (id,location_id,name,slug,is_published)
  values
   ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010','CI League A','ci-league-a',false),
   ('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000011','CI League B','ci-league-b',false);

  insert into public.seasons (id,league_id,name,season_number,is_public,status)
  values
   ('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000020','CI Season A',1,false,'registration_open'),
   ('00000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000021','CI Season B',1,false,'registration_open');

  insert into public.teams (id,created_by)
  values
   ('00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000001'),
   ('00000000-0000-4000-8000-000000000041','00000000-0000-4000-8000-000000000001'),
   ('00000000-0000-4000-8000-000000000042','00000000-0000-4000-8000-000000000003'),
   ('00000000-0000-4000-8000-000000000043','00000000-0000-4000-8000-000000000003');

  insert into public.season_teams (id,team_id,season_id,name,slug,registration_status)
  values
   ('00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000030','CI A Team One','ci-a-team-one','approved'),
   ('00000000-0000-4000-8000-000000000051','00000000-0000-4000-8000-000000000041','00000000-0000-4000-8000-000000000030','CI A Team Two','ci-a-team-two','approved'),
   ('00000000-0000-4000-8000-000000000052','00000000-0000-4000-8000-000000000042','00000000-0000-4000-8000-000000000031','CI B Team One','ci-b-team-one','approved'),
   ('00000000-0000-4000-8000-000000000053','00000000-0000-4000-8000-000000000043','00000000-0000-4000-8000-000000000031','CI B Team Two','ci-b-team-two','approved');

  insert into public.players (user_id,full_name,phone,email,date_of_birth,registration_status)
  values
   ('00000000-0000-4000-8000-000000000001','CI Player A','+447700900001','ci-player-a@openplay.invalid',date '1990-01-01','registered'),
   ('00000000-0000-4000-8000-000000000002','CI Captain A','+447700900002','ci-captain-a@openplay.invalid',date '1990-01-02','registered'),
   ('00000000-0000-4000-8000-000000000003','CI Player B','+447700900003','ci-player-b@openplay.invalid',date '1990-01-03','registered'),
   ('00000000-0000-4000-8000-000000000006','CI Player C','+447700900006','ci-player-c@openplay.invalid',date '1990-01-06','registered');

  insert into public.team_memberships (id,season_team_id,user_id,status,is_captain)
  values
   ('00000000-0000-4000-8000-000000000060','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000002','active',true),
   ('00000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000001','active',false),
   ('00000000-0000-4000-8000-000000000062','00000000-0000-4000-8000-000000000052','00000000-0000-4000-8000-000000000003','active',true),
   ('00000000-0000-4000-8000-000000000063','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000006','pending',false),
   ('00000000-0000-4000-8000-000000000064','00000000-0000-4000-8000-000000000052','00000000-0000-4000-8000-000000000001','pending',false),
   ('00000000-0000-4000-8000-000000000065','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000003','pending',false);

  insert into public.fixtures (id,season_id,gameweek,fixture_number,home_team_id,away_team_id)
  values
   ('00000000-0000-4000-8000-000000000070','00000000-0000-4000-8000-000000000030',1,1,'00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000051'),
   ('00000000-0000-4000-8000-000000000071','00000000-0000-4000-8000-000000000031',1,1,'00000000-0000-4000-8000-000000000052','00000000-0000-4000-8000-000000000053');

  -- Seed the cross-location sheet as its real active captain. A platform
  -- administrator must not create a captain's matchday sheet.
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000003"}',true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked,submitted_at)
  values('00000000-0000-4000-8000-000000000071','00000000-0000-4000-8000-000000000052',
    '00000000-0000-4000-8000-000000000003',true,now())
  returning id into v_cross_location_sheet;

  -- A global administrator without captaincy cannot create a team sheet directly.
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005"}',true);
  v_denied := false;
  begin
    insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked,submitted_at)
    values('00000000-0000-4000-8000-000000000071','00000000-0000-4000-8000-000000000052',
      '00000000-0000-4000-8000-000000000005',true,now());
  exception when others then
    if sqlerrm = 'Administrators must amend submitted sheets through admin_amend_team_sheet' then
      v_denied := true;
    else
      raise;
    end if;
  end;
  if not v_denied then raise exception 'Global admin unexpectedly created a captain team sheet'; end if;

  -- Ordinary player: own profile/player record and own team's fixture only.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000001"}',true);
  if current_user <> 'authenticated' then raise exception 'Could not assume authenticated role'; end if;
  if public.has_global_admin_role() or public.has_platform_role() then raise exception 'Ordinary player unexpectedly has an admin role'; end if;
  select count(*) into v_count from public.profiles where id='00000000-0000-4000-8000-000000000001';
  if v_count <> 1 then raise exception 'Player cannot read their own profile'; end if;
  select count(*) into v_count from public.profiles where id='00000000-0000-4000-8000-000000000003';
  if v_count <> 0 then raise exception 'Player can read another profile'; end if;
  select count(*) into v_count from public.players where user_id='00000000-0000-4000-8000-000000000001';
  if v_count <> 1 then raise exception 'Player cannot read their own player record'; end if;
  select count(*) into v_count from public.players where user_id='00000000-0000-4000-8000-000000000003';
  if v_count <> 0 then raise exception 'Player can read another player record'; end if;
  select count(*) into v_count from public.fixtures where id='00000000-0000-4000-8000-000000000070';
  if v_count <> 1 then raise exception 'Player cannot see their active team fixture'; end if;
  select count(*) into v_count from public.fixtures where id='00000000-0000-4000-8000-000000000071';
  if v_count <> 0 then raise exception 'Player can see an unrelated location fixture'; end if;
  v_denied := false;
  begin
    perform public.get_admin_competition_setup();
  exception when others then
    if sqlerrm = 'Administrator permission required' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Ordinary player unexpectedly accessed admin setup'; end if;
  execute 'reset role';

  -- Captain: their own team's roster and fixtures only.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000002"}',true);
  if not public.is_active_team_captain('00000000-0000-4000-8000-000000000050') then raise exception 'Captain membership was not recognised'; end if;
  if public.has_global_admin_role() or public.has_platform_role() then raise exception 'Captain unexpectedly has an admin role'; end if;
  select count(*) into v_count from public.team_memberships where season_team_id='00000000-0000-4000-8000-000000000050' and status='active';
  if v_count <> 2 then raise exception 'Captain cannot see their own active team roster'; end if;
  perform public.resolve_team_membership_request('00000000-0000-4000-8000-000000000063','approved');
  select count(*) into v_count from public.team_memberships where id='00000000-0000-4000-8000-000000000063' and status='active';
  if v_count <> 1 then raise exception 'Captain could not approve a pending request for their own team'; end if;

  perform public.resolve_team_membership_request('00000000-0000-4000-8000-000000000065','rejected');
  select count(*) into v_count from public.team_memberships where id='00000000-0000-4000-8000-000000000065' and status='rejected';
  if v_count <> 1 then raise exception 'Captain could not reject a pending request for their own team'; end if;

  if auth.uid() <> '00000000-0000-4000-8000-000000000002'::uuid then
    raise exception 'Captain JWT subject changed before cross-team authorization test';
  end if;
  if public.is_active_team_captain('00000000-0000-4000-8000-000000000052') then
    raise exception 'Captain A was incorrectly recognized as captain of Team B';
  end if;
  if public.can_administer_location('00000000-0000-4000-8000-000000000011') then
    raise exception 'Captain A unexpectedly has administration access to Location B';
  end if;

  v_denied := false;
  begin
    perform public.resolve_team_membership_request('00000000-0000-4000-8000-000000000064','approved');
  exception when others then
    if sqlerrm = 'Captain or assigned location administrator permission required' then
      v_denied := true;
    else
      raise;
    end if;
  end;
  if not v_denied then raise exception 'Captain unexpectedly resolved a different team request'; end if;
  -- Captain A cannot read Team B's request directly; inspect its unchanged state
  -- as the database test owner, then restore the captain JWT for the remaining checks.
  execute 'reset role';
  select count(*) into v_count from public.team_memberships where id='00000000-0000-4000-8000-000000000064' and status='pending';
  if v_count <> 1 then raise exception 'Cross-team request changed despite authorization denial'; end if;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000002"}',true);

  select count(*) into v_count from public.team_memberships where season_team_id='00000000-0000-4000-8000-000000000052';
  if v_count <> 0 then raise exception 'Captain can see another location roster'; end if;
  select count(*) into v_count from public.fixtures where id='00000000-0000-4000-8000-000000000070';
  if v_count <> 1 then raise exception 'Captain cannot see their own team fixture'; end if;
  select count(*) into v_count from public.fixtures where id='00000000-0000-4000-8000-000000000071';
  if v_count <> 0 then raise exception 'Captain can see another location fixture'; end if;
  v_denied := false;
  begin
    perform public.get_admin_competition_setup();
  exception when others then
    if sqlerrm = 'Administrator permission required' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Captain unexpectedly accessed admin setup'; end if;
  execute 'reset role';

  -- Location admin: direct reads remain scoped to assigned locations; private identity data and cross-location rows stay hidden.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000004"}',true);
  if current_user <> 'authenticated' then raise exception 'Could not assume authenticated role for location admin'; end if;
  if not public.has_platform_role() then raise exception 'Location admin role was not recognised'; end if;
  if public.has_global_admin_role() then raise exception 'Location admin was incorrectly classified as global'; end if;
  select count(*) into v_count from public.leagues where id='00000000-0000-4000-8000-000000000020';
  if v_count <> 1 then raise exception 'Location admin cannot directly read its assigned private league'; end if;
  select count(*) into v_count from public.leagues where id='00000000-0000-4000-8000-000000000021';
  if v_count <> 0 then raise exception 'Location admin can directly read another location private league'; end if;
  select count(*) into v_count from public.profiles where id in ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000003');
  if v_count <> 0 then raise exception 'Location admin can directly read player profiles'; end if;
  select count(*) into v_count from public.players where user_id in ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000003');
  if v_count <> 0 then raise exception 'Location admin can directly read player identity records'; end if;
  select count(*) into v_count from public.user_roles where user_id='00000000-0000-4000-8000-000000000005';
  if v_count <> 0 then raise exception 'Location admin can directly read another administrator role'; end if;
  select count(*) into v_count from public.team_memberships where season_team_id='00000000-0000-4000-8000-000000000050';
  -- The assigned team has four seeded memberships (two active and two pending).
  if v_count <> 4 then raise exception 'Location admin cannot read all memberships within its assigned location'; end if;
  select count(*) into v_count from public.team_memberships where season_team_id='00000000-0000-4000-8000-000000000052';
  if v_count <> 0 then raise exception 'Location admin can directly read memberships outside its assigned location'; end if;
  v_setup := public.get_admin_competition_setup();
  if jsonb_array_length(v_setup->'locations') <> 1 or v_setup->'locations'->0->>'id' <> '00000000-0000-4000-8000-000000000010' then
    raise exception 'Scoped admin setup did not return only the assigned location';
  end if;
  if jsonb_array_length(v_setup->'leagues') <> 1 or v_setup->'leagues'->0->>'id' <> '00000000-0000-4000-8000-000000000020' then
    raise exception 'Scoped admin setup did not return only the assigned league';
  end if;
  if exists (
    select 1 from jsonb_array_elements(v_setup->'registered_players') item
    where item->>'user_id' = '00000000-0000-4000-8000-000000000003'
  ) then raise exception 'Scoped admin setup leaked a player from another location'; end if;
  perform public.admin_create_league('00000000-0000-4000-8000-000000000010','CI Assigned League','six_a_side',null);
  v_denied := false;
  begin
    perform public.admin_create_league('00000000-0000-4000-8000-000000000011','CI Unassigned League','six_a_side',null);
  exception when others then
    if sqlerrm = 'You are not assigned to this location' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin created a league outside their assignment'; end if;
  v_denied := false;
  begin
    perform public.admin_list_location_assignments(null);
  exception when others then
    if sqlerrm = 'Global administrator permission required' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin accessed global assignment administration'; end if;
  v_denied := false;
  begin
    perform public.admin_set_location_assignment('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000011',true);
  exception when others then
    if sqlerrm = 'Global administrator permission required' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin changed a global location assignment'; end if;
  v_denied := false;
  begin
    perform public.resolve_team_membership_request('00000000-0000-4000-8000-000000000064','approved');
  exception when others then
    if sqlerrm = 'Captain or assigned location administrator permission required' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin approved a membership request outside their assignment'; end if;
  v_denied := false;
  begin
    perform public.admin_set_location_active('00000000-0000-4000-8000-000000000011',false,'CI location admin scope test');
  exception when others then
    if sqlerrm = 'Global administrator permission required' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin changed a platform-wide location activation state'; end if;
  v_denied := false;
  begin
    perform public.admin_set_player_fixture_fee('00000000-0000-4000-8000-000000000031',500,1,'CI location admin finance scope test');
  exception when others then
    if sqlerrm = 'Finance access required' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin changed finance settings without finance permission'; end if;

  -- Every newly replaced contextual/history RPC must enforce the selected location.
  v_denied := false;
  begin
    perform * from public.get_admin_team_sheets_contextual('00000000-0000-4000-8000-000000000011',null,null);
  exception when others then
    if sqlerrm = 'You are not assigned to this location' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin read team sheets outside their assignment'; end if;

  v_denied := false;
  begin
    perform * from public.admin_get_transfer_requests_contextual('all','00000000-0000-4000-8000-000000000011',null,null);
  exception when others then
    if sqlerrm = 'You are not assigned to this location' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin read transfer requests outside their assignment'; end if;

  v_denied := false;
  begin
    perform * from public.get_admin_contextual_fixtures('00000000-0000-4000-8000-000000000011',null,null);
  exception when others then
    if sqlerrm = 'You are not assigned to this location' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin read fixtures outside their assignment'; end if;

  v_denied := false;
  begin
    perform public.get_admin_season_statistics('00000000-0000-4000-8000-000000000031');
  exception when others then
    if sqlerrm = 'You are not assigned to this location' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin read season statistics outside their assignment'; end if;

  v_denied := false;
  begin
    perform public.get_admin_fixture_scorer_options('00000000-0000-4000-8000-000000000071');
  exception when others then
    if sqlerrm = 'You are not assigned to this location' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin read scorer options outside their assignment'; end if;

  v_denied := false;
  begin
    perform public.admin_record_fixture_result_with_appearances(
      '00000000-0000-4000-8000-000000000071',0,0,'{}'::uuid[],'{}'::uuid[],'{}'::uuid[],'{}'::uuid[],
      'Cross-location authorization test'
    );
  exception when others then
    if sqlerrm = 'You are not assigned to this location' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin entered a result outside their assignment'; end if;

  v_denied := false;
  begin
    perform public.admin_amend_team_sheet(
      v_cross_location_sheet,
      '{}'::uuid[],'{}'::uuid[],null,'Cross-location authorization test'
    );
  exception when others then
    if sqlerrm = 'You are not assigned to this location' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin amended a team sheet outside their assignment'; end if;
  execute 'reset role';

  -- Finance admin: may manage fees without a platform-admin or location assignment.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000007',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000007"}',true);
  if not public.has_finance_access() then raise exception 'Finance admin does not have finance access'; end if;
  if public.has_platform_role() or public.has_global_admin_role() then raise exception 'Finance admin was incorrectly granted platform-admin access'; end if;
  perform public.admin_set_player_fixture_fee('00000000-0000-4000-8000-000000000031',500,1,'CI finance role scope test');
  execute 'reset role';
  select count(*) into v_count
  from public.season_fee_configs
  where season_id='00000000-0000-4000-8000-000000000031'
    and player_fee_pence=500
    and effective_from_gameweek=1
    and changed_by='00000000-0000-4000-8000-000000000007';
  if v_count <> 1 then raise exception 'Finance admin could not manage fees without a location assignment'; end if;

  -- Global admin: global visibility and assignment administration remain available.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005"}',true);
  if not public.has_global_admin_role() then raise exception 'Global admin role was not recognised'; end if;
  select count(*) into v_count from public.profiles where id in (
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000003',
    '00000000-0000-4000-8000-000000000006'
  );
  if v_count <> 4 then raise exception 'Global admin cannot read all player profiles'; end if;
  select count(*) into v_count from public.leagues where id in ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000021');
  if v_count <> 2 then raise exception 'Global admin cannot read both private leagues'; end if;

  -- Global administrators may amend a sheet only after the fixture is completed.
  v_denied := false;
  begin
    perform public.admin_amend_team_sheet(
      v_cross_location_sheet,
      '{}'::uuid[],'{}'::uuid[],null,'CI pre-match amendment rejection'
    );
  exception when others then
    if sqlerrm = 'A team sheet can be amended only after its fixture is marked completed' then
      v_denied := true;
    else
      raise;
    end if;
  end;
  if not v_denied then raise exception 'Global admin amended a sheet before its fixture was completed'; end if;

  perform public.admin_set_location_assignment('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000011',true);
  select count(*) into v_count from public.admin_list_location_assignments(null);
  if v_count <> 2 then raise exception 'Global admin cannot manage and list location assignments'; end if;
  v_setup := public.get_admin_competition_setup();
  if jsonb_array_length(v_setup->'locations') <> 3 then raise exception 'Global admin setup did not return all three seeded locations'; end if;
  if not exists (
    select 1 from jsonb_array_elements(v_setup->'locations') item
    where item->>'id' = '00000000-0000-4000-8000-000000000010'
  ) or not exists (
    select 1 from jsonb_array_elements(v_setup->'locations') item
    where item->>'id' = '00000000-0000-4000-8000-000000000011'
  ) or not exists (
    select 1 from jsonb_array_elements(v_setup->'locations') item
    where item->>'id' = '00000000-0000-4000-8000-000000000012'
  ) then
    raise exception 'Global admin setup omitted one or more seeded locations';
  end if;

  -- Repeating an existing grant is a no-op and must not create duplicate audit entries.
  perform public.admin_set_location_assignment('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000011',true);
  execute 'reset role';
  select count(*) into v_count from public.audit_log
  where actor_user_id='00000000-0000-4000-8000-000000000005'
    and action='location_admin.assignment_granted'
    and entity_type='location_admin_assignment';
  if v_count <> 1 then raise exception 'Location assignment grant must create exactly one audit event'; end if;

  -- A stale assignment must remain revocable after the league_admin role is removed.
  delete from public.user_roles
  where user_id='00000000-0000-4000-8000-000000000004' and role='league_admin';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005"}',true);
  perform public.admin_set_location_assignment('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000011',false);
  execute 'reset role';
  select count(*) into v_count from public.location_admin_assignments
  where user_id='00000000-0000-4000-8000-000000000004'
    and location_id='00000000-0000-4000-8000-000000000011';
  if v_count <> 0 then raise exception 'Stale location assignment could not be revoked'; end if;
  select count(*) into v_count from public.audit_log
  where actor_user_id='00000000-0000-4000-8000-000000000005'
    and action='location_admin.assignment_revoked'
    and entity_type='location_admin_assignment';
  if v_count <> 1 then raise exception 'Location assignment revocation must create exactly one audit event'; end if;

  -- Global admins can grant/revoke only the location-admin role. A role grant
  -- gives no location access until an explicit assignment is made.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005"}',true);
  select count(*) into v_count
  from public.admin_search_league_admin_role_candidates('ci-player-c')
  where user_id='00000000-0000-4000-8000-000000000006' and has_league_admin is false;
  if v_count<>1 then raise exception 'Global admin role search did not return an eligible unprivileged account'; end if;
  select count(*) into v_count
  from public.admin_search_league_admin_role_candidates('ci-finance-admin');
  if v_count<>0 then raise exception 'Finance administrator account must not be eligible for league-admin role changes'; end if;
  perform public.admin_set_league_admin_role(
    '00000000-0000-4000-8000-000000000006',true,'Approved location administrator appointment'
  );
  if not exists(select 1 from public.user_roles where user_id='00000000-0000-4000-8000-000000000006' and role='league_admin') then
    raise exception 'Global admin could not grant the league_admin role';
  end if;
  perform public.admin_set_location_assignment(
    '00000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000010',true
  );
  perform public.admin_set_league_admin_role(
    '00000000-0000-4000-8000-000000000006',false,'Administrator access no longer required'
  );
  execute 'reset role';
  if exists(select 1 from public.user_roles where user_id='00000000-0000-4000-8000-000000000006' and role='league_admin')
     or exists(select 1 from public.location_admin_assignments where user_id='00000000-0000-4000-8000-000000000006') then
    raise exception 'Revoking league_admin must also remove every location assignment';
  end if;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005"}',true);
  v_denied:=false;
  begin
    perform public.admin_set_location_assignment(
      '00000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000010',true
    );
  exception when others then
    v_denied:=sqlerrm like '%must have the league_admin role%';
  end;
  execute 'reset role';
  if not v_denied then raise exception 'A user without league_admin role received a location assignment'; end if;
  select count(*) into v_count from public.audit_log
  where actor_user_id='00000000-0000-4000-8000-000000000005'
    and action='role.league_admin.granted' and entity_type='user_role';
  if v_count<>1 then raise exception 'League administrator role grant was not audited'; end if;
  select count(*) into v_count from public.audit_log
  where actor_user_id='00000000-0000-4000-8000-000000000005'
    and action='role.league_admin.revoked' and entity_type='user_role';
  if v_count<>1 then raise exception 'League administrator role revocation was not audited'; end if;

  -- A global administrator cannot change their own role through this workflow.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005"}',true);
  v_denied:=false;
  begin
    perform public.admin_set_league_admin_role(
      '00000000-0000-4000-8000-000000000005',true,'Self grant must be denied'
    );
  exception when others then
    v_denied:=sqlerrm like '%cannot change their own role%';
  end;
  execute 'reset role';
  if not v_denied then raise exception 'Role management allowed a global administrator to change their own role'; end if;

  -- Full platform location-activation role matrix. This runs last so closing
  -- the synthetic seasons cannot affect earlier membership/finance assertions.
  update public.seasons
     set status='completed'
   where id in (
     '00000000-0000-4000-8000-000000000030',
     '00000000-0000-4000-8000-000000000031'
   );

  -- An ordinary player is denied even though the RPC is authenticated-callable.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000001"}',true);
  v_denied:=false;
  begin
    perform public.admin_set_location_active(
      '00000000-0000-4000-8000-000000000010',false,'CI ordinary player denial'
    );
  exception when others then
    v_denied:=sqlerrm='Global administrator permission required';
  end;
  execute 'reset role';
  if not v_denied then raise exception 'Ordinary player changed a platform-wide location activation state'; end if;

  -- An unassigned league administrator is denied as well as the assigned
  -- league administrator covered by the earlier negative test.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000009',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000009"}',true);
  v_denied:=false;
  begin
    perform public.admin_set_location_active(
      '00000000-0000-4000-8000-000000000010',false,'CI unassigned league admin denial'
    );
  exception when others then
    v_denied:=sqlerrm='Global administrator permission required';
  end;
  execute 'reset role';
  if not v_denied then raise exception 'Unassigned league administrator changed location activation'; end if;

  -- Anonymous execution must be denied by the function grant boundary.
  execute 'set local role anon';
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{}',true);
  v_denied:=false;
  begin
    perform public.admin_set_location_active(
      '00000000-0000-4000-8000-000000000010',false,'CI anonymous denial'
    );
  exception when others then
    v_denied:=true;
  end;
  execute 'reset role';
  if not v_denied then raise exception 'Anonymous caller changed location activation'; end if;

  -- Only a global admin may activate, and only the first-release Bideford
  -- location. A second Bideford cannot become active while Location A is active.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005"}',true);
  v_denied:=false;
  begin
    perform public.admin_set_location_active(
      '00000000-0000-4000-8000-000000000011',true,'CI non-Bideford activation denial'
    );
  exception when others then
    v_denied:=sqlerrm='Only Bideford may be activated for the first release';
  end;
  if not v_denied then raise exception 'Global admin activated a non-Bideford location'; end if;

  if not (select is_active from public.locations where id='00000000-0000-4000-8000-000000000010') then
    raise exception 'Location A must be active before testing the single-active-location constraint';
  end if;
  v_denied:=false;
  begin
    perform public.admin_set_location_active(
      '00000000-0000-4000-8000-000000000012',true,'CI duplicate active location denial'
    );
  exception
    when unique_violation then
      v_denied:=true;
    when others then
      v_denied:=sqlerrm='Only one location may be active for the first release';
  end;
  if not v_denied then raise exception 'A second Bideford location became active while another was active'; end if;
  if (select is_active from public.locations where id='00000000-0000-4000-8000-000000000012') then
    raise exception 'The duplicate Bideford location must remain inactive';
  end if;

  perform public.admin_set_location_active(
    '00000000-0000-4000-8000-000000000010',false,'CI global admin deactivation acceptance'
  );
  if (select is_active from public.locations where id='00000000-0000-4000-8000-000000000010') then
    raise exception 'Global admin deactivation did not persist';
  end if;
  perform public.admin_set_location_active(
    '00000000-0000-4000-8000-000000000010',true,'CI global admin activation acceptance'
  );
  if not (select is_active from public.locations where id='00000000-0000-4000-8000-000000000010') then
    raise exception 'Global admin activation did not persist';
  end if;
  execute 'reset role';

  -- super_admin has the same platform activation capability as admin.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000008',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000008"}',true);
  perform public.admin_set_location_active(
    '00000000-0000-4000-8000-000000000010',false,'CI super admin deactivation acceptance'
  );
  perform public.admin_set_location_active(
    '00000000-0000-4000-8000-000000000010',true,'CI super admin activation acceptance'
  );
  execute 'reset role';

  select count(*) into v_count
  from public.audit_log
  where entity_type='location'
    and entity_id='00000000-0000-4000-8000-000000000010'
    and action in ('location.activated','location.deactivated')
    and reason like 'CI % acceptance';
  if v_count<4 then raise exception 'Location activation/deactivation audit history is incomplete'; end if;

  -- A finance administrator cannot search or mutate platform roles.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000007',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000007"}',true);
  v_denied:=false;
  begin
    perform * from public.admin_search_league_admin_role_candidates('ci-player');
  exception when others then
    v_denied:=sqlerrm like '%Global administrator permission required%';
  end;
  execute 'reset role';
  if not v_denied then raise exception 'Finance administrator was able to search global role candidates'; end if;
end;
$role_matrix$;

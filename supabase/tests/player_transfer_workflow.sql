-- Player-led transfer, emergency multi-request and match-sheet cutoff regressions.
-- Runs only against the disposable local Supabase database in CI.

do $player_transfer_workflow$
declare
  v_player uuid:=gen_random_uuid();
  v_player_two uuid:=gen_random_uuid();
  v_player_three uuid:=gen_random_uuid();
  v_source_captain uuid:=gen_random_uuid();
  v_captain_b uuid:=gen_random_uuid();
  v_captain_c uuid:=gen_random_uuid();
  v_captain_d uuid:=gen_random_uuid();
  v_opponent_b_captain uuid:=gen_random_uuid();
  v_opponent_c_captain uuid:=gen_random_uuid();
  v_opponent_d_captain uuid:=gen_random_uuid();
  v_captain_e uuid:=gen_random_uuid();
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_season_two uuid;
  v_source_team uuid;
  v_team_b uuid;
  v_team_c uuid;
  v_team_d uuid;
  v_opponent_b uuid;
  v_opponent_c uuid;
  v_opponent_d uuid;
  v_team_e uuid;
  v_team_f uuid;
  v_other_league uuid;
  v_other_season uuid;
  v_other_team uuid;
  v_source_st uuid;
  v_b_st uuid;
  v_c_st uuid;
  v_d_st uuid;
  v_opponent_b_st uuid;
  v_opponent_c_st uuid;
  v_opponent_d_st uuid;
  v_e_st uuid;
  v_e_season_one_st uuid;
  v_f_st uuid;
  v_other_st uuid;
  v_fixture_b uuid;
  v_fixture_c uuid;
  v_fixture_d uuid;
  v_fixture_past uuid;
  v_sheet_d uuid;
  v_player_membership uuid;
  v_player_two_membership uuid;
  v_membership uuid;
  v_membership_three uuid;
  v_request_b uuid;
  v_request_c uuid;
  v_request_two uuid;
  v_destination_count integer;
  v_error text;
begin
  if has_table_privilege('authenticated','public.team_memberships','INSERT')
     or has_table_privilege('authenticated','public.team_memberships','UPDATE')
     or has_table_privilege('authenticated','public.player_transfer_requests','INSERT')
     or has_table_privilege('authenticated','public.player_transfer_requests','UPDATE')
     or has_table_privilege('authenticated','public.fixture_team_sheets','INSERT')
     or has_table_privilege('authenticated','public.fixture_team_sheets','UPDATE')
     or has_table_privilege('authenticated','public.fixture_team_sheet_players','INSERT')
     or has_table_privilege('authenticated','public.fixture_team_sheet_players','UPDATE') then
    raise exception 'Authenticated clients retain direct membership/transfer table write privileges';
  end if;

  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_player,'authenticated','authenticated','ci-transfer-player@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player_two,'authenticated','authenticated','ci-transfer-player-two@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player_three,'authenticated','authenticated','ci-transfer-player-three@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_source_captain,'authenticated','authenticated','ci-transfer-source-captain@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_captain_b,'authenticated','authenticated','ci-transfer-captain-b@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_captain_c,'authenticated','authenticated','ci-transfer-captain-c@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_captain_d,'authenticated','authenticated','ci-transfer-captain-d@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_opponent_b_captain,'authenticated','authenticated','ci-transfer-opponent-b@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_opponent_c_captain,'authenticated','authenticated','ci-transfer-opponent-c@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_opponent_d_captain,'authenticated','authenticated','ci-transfer-opponent-d@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_captain_e,'authenticated','authenticated','ci-transfer-captain-e@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_genuine)
  values
    (v_player,'Transfer Test Player','+447700910001','ci-transfer-player@openplay.invalid',date '1990-01-01','registered',true),
    (v_player_two,'Transfer Test Player Two','+447700910002','ci-transfer-player-two@openplay.invalid',date '1990-01-02','registered',true),
    (v_player_three,'Transfer Test Player Three','+447700910011','ci-transfer-player-three@openplay.invalid',date '1990-01-11','registered',true),
    (v_source_captain,'Transfer Source Captain','+447700910003','ci-transfer-source-captain@openplay.invalid',date '1990-01-03','registered',true),
    (v_captain_b,'Transfer Captain B','+447700910004','ci-transfer-captain-b@openplay.invalid',date '1990-01-04','registered',true),
    (v_captain_c,'Transfer Captain C','+447700910005','ci-transfer-captain-c@openplay.invalid',date '1990-01-05','registered',true),
    (v_captain_d,'Transfer Captain D','+447700910006','ci-transfer-captain-d@openplay.invalid',date '1990-01-06','registered',true),
    (v_opponent_b_captain,'Transfer Opponent B Captain','+447700910007','ci-transfer-opponent-b@openplay.invalid',date '1990-01-07','registered',true),
    (v_opponent_c_captain,'Transfer Opponent C Captain','+447700910008','ci-transfer-opponent-c@openplay.invalid',date '1990-01-08','registered',true),
    (v_opponent_d_captain,'Transfer Opponent D Captain','+447700910009','ci-transfer-opponent-d@openplay.invalid',date '1990-01-09','registered',true),
    (v_captain_e,'Transfer Captain E','+447700910010','ci-transfer-captain-e@openplay.invalid',date '1990-01-10','registered',true);

  insert into public.locations(name,slug,town)
  values('Transfer Workflow Test Location','transfer-workflow-test','Bideford')
  returning id into v_location;

  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location,'Transfer Workflow Test League','transfer-workflow-test','six_a_side',true)
  returning id into v_league;

  insert into public.seasons(league_id,name,status,is_public)
  values(v_league,'Transfer Workflow Season One','active',true)
  returning id into v_season;

  insert into public.seasons(league_id,name,status,is_public)
  values(v_league,'Transfer Workflow Season Two','registration_open',true)
  returning id into v_season_two;

  insert into public.teams(created_by) values(v_source_captain) returning id into v_source_team;
  insert into public.teams(created_by) values(v_captain_b) returning id into v_team_b;
  insert into public.teams(created_by) values(v_captain_c) returning id into v_team_c;
  insert into public.teams(created_by) values(v_captain_d) returning id into v_team_d;
  insert into public.teams(created_by) values(v_opponent_b_captain) returning id into v_opponent_b;
  insert into public.teams(created_by) values(v_opponent_c_captain) returning id into v_opponent_c;
  insert into public.teams(created_by) values(v_opponent_d_captain) returning id into v_opponent_d;
  insert into public.teams(created_by) values(v_captain_e) returning id into v_team_e;
  insert into public.teams(created_by) values(v_captain_e) returning id into v_team_f;

  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values
    (v_source_team,v_season,'Transfer Source Club','transfer-source-club','approved',v_source_captain),
    (v_team_b,v_season,'Transfer Destination B','transfer-destination-b','approved',v_captain_b),
    (v_team_c,v_season,'Transfer Destination C','transfer-destination-c','approved',v_captain_c),
    (v_team_d,v_season,'Transfer Destination D','transfer-destination-d','approved',v_captain_d),
    (v_opponent_b,v_season,'Transfer Opponent B','transfer-opponent-b','approved',v_opponent_b_captain),
    (v_opponent_c,v_season,'Transfer Opponent C','transfer-opponent-c','approved',v_opponent_c_captain),
    (v_opponent_d,v_season,'Transfer Opponent D','transfer-opponent-d','approved',v_opponent_d_captain),
    (v_team_e,v_season_two,'Transfer Season Two Club E','transfer-season-two-e','approved',v_captain_e),
    (v_team_f,v_season_two,'Transfer Season Two Club F','transfer-season-two-f','approved',v_captain_e);

  select id into v_source_st from public.season_teams where team_id=v_source_team and season_id=v_season;
  select id into v_b_st from public.season_teams where team_id=v_team_b and season_id=v_season;
  select id into v_c_st from public.season_teams where team_id=v_team_c and season_id=v_season;
  select id into v_d_st from public.season_teams where team_id=v_team_d and season_id=v_season;
  select id into v_opponent_b_st from public.season_teams where team_id=v_opponent_b and season_id=v_season;
  select id into v_opponent_c_st from public.season_teams where team_id=v_opponent_c and season_id=v_season;
  select id into v_opponent_d_st from public.season_teams where team_id=v_opponent_d and season_id=v_season;
  select id into v_e_st from public.season_teams where team_id=v_team_e and season_id=v_season_two;
  select id into v_f_st from public.season_teams where team_id=v_team_f and season_id=v_season_two;

  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values
    (v_source_st,v_source_captain,'active',true),
    (v_source_st,v_player,'active',false),
    (v_source_st,v_player_two,'active',false),
    (v_b_st,v_captain_b,'active',true),
    (v_c_st,v_captain_c,'active',true),
    (v_d_st,v_captain_d,'active',true),
    (v_opponent_b_st,v_opponent_b_captain,'active',true),
    (v_opponent_c_st,v_opponent_c_captain,'active',true),
    (v_opponent_d_st,v_opponent_d_captain,'active',true),
    (v_e_st,v_captain_e,'active',true),
    (v_f_st,v_captain_e,'active',false);

  select id into v_player_membership from public.team_memberships
  where season_team_id=v_source_st and user_id=v_player;
  select id into v_player_two_membership from public.team_memberships
  where season_team_id=v_source_st and user_id=v_player_two;

  insert into public.fixtures(season_id,home_team_id,away_team_id,gameweek,status,scheduled_at)
  values
    (v_season,v_b_st,v_opponent_b_st,1,'scheduled',now()+interval '12 hours')
  returning id into v_fixture_b;
  insert into public.fixtures(season_id,home_team_id,away_team_id,gameweek,status,scheduled_at)
  values
    (v_season,v_c_st,v_opponent_c_st,1,'scheduled',now()+interval '12 hours')
  returning id into v_fixture_c;
  insert into public.fixtures(season_id,home_team_id,away_team_id,gameweek,status,scheduled_at)
  values
    (v_season,v_d_st,v_opponent_d_st,1,'scheduled',now()+interval '12 hours')
  returning id into v_fixture_d;

  -- A draft can be saved and edited before kickoff without excluding the club
  -- from emergency transfer eligibility.
  perform set_config('request.jwt.claim.sub',v_captain_b::text,true);
  perform public.save_team_sheet_draft(v_fixture_b,v_b_st,'{}'::uuid[],'{}'::uuid[],null);
  perform public.save_team_sheet_draft(v_fixture_b,v_b_st,'{}'::uuid[],'{}'::uuid[],null);

  -- Club D has already submitted; it must not be an emergency destination.
  perform set_config('request.jwt.claim.sub',v_captain_d::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,submitted_at,is_locked)
  values(v_fixture_d,v_d_st,v_captain_d,now(),true)
  returning id into v_sheet_d;

  -- A still-attached player cannot request a transfer.
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  begin
    perform public.request_player_transfer(v_b_st,'Attempt while still attached');
    raise exception 'An attached player was incorrectly allowed to request a transfer';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'Leave your current club in this league%' then raise; end if;
  end;

  -- Both players leave their source club themselves, with no captain approval.
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  perform public.leave_team_membership(v_player_membership);
  perform set_config('request.jwt.claim.sub',v_player_two::text,true);
  perform public.leave_team_membership(v_player_two_membership);

  -- Returning players cannot bypass transfers through ordinary join RPCs or
  -- direct active-membership writes.
  begin
    perform public.request_team_membership(v_e_st);
    raise exception 'A returning player was incorrectly allowed to use ordinary team joining';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'Use the player transfer workflow%' then raise; end if;
  end;
  begin
    insert into public.team_memberships(season_team_id,user_id,status,is_captain)
    values(v_e_st,v_player_two,'active',false);
    raise exception 'A returning player was incorrectly attached without an approved transfer';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'A player who voluntarily left a different club%' then raise; end if;
  end;

  perform set_config('request.jwt.claim.sub',v_player::text,true);
  select count(*) into v_destination_count
  from public.get_my_transfer_destinations()
  where emergency_window=true;
  if v_destination_count<>2 then
    raise exception 'Emergency destinations must include only the two clubs with unsubmitted matchday sheets; found %',v_destination_count;
  end if;
  if exists(
    select 1 from public.get_my_transfer_destinations()
    where destination_team_id=v_d_st
  ) then
    raise exception 'A club with a submitted team sheet was incorrectly offered an emergency transfer';
  end if;

  select (public.request_player_transfer(v_b_st,'Emergency transfer request to club B')).id
  into v_request_b;
  select (public.request_player_transfer(v_c_st,'Emergency transfer request to club C')).id
  into v_request_c;

  if (select count(*) from public.player_transfer_requests
      where user_id=v_player and league_id=v_league and status='pending' and is_emergency)<>2 then
    raise exception 'The player could not submit simultaneous emergency requests to eligible clubs';
  end if;

  -- Only the destination captain may make the ordinary decision.
  perform set_config('request.jwt.claim.sub',v_source_captain::text,true);
  begin
    perform public.resolve_player_transfer_request(v_request_b,'approved','Wrong captain attempt');
    raise exception 'A non-destination captain was incorrectly allowed to approve a transfer';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'Only the destination club captain%' then raise; end if;
  end;

  -- The destination captain sees the request in their own approval queue.
  perform set_config('request.jwt.claim.sub',v_captain_b::text,true);
  if not exists(select 1 from public.get_captain_transfer_requests() where id=v_request_b) then
    raise exception 'Destination captain cannot see their pending transfer request';
  end if;

  -- First captain approval secures the player and cancels all competing requests.
  perform set_config('request.jwt.claim.sub',v_captain_b::text,true);
  perform public.resolve_player_transfer_request(v_request_b,'approved','Destination captain approved');

  if not exists(
    select 1 from public.team_memberships
    where user_id=v_player and season_team_id=v_b_st and status='active'
  ) then
    raise exception 'The first approving captain did not receive the player';
  end if;
  if not exists(
    select 1 from public.player_transfer_requests
    where id=v_request_c and status='cancelled'
      and resolution_reason='Automatically cancelled because another club secured the player'
  ) then
    raise exception 'Competing emergency request was not automatically cancelled';
  end if;

  perform set_config('request.jwt.claim.sub',v_captain_c::text,true);
  begin
    perform public.resolve_player_transfer_request(v_request_c,'approved','Second captain approved');
    raise exception 'A second captain was incorrectly allowed to approve the already-secured player';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'This transfer has already been resolved%' then raise; end if;
  end;

  -- A club becomes ineligible as soon as it submits its matchday sheet.
  perform set_config('request.jwt.claim.sub',v_captain_b::text,true);
  update public.fixture_team_sheets
  set is_locked=true,submitted_at=now()
  where fixture_id=v_fixture_b and season_team_id=v_b_st;

  perform set_config('request.jwt.claim.sub',v_player_two::text,true);
  select count(*) into v_destination_count
  from public.get_my_transfer_destinations()
  where emergency_window=true;
  if v_destination_count<>1 or exists(
    select 1 from public.get_my_transfer_destinations()
    where destination_team_id in (v_b_st,v_d_st)
  ) then
    raise exception 'Submitted clubs remained eligible for emergency transfer requests';
  end if;

  select (public.request_player_transfer(v_c_st,'Emergency request to club C')).id
  into v_request_two;

  -- If the destination submits after receiving the request, it is cancelled.
  perform set_config('request.jwt.claim.sub',v_captain_c::text,true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,submitted_at,is_locked)
  values(v_fixture_c,v_c_st,v_captain_c,now(),true);

  if not exists(
    select 1 from public.player_transfer_requests
    where id=v_request_two and status='cancelled'
      and resolution_reason='Destination club submitted its matchday team sheet; emergency request expired'
  ) then
    raise exception 'Submitting the destination sheet did not expire its pending emergency request';
  end if;

  -- Outside the emergency window, only one pending destination is permitted.
  update public.fixtures set scheduled_at=now()+interval '48 hours'
  where id in (v_fixture_b,v_fixture_c,v_fixture_d);

  perform set_config('request.jwt.claim.sub',v_player_two::text,true);
  if exists(
    select 1 from public.get_my_transfer_destinations()
    where emergency_window=true
  ) then
    raise exception 'Emergency mode remained open more than 24 hours before kickoff';
  end if;

  select (public.request_player_transfer(v_e_st,'Normal transfer request to club E')).id
  into v_request_two;

  begin
    perform public.request_player_transfer(v_c_st,'Second normal transfer request to club C');
    raise exception 'A second normal transfer request was incorrectly allowed';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'You already have a pending transfer request%' then raise; end if;
  end;

  -- A transfer pending in this league also blocks ordinary team-join requests.
  begin
    perform public.request_team_membership(v_e_st);
    raise exception 'A team-join request was incorrectly allowed alongside a pending transfer';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'Cancel or resolve your pending transfer request%' then raise; end if;
  end;

  perform public.cancel_player_transfer_request(v_request_two);

  -- Re-request the destination through the transfer route and let its captain approve.
  select (public.request_player_transfer(v_e_st,'Second transfer request to club E')).id
  into v_request_two;
  perform set_config('request.jwt.claim.sub',v_captain_e::text,true);
  perform public.resolve_player_transfer_request(v_request_two,'approved','Destination captain approved');

  -- Ordinary first-time join requests are also single-destination within a league.
  perform set_config('request.jwt.claim.sub',v_player_three::text,true);
  perform public.request_team_membership(v_e_st);
  begin
    perform public.request_team_membership(v_f_st);
    raise exception 'A second pending team-join request was incorrectly allowed';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'You already have a pending team request%' then raise; end if;
  end;

  select id into v_membership_three from public.team_memberships
  where season_team_id=v_e_st and user_id=v_player_three and status='pending';
  perform set_config('request.jwt.claim.sub',v_captain_e::text,true);
  perform public.resolve_team_membership_request(v_membership_three,'approved');

  -- One active membership is enforced across seasons of the same league.

  begin
    insert into public.team_memberships(season_team_id,user_id,status,is_captain)
    values(v_c_st,v_player_two,'active',false);
    raise exception 'A second active club in the same league was incorrectly allowed across seasons';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'A player can represent only one club%' then raise; end if;
  end;

  -- The same player may still represent a club in a different league.
  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location,'Transfer Other League','transfer-other-league','six_a_side',true)
  returning id into v_other_league;
  insert into public.seasons(league_id,name,status,is_public)
  values(v_other_league,'Transfer Other League Season','active',true)
  returning id into v_other_season;
  insert into public.teams(created_by) values(v_captain_e) returning id into v_other_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_other_team,v_other_season,'Transfer Other League Club','transfer-other-league-club','approved',v_captain_e)
  returning id into v_other_st;
  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_other_st,v_player_two,'active',false);

  -- Draft save is permitted before kickoff but rejected once kickoff has passed.
  insert into public.fixtures(season_id,home_team_id,away_team_id,gameweek,status,scheduled_at)
  values(v_season_two,v_e_st,v_f_st,1,'scheduled',now()-interval '1 hour')
  returning id into v_fixture_past;

  perform set_config('request.jwt.claim.sub',v_captain_e::text,true);
  begin
    perform public.save_team_sheet_draft(v_fixture_past,v_e_st,'{}'::uuid[],'{}'::uuid[],null);
    raise exception 'A team-sheet draft was incorrectly allowed after kickoff';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'Team sheets can only be edited, saved or submitted before kickoff%' then raise; end if;
  end;

  if not exists(
    select 1 from public.team_memberships
    where user_id=v_player and season_team_id=v_b_st and status='active'
  ) or exists(
    select 1 from public.team_memberships tm
    join public.season_teams st on st.id=tm.season_team_id
    join public.seasons s on s.id=st.season_id
    where tm.user_id=v_player and tm.status='active'
      and s.league_id=v_league and tm.season_team_id<>v_b_st
  ) then
    raise exception 'Transfer approval did not preserve one active club in the league';
  end if;
end;
$player_transfer_workflow$;

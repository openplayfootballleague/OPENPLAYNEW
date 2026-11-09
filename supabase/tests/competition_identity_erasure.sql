-- Permanent competition identity and safe account erasure regression tests.
-- Runs only against the disposable local Supabase database in CI.

do $competition_identity_erasure$
declare
  v_player constant uuid := '93000000-0000-4000-8000-000000000001';
  v_admin constant uuid := '93000000-0000-4000-8000-000000000002';
  v_location_admin constant uuid := '93000000-0000-4000-8000-000000000003';
  v_returning_user constant uuid := '93000000-0000-4000-8000-000000000004';
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_home_team uuid;
  v_away_team uuid;
  v_home_season_team uuid;
  v_away_season_team uuid;
  v_fixture uuid;
  v_home_sheet uuid;
  v_away_sheet uuid;
  v_membership uuid;
  v_player_row uuid;
  v_other_player_row uuid;
  v_competition_player uuid;
  v_transfer uuid;
  v_payment uuid;
  v_options jsonb;
  v_stats jsonb;
  v_sheet_players jsonb;
  v_prepared boolean;
  v_count integer;
begin
  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at,last_sign_in_at)
  values
    (v_player,'authenticated','authenticated','ci-competition-player@openplay.invalid','','{}'::jsonb,now(),now()-interval '2 years',now(),now()-interval '13 months'),
    (v_admin,'authenticated','authenticated','ci-competition-admin@openplay.invalid','','{}'::jsonb,now(),now(),now(),now()),
    (v_location_admin,'authenticated','authenticated','ci-competition-location-admin@openplay.invalid','','{}'::jsonb,now(),now()-interval '2 years',now(),now()-interval '13 months');

  insert into public.user_roles(user_id,role,granted_by)
  values(v_admin,'admin',v_player);

  update public.profiles
  set last_sign_in_at=now()-interval '13 months',
      avatar_path=v_player::text||'/avatar.webp'
  where id=v_player;

  update public.profiles
  set last_sign_in_at=now()-interval '13 months'
  where id=v_location_admin;

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_genuine)
  values
    (v_player,'Competition History Player','+447700900001','ci-competition-player@openplay.invalid',date '1990-01-01','registered',true),
    (v_location_admin,'Location Admin Player','+447700900002','ci-competition-location-admin@openplay.invalid',date '1990-02-01','registered',true);

  select id,competition_player_id into v_player_row,v_competition_player
  from public.players where user_id=v_player;

  select id into v_other_player_row from public.players where user_id=v_location_admin;

  insert into public.locations(name,slug,town)
  values('Competition Identity Test Location','competition-identity-test','Bideford')
  returning id into v_location;

  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location,'Competition Identity Test League','competition-identity-test','six_a_side',true)
  returning id into v_league;

  insert into public.seasons(league_id,name,status,is_public)
  values(v_league,'Competition Identity Test Season','active',true)
  returning id into v_season;

  insert into public.teams(created_by) values(v_player) returning id into v_home_team;
  insert into public.teams(created_by) values(v_admin) returning id into v_away_team;

  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_home_team,v_season,'Identity Test Home','identity-test-home','approved',v_player)
  returning id into v_home_season_team;

  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_away_team,v_season,'Identity Test Away','identity-test-away','approved',v_admin)
  returning id into v_away_season_team;

  insert into public.fixtures(season_id,home_team_id,away_team_id,gameweek,status)
  values(v_season,v_home_season_team,v_away_season_team,1,'completed')
  returning id into v_fixture;

  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by)
  values(v_fixture,1,0,now(),v_player);

  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked,submitted_at)
  values(v_fixture,v_home_season_team,v_player,true,now())
  returning id into v_home_sheet;

  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked,submitted_at)
  values(v_fixture,v_away_season_team,v_admin,true,now())
  returning id into v_away_sheet;

  insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,is_goalkeeper,squad_number_snapshot)
  values(v_home_sheet,v_player,'starter',false,8);

  insert into public.fixture_goal_records(fixture_id,season_team_id,scorer_user_id,created_by)
  values(v_fixture,v_home_season_team,v_player,v_player);

  insert into public.fixture_goal_records(
    fixture_id,season_team_id,scorer_user_id,created_by,voided_at,voided_by,void_reason
  ) values(v_fixture,v_home_season_team,v_player,v_admin,now(),v_player,'Test voided record');

  insert into public.team_memberships(season_team_id,user_id,status,is_captain,left_at)
  values(v_home_season_team,v_player,'left',false,now())
  returning id into v_membership;

  insert into public.player_transfer_requests(
    user_id,source_membership_id,source_season_team_id,destination_season_team_id,
    reason,status,resolved_at,resolved_by,resolution_reason
  ) values(
    v_player,v_membership,v_home_season_team,v_away_season_team,
    'Test historical transfer reason','cancelled',now(),v_player,'Test resolution note'
  ) returning id into v_transfer;

  insert into public.payment_records(
    season_team_id,fixture_id,player_user_id,amount_pence,currency,status,fee_snapshot,
    stripe_customer_id,paid_at
  ) values(
    v_home_season_team,v_fixture,v_player,500,'gbp','paid',
    jsonb_build_object('player_fee_pence',500,'season_id',v_season,'gameweek',1),
    'cus_competition_identity_test',now()
  ) returning id into v_payment;

  insert into public.finance_entries(season_team_id,entry_type,amount_pence,description,created_by)
  values(v_home_season_team,'charge',500,'Historical test charge',v_player);

  insert into public.gallery_items(location_id,object_path,caption,uploaded_by)
  values(v_location,'competition-identity-test/test.jpg','Test gallery item',v_player);

  -- The player is an assigning administrator in historical audit metadata only,
  -- not the current location administrator. This reference must be nulled.
  insert into public.location_admin_assignments(user_id,location_id,assigned_by)
  values(v_admin,v_location,v_player);

  -- A separate location administrator without a global role must be excluded
  -- from automatic inactivity closure.
  insert into public.location_admin_assignments(user_id,location_id,assigned_by)
  values(v_location_admin,v_location,v_admin);

  insert into public.notification_events(user_id,channel,event_type,status,payload,held_at,held_by,hold_reason)
  values(v_player,'email','test.player.notification','held',jsonb_build_object('fixture_id',v_fixture),now(),v_player,'Test hold');

  insert into public.notification_events(user_id,channel,event_type,status,payload,held_at,held_by,hold_reason)
  values(v_admin,'in_app','test.admin.notification','held',
    jsonb_build_object('player_user_id',v_player,'player_id',v_player_row,'player_name','Competition History Player'),
    now(),v_player,'Test hold by former user');

  insert into public.player_guardian_consents(
    player_user_id,player_date_of_birth,guardian_full_name,guardian_email,status,
    withdrawal_token_hash,verified_at,reviewed_by,reviewed_at
  ) values(
    v_player,date '1990-01-01','Guardian Personal Name','guardian-ci@openplay.invalid','approved',
    repeat('a',64),now(),v_admin,now()
  );

  insert into public.player_registration_reviews(
    player_id,name_matched,phone_matched,email_matched,matched_player_ids,reviewed_by,reviewed_at,review_reason
  ) values(v_other_player_row,true,true,true,array[v_player_row],v_player,now(),'Reviewed using Competition History Player personal details');

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(
    v_player,'player.details.corrected','player',v_player_row::text,'Player name and contact corrected',
    jsonb_build_object('full_name','Competition History Player','email','ci-competition-player@openplay.invalid'),
    jsonb_build_object('user_id',v_player,'phone','+447700900001')
  );

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(
    v_admin,'fixture.result.recorded','fixture',v_fixture::text,'Fixture result entered',
    jsonb_build_object('home_scorers',jsonb_build_array(v_player),'player_name','Competition History Player'),
    jsonb_build_object('scorer_user_id',v_player,'score',jsonb_build_array(1,0))
  );

  update public.profiles
  set account_retention_status='erasure_due',
      account_closed_at=now()-interval '13 months',
      archive_expires_at=now()-interval '1 day',
      retention_hold=false
  where id=v_player;

  -- A closed/erasure-due account cannot acquire a new active or pending membership.
  begin
    insert into public.team_memberships(season_team_id,user_id,status,is_captain)
    values(v_away_season_team,v_player,'active',false);
    raise exception 'A closed player account was incorrectly allowed to join a team';
  exception when others then
    if sqlerrm not like 'An active registered player account is required%' then
      raise;
    end if;
  end;

  if not exists (
    select 1 from public.players
    where user_id=v_player and competition_player_id=v_competition_player
  ) then raise exception 'Player did not receive a permanent competition identity'; end if;

  -- The location-admin assignment blocks inactivity closure despite no global role.
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  select count(*) into v_count
  from public.admin_list_inactive_player_accounts()
  where user_id=v_location_admin;
  if v_count<>0 then raise exception 'A location administrator was incorrectly selected for inactivity closure'; end if;

  select public.admin_prepare_player_account_erasure(v_player) into v_prepared;
  if not v_prepared then raise exception 'Eligible expired player account was not prepared for erasure'; end if;

  execute 'reset role';

  if exists(select 1 from public.profiles where id=v_player and avatar_path is not null) then
    raise exception 'Profile avatar path was not scrubbed';
  end if;
  if exists(select 1 from public.players where user_id=v_player and
      (full_name<>'Former player' or email like '%ci-competition-player%' or date_of_birth<>date '1900-01-01')) then
    raise exception 'Player personal details were not scrubbed before Auth deletion';
  end if;
  if not exists(select 1 from public.competition_player_identities
      where id=v_competition_player and display_name='Former player' and anonymised_at is not null and counts_for_statistics) then
    raise exception 'Competition identity did not retain its anonymised statistics eligibility';
  end if;

  delete from auth.users where id=v_player;

  if exists(select 1 from auth.users where id=v_player)
     or exists(select 1 from public.profiles where id=v_player)
     or exists(select 1 from public.players where user_id=v_player) then
    raise exception 'Auth account, profile or personal player record was not deleted';
  end if;

  if not exists(select 1 from public.fixture_team_sheet_players
      where team_sheet_id=v_home_sheet and user_id is null and competition_player_id=v_competition_player) then
    raise exception 'Historic team-sheet appearance was deleted or lost its competition identity';
  end if;

  if not exists(select 1 from public.fixture_goal_records
      where fixture_id=v_fixture and scorer_user_id is null and competition_player_id=v_competition_player
        and voided_at is null) then
    raise exception 'Historic goalscorer record was deleted or lost its competition identity';
  end if;

  if not exists(select 1 from public.fixture_team_sheets where id=v_home_sheet and submitted_by is null)
     or not exists(select 1 from public.fixture_results where fixture_id=v_fixture and confirmed_by is null) then
    raise exception 'Historical sheet/result audit actor references were not detached';
  end if;

  if not exists(select 1 from public.teams where id=v_home_team and created_by is null)
     or not exists(select 1 from public.season_teams where id=v_home_season_team and approved_by is null)
     or not exists(select 1 from public.user_roles where user_id=v_admin and granted_by is null)
     or not exists(select 1 from public.player_registration_reviews
       where player_id=v_other_player_row and reviewed_by is null) then
    raise exception 'Historical creator, approver or reviewer references were not detached';
  end if;

  if not exists(select 1 from public.payment_records
      where id=v_payment and player_user_id is null and stripe_customer_id is null) then
    raise exception 'Payment record was not retained with its account/customer link removed';
  end if;

  if not exists(select 1 from public.player_transfer_requests
      where id=v_transfer and user_id is null and source_membership_id is null
        and resolved_by is null and reason='Anonymised following account retention') then
    raise exception 'Transfer history was not retained in anonymised form';
  end if;

  if not exists(select 1 from public.finance_entries
      where description='Historical test charge' and created_by is null)
     or not exists(select 1 from public.gallery_items
      where object_path='competition-identity-test/test.jpg' and uploaded_by is null)
     or not exists(select 1 from public.location_admin_assignments
      where user_id=v_admin and location_id=v_location and assigned_by is null) then
    raise exception 'Historical operational records retained a deleted account actor reference';
  end if;

  if exists(select 1 from public.player_guardian_consents where player_user_id=v_player) then
    raise exception 'Guardian consent personal data was not erased';
  end if;
  if exists(select 1 from public.notification_events where user_id=v_player) then
    raise exception 'The deleted player still has notification events';
  end if;
  if not exists(select 1 from public.notification_events
      where user_id=v_admin and held_by is null
        and payload::text not like '%'||v_player::text||'%'
        and payload::text not like '%'||v_player_row::text||'%') then
    raise exception 'Notification payload or historical hold actor still identifies the deleted player';
  end if;

  if exists(select 1 from public.audit_log
      where entity_id=v_player_row::text or actor_user_id=v_player
        or (entity_type='player' and entity_id='anonymised' and
          (coalesce(before_data::text,'') like '%Competition History Player%'
           or coalesce(before_data::text,'') like '%ci-competition-player%'
           or coalesce(after_data::text,'') like '%'||v_player::text||'%'))) then
    raise exception 'Audit history retained direct personal identifiers';
  end if;
  if not exists(select 1 from public.player_registration_reviews
      where player_id=v_other_player_row and not (v_player_row=any(matched_player_ids))
        and reviewed_by is null and review_reason is null) then
    raise exception 'Registration review retained the deleted player ID, reviewer link or reviewer personal details';
  end if;

  -- A returning person who signs up again gets a new, unlinked competition identity.
  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at,last_sign_in_at)
  values(v_returning_user,'authenticated','authenticated','ci-competition-player@openplay.invalid','','{}'::jsonb,now(),now(),now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_genuine)
  values(v_returning_user,'Returning Competition Player','+447700900004',
    'ci-competition-player@openplay.invalid',date '1990-01-01','registered',true);

  if (select competition_player_id from public.players where user_id=v_returning_user)=v_competition_player then
    raise exception 'A new registration was linked to the erased player competition identity';
  end if;

  -- The anonymised identity remains selectable for historic result corrections.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  select public.get_admin_fixture_scorer_options(v_fixture) into v_options;
  if not exists(
    select 1 from jsonb_array_elements(v_options->'home_players') p
    where p->>'competition_player_id'=v_competition_player::text
      and p->>'full_name'='Former player'
  ) then raise exception 'Historic goalscorer options did not retain the anonymised competition identity'; end if;

  perform public.admin_record_fixture_result_with_appearances(
    v_fixture,1,0,'{}'::uuid[],'{}'::uuid[],array[v_competition_player],'{}'::uuid[],
    'Correction after account erasure'
  );

  select public.get_admin_season_statistics(v_season) into v_stats;
  if not exists(
    select 1 from jsonb_array_elements(v_stats->'players') p
    where p->>'competition_player_id'=v_competition_player::text
      and p->>'full_name'='Former player'
      and (p->>'apps')::integer=1
      and (p->>'goals')::integer=1
  ) then raise exception 'Season statistics lost the anonymised player appearance or goal'; end if;

  select players into v_sheet_players
  from public.get_admin_team_sheets_contextual(v_location,v_league,v_season)
  where team_sheet_id=v_home_sheet;
  if not exists(
    select 1 from jsonb_array_elements(v_sheet_players) p
    where p->>'player_name'='Former player' and p->'membership_id'='null'::jsonb
  ) then raise exception 'Admin team-sheet history did not display the anonymised former player'; end if;

  execute 'reset role';
end;
$competition_identity_erasure$;

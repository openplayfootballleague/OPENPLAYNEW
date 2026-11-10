-- Referee match-report deadline, rejection/resubmission, approval, discipline and finance regression.
-- Runs only against the disposable local Supabase database created by CI.
do $referee_match_reports$
declare
  v_admin constant uuid:='95000000-0000-4000-8000-000000000001';
  v_referee constant uuid:='95000000-0000-4000-8000-000000000002';
  v_home_user constant uuid:='95000000-0000-4000-8000-000000000003';
  v_away_user constant uuid:='95000000-0000-4000-8000-000000000004';
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_home_team uuid;
  v_away_team uuid;
  v_home_season_team uuid;
  v_away_season_team uuid;
  v_application uuid;
  v_fixture_one uuid;
  v_fixture_two uuid;
  v_fixture_three uuid;
  v_assignment public.referee_fixture_assignments;
  v_referee_identity constant uuid:='95000000-0000-4000-8000-000000000005';
  v_home_identity constant uuid:='95000000-0000-4000-8000-000000000006';
  v_away_identity constant uuid:='95000000-0000-4000-8000-000000000007';
  v_home_sheet_one uuid;
  v_away_sheet_one uuid;
  v_home_sheet_two uuid;
  v_away_sheet_two uuid;
  v_home_sheet_three uuid;
  v_away_sheet_three uuid;
  v_report_one uuid;
  v_report_two uuid;
  v_future_one timestamptz;
  v_future_two timestamptz;
  v_weekday integer;
  v_events jsonb;
  v_rejected boolean;
  v_count integer;
  v_amount integer;
  v_options jsonb;
  v_corrected_events jsonb;
  v_correction_options jsonb;
  v_corrected_version integer;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-referee-report-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_referee,'authenticated','authenticated','ci-referee-report-referee@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_home_user,'authenticated','authenticated','ci-referee-report-home@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_away_user,'authenticated','authenticated','ci-referee-report-away@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.competition_player_identities(id,display_name,counts_for_statistics)
  values
    (v_referee_identity,'Report Test Referee',false),
    (v_home_identity,'Report Home Player',true),
    (v_away_identity,'Report Away Player',true);

  insert into public.players(user_id,competition_player_id,full_name,phone,email,date_of_birth,registration_status,is_banned,is_genuine)
  values
    (v_referee,v_referee_identity,'Report Test Referee','07700900802','ci-referee-report-referee@openplay.invalid',date '1990-03-02','registered',false,true),
    (v_home_user,v_home_identity,'Report Home Player','07700900803','ci-referee-report-home@openplay.invalid',date '1990-03-03','registered',false,true),
    (v_away_user,v_away_identity,'Report Away Player','07700900804','ci-referee-report-away@openplay.invalid',date '1990-03-04','registered',false,true);
  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'admin',v_admin);
  select id into v_location from public.locations where is_active=true order by created_at limit 1;
  if v_location is null then raise exception 'Expected an active location from earlier regression'; end if;

  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Referee Reports League','ci-referee-reports-league',false)
  returning id into v_league;
  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Referee Reports Season',992,'active',false)
  returning id into v_season;

  insert into public.teams(created_by) values(v_admin) returning id into v_home_team;
  insert into public.teams(created_by) values(v_admin) returning id into v_away_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values
    (v_home_team,v_season,'Report Home','ci-report-home','approved',now(),v_admin),
    (v_away_team,v_season,'Report Away','ci-report-away','approved',now(),v_admin)
  ;
  select id into v_home_season_team from public.season_teams where slug='ci-report-home';
  select id into v_away_season_team from public.season_teams where slug='ci-report-away';

  v_future_one:=now()+interval '2 days';
  v_future_two:=now()+interval '4 days';
  v_weekday:=extract(isodow from v_future_one at time zone 'Europe/London')::integer;
  insert into public.referee_applications(
    user_id,status,experience_summary,qualifications,availability,contact_phone,preferred_location_ids,
    submitted_at,reviewed_at,reviewed_by,review_reason
  ) values(
    v_referee,'approved','CI match report workflow referee','{}'::text[],
    (select jsonb_agg(jsonb_build_object('weekday',day_no,'start_time','00:00','end_time','23:59'))
      from generate_series(1,7) day_no),
    '+44770090802',array[v_location],now(),now(),v_admin,'CI approved referee'
  ) returning id into v_application;
  insert into public.referee_memberships(user_id,application_id,status,approved_by,status_changed_by,status_reason)
  values(v_referee,v_application,'active',v_admin,v_admin,'CI approved referee membership');

  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,991,1,v_home_season_team,v_away_season_team,v_location,v_future_one,'scheduled')
  returning id into v_fixture_one;

  -- Allocate while the fixture is in the future, then simulate the completed match.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform public.save_admin_context_preference(v_location,v_league,v_season);
  v_assignment:=public.admin_assign_referee_to_fixture(v_fixture_one,v_referee,'lead');
  execute 'reset role';

  -- Synthetic test setup uses the trusted service-role path; application
  -- writes remain restricted to captain/admin RPCs.
  perform set_config('request.jwt.claim.role','service_role',true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked)
  values(v_fixture_one,v_home_season_team,v_admin,true) returning id into v_home_sheet_one;
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked)
  values(v_fixture_one,v_away_season_team,v_admin,true) returning id into v_away_sheet_one;
  insert into public.fixture_team_sheet_players(team_sheet_id,user_id,competition_player_id,role,is_goalkeeper,did_appear)
  values
    (v_home_sheet_one,v_home_user,v_home_identity,'starter',false,true),
    (v_away_sheet_one,v_away_user,v_away_identity,'starter',false,true);
  perform set_config('request.jwt.claim.role','authenticated',true);

  -- Create team sheets before simulating the completed match; kickoff lock remains enforced.
  update public.fixtures set scheduled_at=now()-interval '1 hour',status='in_progress' where id=v_fixture_one;

  v_events:=jsonb_build_array(
    jsonb_build_object('season_team_id',v_home_season_team,'recipient_type','registered_player',
      'card_type','straight_red','competition_player_id',v_home_identity,'minute',20,'description','Straight red'),
    jsonb_build_object('season_team_id',v_away_season_team,'recipient_type','bench',
      'card_type','yellow','minute',40,'description','Bench caution'),
    jsonb_build_object('season_team_id',v_home_season_team,'recipient_type','supporter',
      'card_type','second_yellow_red','minute',60,'description','Supporter misconduct')
  );

  -- The appointed referee can submit during the 24-hour window.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_referee::text,true);
  v_report_one:=public.submit_referee_match_report(
    v_fixture_one,1,0,'{}'::uuid[],'{}'::uuid[],array[v_home_identity],'{}'::uuid[],v_events,
    'A competitive match with one goal.'
  );
  if (public.get_my_referee_fixture_report_options(v_fixture_one)->'report'->>'status')<>'submitted' then
    raise exception 'Referee report did not appear in the referee workspace';
  end if;

  v_rejected:=false;
  begin
    perform (select count(*) from public.referee_match_reports);
  exception when insufficient_privilege then
    v_rejected:=true;
  end;
  if not v_rejected then raise exception 'Referee could read report records directly instead of through the scoped RPC'; end if;
  v_rejected:=false;
  begin
    perform public.admin_submit_referee_match_report(
      v_fixture_one,1,0,'{}'::uuid[],'{}'::uuid[],array[v_home_identity],'{}'::uuid[],v_events,
      'Unauthorized admin report attempt','Not allowed'
    );
  exception when others then
    v_rejected:=sqlerrm like '%Administrator permission required%';
  end;
  if not v_rejected then raise exception 'Referee was able to use the administrator report override'; end if;
  execute 'reset role';

  -- Administrator rejection preserves the report and returns it to the referee.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform public.admin_review_referee_match_report(v_report_one,'rejected','Please verify the card details');
  execute 'reset role';
  if not exists(
    select 1 from public.notification_events
    where user_id=v_referee and event_type='referee.report.rejected'
      and payload->>'report_id'=v_report_one::text
  ) then raise exception 'Rejected referee report did not enqueue a notification'; end if;

  -- A later gameweek makes the first report older than the current reporting window.
  -- Rejected work must remain active and resubmittable even after the deadline.
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,992,1,v_home_season_team,v_away_season_team,v_location,v_future_two,'scheduled')
  returning id into v_fixture_two;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_assignment:=public.admin_assign_referee_to_fixture(v_fixture_two,v_referee,'lead');
  execute 'reset role';

  perform set_config('request.jwt.claim.role','service_role',true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked)
  values(v_fixture_two,v_home_season_team,v_admin,true) returning id into v_home_sheet_two;
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked)
  values(v_fixture_two,v_away_season_team,v_admin,true) returning id into v_away_sheet_two;
  insert into public.fixture_team_sheet_players(team_sheet_id,user_id,competition_player_id,role,is_goalkeeper,did_appear)
  values
    (v_home_sheet_two,v_home_user,v_home_identity,'starter',false,true),
    (v_away_sheet_two,v_away_user,v_away_identity,'starter',false,true);
  perform set_config('request.jwt.claim.role','authenticated',true);

  -- Create team sheets before simulating the completed match; kickoff lock remains enforced.
  update public.fixtures set scheduled_at=now()-interval '2 days',status='in_progress' where id=v_fixture_two;

  -- Initial referee reports after the 24-hour deadline are blocked.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_referee::text,true);
  v_rejected:=false;
  begin
    perform public.submit_referee_match_report(v_fixture_two,0,0,'{}'::uuid[],'{}'::uuid[],'{}'::uuid[],'{}'::uuid[],'[]'::jsonb,null);
  exception when others then v_rejected:=true;
  end;
  if not v_rejected then raise exception 'Initial referee report was accepted after the 24-hour deadline'; end if;

  -- Rejected report resubmission remains allowed even though its gameweek is no longer latest.
  execute 'reset role';
  update public.players set disciplinary_strikes=2,disciplinary_inactive=false where user_id=v_home_user;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_referee::text,true);
  v_report_one:=public.submit_referee_match_report(
    v_fixture_one,1,0,'{}'::uuid[],'{}'::uuid[],array[v_home_identity],'{}'::uuid[],v_events,
    'Corrected match report after administrator feedback.'
  );
  if (public.get_my_referee_fixture_report_options(v_fixture_one)->'report'->>'status')<>'submitted' then
    raise exception 'Rejected report did not return to active referee work';
  end if;
  execute 'reset role';

  -- An administrator can take over and report any completed fixture after the deadline.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_report_two:=public.admin_submit_referee_match_report(
    v_fixture_two,0,0,'{}'::uuid[],'{}'::uuid[],'{}'::uuid[],'{}'::uuid[],'[]'::jsonb,
    'Administrative result entry after referee deadline.','Referee reporting window expired'
  );
  select count(*) into v_count from public.admin_list_referee_match_reports('submitted',v_location);
  if v_count<>2 then raise exception 'Administrator report queue did not include both submitted reports'; end if;
  execute 'reset role';

  -- The match is now complete. Admin result publication may update the locked
  -- appearance rows only after the fixture has entered its completed state.
  update public.fixtures set status='completed' where id in (v_fixture_one,v_fixture_two);

  -- Admin report-entry selectors expose only completed, locked-sheet fixtures
  -- within the caller's location scope, and return identity-safe player options.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  select count(*) into v_count from public.admin_list_referee_reportable_fixtures(null);
  if v_count<>2 then raise exception 'Admin report-entry fixture selector did not return both eligible fixtures'; end if;
  select public.admin_get_referee_fixture_report_options(v_fixture_one) into v_options;
  if jsonb_array_length(v_options->'home_players')<>1
     or jsonb_array_length(v_options->'away_players')<>1
     or v_options->'report'->>'status'<>'submitted' then
    raise exception 'Admin report-entry options did not return the locked team-sheet players and existing report';
  end if;
  execute 'reset role';

  -- Approval creates the official result, permanent cards, team fines and one £22 payout obligation.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform public.admin_review_referee_match_report(v_report_one,'approved','Report and card details verified');
  execute 'reset role';
  if not exists(
    select 1 from public.notification_events
    where user_id=v_referee and event_type='referee.report.approved'
      and payload->>'report_id'=v_report_one::text
  ) then raise exception 'Approved referee report did not enqueue a notification'; end if;
  if not exists(select 1 from public.fixture_results where fixture_id=v_fixture_one and home_score=1 and away_score=0 and confirmed_at is not null) then
    raise exception 'Approved referee report did not publish the official fixture result';
  end if;
  if (select count(*) from public.referee_disciplinary_events where report_id=v_report_one)<>3 then
    raise exception 'Approved referee report did not create all three permanent card records';
  end if;
  select coalesce(sum(amount_pence),0) into v_amount from public.finance_entries
    where fixture_id=v_fixture_one and entry_type='fine';
  if v_amount<>5000 then raise exception 'Card fines were not charged to the correct team ledgers'; end if;
  if not exists(select 1 from public.players where user_id=v_home_user and disciplinary_strikes=3 and disciplinary_inactive=true) then
    raise exception 'Third straight-red strike did not make the player inactive';
  end if;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  select count(*) into v_count from public.admin_list_referee_report_payouts('pending_connect',v_location)
    where report_id=v_report_one and gross_allocation_pence=2200 and referee_net_pence=2200 and status='pending_connect';
  execute 'reset role';
  if v_count<>1 then raise exception 'Location-scoped referee payout queue did not return the pending £22 obligation'; end if;

  if (select count(*) from public.referee_report_payouts where report_id=v_report_one and gross_allocation_pence=2200 and deductions_pence=0 and referee_net_pence=2200 and open_play_top_up_pence=0 and status='pending_connect')<>1 then
    raise exception 'Approved referee report did not create exactly one £22 payout obligation';
  end if;

  -- Duplicate approval cannot create another result, fine or payout.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_rejected:=false;
  begin
    perform public.admin_review_referee_match_report(v_report_one,'approved','Duplicate approval attempt');
  exception when others then v_rejected:=true;
  end;
  execute 'reset role';
  if not v_rejected then raise exception 'An approved referee report was approved twice'; end if;
  if (select count(*) from public.referee_report_payouts where report_id=v_report_one)<>1 then
    raise exception 'Duplicate approval created a second referee payout';
  end if;

  -- Admin takeover is not a referee assignment and therefore creates no referee payout.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform public.admin_review_referee_match_report(v_report_two,'approved','Administrative result verified');
  execute 'reset role';
  if exists(select 1 from public.referee_report_payouts where report_id=v_report_two) then
    raise exception 'Administrative report incorrectly generated a referee payout';
  end if;

  -- Create a future fixture for the disciplinary guard test. The prior fixtures
  -- are completed, so their team sheets are correctly locked against amendments.
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,993,1,v_home_season_team,v_away_season_team,v_location,now()+interval '6 days','scheduled')
  returning id into v_fixture_three;
  perform set_config('request.jwt.claim.role','service_role',true);
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked)
  values(v_fixture_three,v_home_season_team,v_admin,true) returning id into v_home_sheet_three;
  insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,is_locked)
  values(v_fixture_three,v_away_season_team,v_admin,true) returning id into v_away_sheet_three;
  perform set_config('request.jwt.claim.role','authenticated',true);

  -- The disciplinary trigger must reject an inactive player even on a future
  -- sheet. Use the trusted service-role claim to isolate this trigger from the
  -- separate captain/next-fixture authorization trigger.
  perform set_config('request.jwt.claim.role','service_role',true);
  v_rejected:=false;
  begin
    insert into public.fixture_team_sheet_players(team_sheet_id,user_id,competition_player_id,role,is_goalkeeper,did_appear)
    values(v_home_sheet_three,v_home_user,v_home_identity,'substitute',false,false);
  exception when others then
    v_rejected:=sqlerrm like '%disciplinary strikes%';
  end;
  perform set_config('request.jwt.claim.role','authenticated',true);
  if not v_rejected then raise exception 'The disciplinary team-sheet guard did not block the inactive player'; end if;

  -- Reactivation is audited and does not erase the permanent strike record.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform public.admin_reactivate_disciplined_player(v_home_identity,'Administrator reviewed and approved reactivation');
  execute 'reset role';
  if not exists(select 1 from public.players where user_id=v_home_user and disciplinary_strikes=3 and disciplinary_inactive=false) then
    raise exception 'Administrator reactivation erased strikes or left the player inactive';
  end if;
  execute 'reset role';

  -- Correcting an approved report preserves the original incidents, offsets their
  -- fine liabilities with append-only credits, and applies only the corrected cards.
  v_corrected_events:=jsonb_build_array(
    jsonb_build_object('season_team_id',v_away_season_team,'recipient_type','bench',
      'card_type','yellow','minute',40,'description','Corrected bench caution'),
    jsonb_build_object('season_team_id',v_home_season_team,'recipient_type','supporter',
      'card_type','second_yellow_red','minute',60,'description','Corrected supporter misconduct')
  );
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_corrected_version:=public.admin_correct_approved_referee_match_report(
    v_report_one,2,1,0,'{}'::uuid[],'{}'::uuid[],array[v_home_identity],'{}'::uuid[],
    v_corrected_events,'Corrected match summary','The original card record was entered incorrectly; corrected after review'
  );
  execute 'reset role';
  if v_corrected_version<>3 then raise exception 'Approved report correction did not advance the version'; end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_correction_options:=public.admin_get_approved_referee_report_correction_options(v_report_one);
  execute 'reset role';
  if v_correction_options->'report'->>'status'<>'approved'
     or (v_correction_options->'report'->>'version')::integer<>3
     or jsonb_array_length(v_correction_options->'home_players')<>1
     or jsonb_array_length(v_correction_options->'away_players')<>1 then
    raise exception 'Approved report correction interface did not receive the current version and both locked team-sheet player lists';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_referee::text,true);
  v_rejected:=false;
  begin
    perform public.admin_get_approved_referee_report_correction_options(v_report_one);
  exception when others then
    v_rejected:=sqlerrm like '%Administrator permission required%';
  end;
  if not v_rejected then raise exception 'A referee could read the administrator-only approved-report correction options'; end if;
  execute 'reset role';
  if not exists(select 1 from public.referee_match_reports where id=v_report_one and status='approved' and version=3 and jsonb_array_length(disciplinary_events)=2) then
    raise exception 'Corrected report did not remain approved with its corrected events'; end if;
  if (select count(*) from public.referee_disciplinary_events where report_id=v_report_one and voided_at is null)<>2
     or (select count(*) from public.referee_disciplinary_events where report_id=v_report_one and voided_at is not null)<>3 then
    raise exception 'Correction did not preserve the three original voided incidents and two corrected active incidents'; end if;
  if not exists(select 1 from public.players where user_id=v_home_user and disciplinary_strikes=2 and disciplinary_inactive=false) then
    raise exception 'Correction did not reverse the erroneous straight-red strike'; end if;
  select coalesce(sum(amount_pence) filter(where entry_type='fine'),0)
       - coalesce(sum(amount_pence) filter(where entry_type='credit'),0)
    into v_amount
    from public.finance_entries where fixture_id=v_fixture_one;
  if v_amount<>2000 then raise exception 'Fine correction did not reconcile the team ledger to the corrected £20 total'; end if;
  if (select count(*) from public.referee_report_payouts where report_id=v_report_one and gross_allocation_pence=2200 and referee_net_pence=2200)<>1 then
    raise exception 'Correcting a report duplicated or changed the original referee payout entitlement'; end if;

  -- Optimistic version checking prevents a stale retry from posting a second credit.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_rejected:=false;
  begin
    perform public.admin_correct_approved_referee_match_report(
      v_report_one,2,1,0,'{}'::uuid[],'{}'::uuid[],array[v_home_identity],'{}'::uuid[],
      v_corrected_events,'Corrected match summary','Stale duplicate correction attempt'
    );
  exception when others then
    v_rejected:=sqlerrm like '%report has changed since it was loaded%';
  end;
  execute 'reset role';
  if not v_rejected then raise exception 'A stale duplicate correction was not rejected'; end if;
  if (select count(*) from public.finance_entries where fixture_id=v_fixture_one and entry_type='credit')<>3 then
    raise exception 'A stale correction retry created duplicate finance credits'; end if;

  if (select count(*) from public.referee_match_report_history where report_id=v_report_one)<>4 then
    raise exception 'Rejection, resubmission, approval and correction history was not preserved';
  end if;
end;
$referee_match_reports$;

-- Location-scoped disciplinary return queue uses the existing players/event ledger.
do $disciplinary_return_queue$
declare
  v_definition text;
begin
  if not has_function_privilege('authenticated','public.admin_list_disciplinary_suspensions(uuid)','execute')
     or has_function_privilege('anon','public.admin_list_disciplinary_suspensions(uuid)','execute') then
    raise exception 'Disciplinary return queue grants are incorrect';
  end if;
  select pg_get_functiondef('public.admin_list_disciplinary_suspensions(uuid)'::regprocedure)
    into v_definition;
  if position('has_platform_role' in v_definition)=0
     or position('can_administer_location' in v_definition)=0
     or position('referee_disciplinary_events' in v_definition)=0
     or position('disciplinary_inactive' in v_definition)=0 then
    raise exception 'Disciplinary return queue must be platform-role and location scoped over approved events';
  end if;

  if not has_function_privilege('authenticated','public.admin_reactivate_disciplined_player(uuid,text)','execute')
     or has_function_privilege('anon','public.admin_reactivate_disciplined_player(uuid,text)','execute') then
    raise exception 'Disciplinary reactivation grants are incorrect';
  end if;
  select pg_get_functiondef('public.admin_reactivate_disciplined_player(uuid,text)'::regprocedure)
    into v_definition;
  if position('referee_disciplinary_events' in v_definition)=0
     or position('can_administer_location' in v_definition)=0
     or position('disciplinary_inactive' in v_definition)=0
     or position('enqueue_notification_event' in v_definition)=0
     or position('length(btrim(coalesce(p_reason' in v_definition)=0 then
    raise exception 'Disciplinary reactivation must use historical location scope, preserve strike history, audit and notify';
  end if;
end;
$disciplinary_return_queue$;

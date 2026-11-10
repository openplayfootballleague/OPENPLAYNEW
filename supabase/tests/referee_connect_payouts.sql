-- Stripe Connect account readiness, match-report transfers, milestone transfers,
-- reversal/retry and webhook-idempotent state transitions.
do $referee_connect_payouts$
declare
  v_admin constant uuid:='97000000-0000-4000-8000-000000000001';
  v_referee constant uuid:='97000000-0000-4000-8000-000000000002';
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_home_team uuid;
  v_away_team uuid;
  v_home_season_team uuid;
  v_away_season_team uuid;
  v_fixture uuid;
  v_application uuid;
  v_report uuid;
  v_match_payout uuid;
  v_milestone_payout uuid;
  v_account_id constant text:='acct_ci_referee_connect_000001';
  v_claim jsonb;
  v_status text;
  v_rejected boolean;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-connect-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_referee,'authenticated','authenticated','ci-connect-referee@openplay.invalid','','{}'::jsonb,now(),now(),now());
  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'admin',v_admin);

  select id into v_location from public.locations where is_active=true order by created_at limit 1;
  if v_location is null then raise exception 'Expected an active location from earlier database regressions'; end if;
  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Referee Connect League','ci-referee-connect-league',false)
  returning id into v_league;
  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Referee Connect Season',994,'active',false)
  returning id into v_season;

  insert into public.teams(created_by) values(v_admin) returning id into v_home_team;
  insert into public.teams(created_by) values(v_admin) returning id into v_away_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values
    (v_home_team,v_season,'Connect Home','ci-connect-home','approved',now(),v_admin),
    (v_away_team,v_season,'Connect Away','ci-connect-away','approved',now(),v_admin);
  select id into v_home_season_team from public.season_teams where slug='ci-connect-home';
  select id into v_away_season_team from public.season_teams where slug='ci-connect-away';

  insert into public.referee_applications(
    user_id,status,experience_summary,qualifications,availability,contact_phone,preferred_location_ids,
    submitted_at,reviewed_at,reviewed_by,review_reason
  ) values(
    v_referee,'approved','CI referee Connect test','{}'::text[],
    (select jsonb_agg(jsonb_build_object('weekday',day_no,'start_time','00:00','end_time','23:59'))
      from generate_series(1,7) day_no),
    '+44770090901',array[v_location],now(),now(),v_admin,'CI approved referee'
  ) returning id into v_application;
  insert into public.referee_memberships(user_id,application_id,status,approved_by,status_changed_by,status_reason)
  values(v_referee,v_application,'active',v_admin,v_admin,'CI active referee membership');

  insert into public.fixtures(
    season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status
  ) values(
    v_season,1,1,v_home_season_team,v_away_season_team,v_location,now()-interval '1 day','completed'
  ) returning id into v_fixture;
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by)
  values(v_fixture,0,0,now(),v_admin);
  insert into public.referee_match_reports(
    fixture_id,referee_user_id,report_source,submitted_by,status,
    home_score,away_score,reviewed_at,reviewed_by,approved_at,approved_by
  ) values(
    v_fixture,v_referee,'referee',v_referee,'approved',0,0,now(),v_admin,now(),v_admin
  ) returning id into v_report;
  insert into public.referee_report_payouts(
    report_id,referee_user_id,gross_allocation_pence,deductions_pence,
    referee_net_pence,open_play_top_up_pence,status
  ) values(v_report,v_referee,2200,0,2200,0,'pending_connect')
  returning id into v_match_payout;

  insert into public.referee_milestone_rewards(
    referee_user_id,milestone_number,approved_games,amount_pence,status
  ) values(v_referee,1,50,5000,'pending_connect')
  returning id into v_milestone_payout;

  -- A connected account without payouts enabled cannot receive an admin transfer.
  execute 'set local role service_role';
  perform public.sync_referee_connect_account(
    v_referee,v_account_id,true,true,false,false,
    jsonb_build_object('currently_due',jsonb_build_array('external_account')),'requirements.pending'
  );
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_rejected:=false;
  begin
    perform public.claim_referee_payout_transfer('match_report',v_match_payout);
  exception when others then
    v_rejected:=sqlerrm like '%complete Stripe Connect verification%';
  end;
  if not v_rejected then raise exception 'Payout was claimable before the referee enabled bank payouts'; end if;
  execute 'reset role';

  execute 'set local role service_role';
  perform public.sync_referee_connect_account(
    v_referee,v_account_id,true,true,true,false,
    '{}'::jsonb,null
  );
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_referee::text,true);
  if public.get_my_referee_connect_status()->>'onboarding_status'<>'enabled'
     or (public.get_my_referee_connect_status()->>'payouts_enabled')::boolean is not true then
    raise exception 'Referee Connect status did not expose the verified payout state';
  end if;
  v_rejected:=false;
  begin
    perform public.claim_referee_payout_transfer('match_report',v_match_payout);
  exception when others then
    v_rejected:=sqlerrm like '%Finance access required%';
  end;
  if not v_rejected then raise exception 'A referee was able to claim an administrator payout transfer'; end if;
  execute 'reset role';

  -- Match-report transfer is scoped to finance admin and location, and reconciles idempotently.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_claim:=public.claim_referee_payout_transfer('match_report',v_match_payout);
  if v_claim->>'stripe_account_id'<>v_account_id
     or (v_claim->>'amount_pence')::integer<>2200
     or (v_claim->>'attempt')::integer<>1 then
    raise exception 'Match-report payout claim did not return the exact approved transfer details';
  end if;
  execute 'reset role';

  execute 'set local role service_role';
  v_status:=public.record_referee_payout_transfer_success(
    'match_report',v_match_payout,'tr_ci_referee_match_000001',v_account_id,2200,'gbp'
  );
  perform public.record_referee_payout_transfer_success(
    'match_report',v_match_payout,'tr_ci_referee_match_000001',v_account_id,2200,'gbp'
  );
  if v_status<>'transferred'
     or (select status from public.referee_report_payouts where id=v_match_payout)<>'transferred' then
    raise exception 'Match-report Stripe transfer was not recorded as transferred';
  end if;

  -- A reversed transfer becomes retryable; the next attempt gets a new idempotency attempt number.
  perform public.record_referee_payout_transfer_failure(
    'match_report',v_match_payout,'Stripe transfer reversed',true
  );
  -- Out-of-order transfer.created delivery must not overwrite a recorded reversal.
  v_status:=public.record_referee_payout_transfer_success(
    'match_report',v_match_payout,'tr_ci_referee_match_000001',v_account_id,2200,'gbp'
  );
  if v_status<>'reversed'
     or (select status from public.referee_report_payouts where id=v_match_payout)<>'failed' then
    raise exception 'A delayed transfer.created webhook incorrectly overwrote the reversal';
  end if;
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_claim:=public.claim_referee_payout_transfer('match_report',v_match_payout);
  if (v_claim->>'attempt')::integer<>2 then
    raise exception 'Reversed transfer retry did not increment the attempt number';
  end if;
  execute 'reset role';
  execute 'set local role service_role';
  perform public.record_referee_payout_transfer_success(
    'match_report',v_match_payout,'tr_ci_referee_match_000002',v_account_id,2200,'gbp'
  );

  -- Milestone rewards use the same verified Connect account and transfer safeguards.
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_claim:=public.claim_referee_payout_transfer('milestone',v_milestone_payout);
  if (v_claim->>'amount_pence')::integer<>5000 then
    raise exception 'Milestone transfer amount did not match the £50 reward';
  end if;
  execute 'reset role';
  execute 'set local role service_role';
  perform public.record_referee_payout_transfer_success(
    'milestone',v_milestone_payout,'tr_ci_referee_milestone_000001',v_account_id,5000,'gbp'
  );
  if (select status from public.referee_milestone_rewards where id=v_milestone_payout)<>'transferred' then
    raise exception 'Milestone Connect transfer was not recorded';
  end if;
  if (select count(*) from public.referee_payout_transfer_history
      where payout_type='match_report' and payout_id=v_match_payout)<>2
     or not exists(select 1 from public.referee_payout_transfer_history
       where payout_type='match_report' and payout_id=v_match_payout
         and stripe_transfer_id='tr_ci_referee_match_000001' and status='reversed') then
    raise exception 'Transfer history did not retain both the reversed and successful retry attempts';
  end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  if (select count(*) from public.admin_list_referee_report_payouts_connect('all')
      where payout_id=v_match_payout)<>1 then
    raise exception 'Finance queue did not expose the match-report payout and Connect state';
  end if;
  if (select count(*) from public.admin_list_referee_milestone_rewards_connect('all')
      where reward_id=v_milestone_payout)<>1 then
    raise exception 'Finance queue did not expose the milestone reward and Connect state';
  end if;
  execute 'reset role';
end;
$referee_connect_payouts$;

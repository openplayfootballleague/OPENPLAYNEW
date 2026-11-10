-- Team weekly payment deadlines, strikes, cancellation and refund-ledger regression.
-- Runs only against the disposable local Supabase database created by CI.
do $team_weekly_payment$
declare
  v_admin constant uuid:='96000000-0000-4000-8000-000000000001';
  v_home_captain constant uuid:='96000000-0000-4000-8000-000000000002';
  v_away_captain constant uuid:='96000000-0000-4000-8000-000000000003';
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_home_team uuid;
  v_away_team uuid;
  v_home_season_team uuid;
  v_away_season_team uuid;
  v_fixture uuid;
  v_home_obligation uuid;
  v_away_obligation uuid;
  v_deadline timestamptz;
  v_grace_ends timestamptz;
  v_status text;
  v_refund uuid;
  v_count integer;
  v_attempt integer;
  v_claimed boolean;
  v_rejected boolean;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-team-payment-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_home_captain,'authenticated','authenticated','ci-team-payment-home@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_away_captain,'authenticated','authenticated','ci-team-payment-away@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned,is_genuine)
  values
    (v_home_captain,'Team Payment Home Captain','07700900810','ci-team-payment-home-player@openplay.invalid',date '1990-03-10','registered',false,true),
    (v_away_captain,'Team Payment Away Captain','07700900811','ci-team-payment-away-player@openplay.invalid',date '1990-03-11','registered',false,true);

  insert into public.user_roles(user_id,role,granted_by)
  values(v_admin,'admin',v_admin);

  select id into v_location from public.locations where is_active=true order by created_at limit 1;
  if v_location is null then raise exception 'Expected an active location from earlier database regressions'; end if;

  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Team Payment League','ci-team-payment-league',false)
  returning id into v_league;
  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Team Payment Season',993,'active',false)
  returning id into v_season;

  insert into public.teams(created_by) values(v_admin) returning id into v_home_team;
  insert into public.teams(created_by) values(v_admin) returning id into v_away_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values
    (v_home_team,v_season,'Payment Home','ci-payment-home','approved',now(),v_admin),
    (v_away_team,v_season,'Payment Away','ci-payment-away','approved',now(),v_admin);
  select id into v_home_season_team from public.season_teams where slug='ci-payment-home';
  select id into v_away_season_team from public.season_teams where slug='ci-payment-away';

  insert into public.team_memberships(season_team_id,user_id,status,is_captain,joined_at)
  values
    (v_home_season_team,v_home_captain,'active',true,now()),
    (v_away_season_team,v_away_captain,'active',true,now());

  insert into public.season_fee_configs(season_id,team_fee_pence,effective_from_gameweek,reason,changed_by)
  values(v_season,3500,1,'CI team payment fee',v_admin);

  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,1,1,v_home_season_team,v_away_season_team,v_location,now()+interval '3 days','scheduled')
  returning id into v_fixture;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  select payment.obligation_id,payment.deadline_at,payment.grace_ends_at
    into v_home_obligation,v_deadline,v_grace_ends
  from public.create_team_fixture_payment_obligation(v_fixture,v_home_season_team) payment;
  -- A duplicate captain retry must return the same obligation and never duplicate the charge.
  if (select count(*) from public.create_team_fixture_payment_obligation(v_fixture,v_home_season_team))<>1 then
    raise exception 'Idempotent home obligation retry did not return one row';
  end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_away_captain::text,true);
  select obligation_id into v_away_obligation
  from public.create_team_fixture_payment_obligation(v_fixture,v_away_season_team);
  execute 'reset role';

  if (select amount_pence from public.team_fixture_payment_obligations where id=v_home_obligation)<>3500 then
    raise exception 'Team fee was not snapshotted from the season configuration';
  end if;
  if v_deadline<>(select scheduled_at from public.fixtures where id=v_fixture)-interval '24 hours'
     or v_grace_ends<>(select scheduled_at from public.fixtures where id=v_fixture)-interval '12 hours' then
    raise exception 'The 24-hour deadline or 12-hour grace boundary is incorrect';
  end if;
  if (select count(*) from public.finance_entries where fixture_id=v_fixture and entry_type='charge')<>2 then
    raise exception 'Each team must receive exactly one append-only fee charge';
  end if;

  -- Stripe Checkout retries use compare-and-set attempts and never attach stale sessions.
  execute 'set local role service_role';
  select public.claim_team_fixture_payment_checkout_attempt(v_home_obligation,null) into v_attempt;
  if v_attempt<>1 then raise exception 'First checkout attempt number is incorrect'; end if;
  select public.set_team_fixture_payment_checkout_session(v_home_obligation,v_attempt,'cs_test_team_payment_001') into v_claimed;
  if not v_claimed then raise exception 'First checkout session was not attached'; end if;
  select public.claim_team_fixture_payment_checkout_attempt(v_home_obligation,'cs_test_team_payment_001') into v_attempt;
  if v_attempt<>2 then raise exception 'Expired checkout retry did not increment its attempt'; end if;
  select public.set_team_fixture_payment_checkout_session(v_home_obligation,v_attempt,'cs_test_team_payment_002') into v_claimed;
  if not v_claimed then raise exception 'Replacement checkout session was not attached'; end if;
  select public.clear_team_fixture_payment_checkout_session(v_home_obligation,'cs_test_team_payment_002') into v_claimed;
  if not v_claimed then raise exception 'Expired checkout session could not be cleared'; end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_rejected:=false;
  begin
    perform (select count(*) from public.team_stripe_webhook_events);
  exception when insufficient_privilege then
    v_rejected:=true;
  end;
  if not v_rejected then raise exception 'Authenticated clients must not read the team Stripe webhook inbox'; end if;
  execute 'reset role';

  -- The away team pays on time; the later weather/default workflow must refund it if its opponent defaults.
  execute 'set local role service_role';
  perform public.record_team_fixture_payment_success(v_away_obligation,'pi_ci_team_payment_away_001',v_deadline-interval '1 minute');
  select public.process_team_fixture_payment_deadlines(v_deadline) into v_count;
  if (select status from public.team_fixture_payment_obligations where id=v_home_obligation)<>'grace_period' then
    raise exception 'Payment did not enter the grace period at the exact 24-hour deadline';
  end if;
  if exists(select 1 from public.team_payment_strikes where obligation_id=v_home_obligation) then
    raise exception 'A payment strike was applied before the grace period ended';
  end if;

  select public.process_team_fixture_payment_deadlines(v_grace_ends) into v_count;
  if (select status from public.team_fixture_payment_obligations where id=v_home_obligation)<>'defaulted' then
    raise exception 'Unpaid team was not defaulted at the exact end of the 12-hour grace period';
  end if;
  if (select status from public.fixtures where id=v_fixture)<>'cancelled' then
    raise exception 'Fixture was not cancelled after the unpaid grace period';
  end if;
  if (select count(*) from public.team_payment_strikes where obligation_id=v_home_obligation)<>1 then
    raise exception 'Default must create exactly one team payment strike';
  end if;
  if (select status from public.team_fixture_payment_obligations where id=v_away_obligation)<>'refund_pending' then
    raise exception 'The compliant opponent payment was not queued for refund';
  end if;
  select id into v_refund from public.team_fixture_payment_refunds where obligation_id=v_away_obligation;
  if v_refund is null then raise exception 'A refund obligation was not created for the paid opponent'; end if;

  -- Payment after cancellation settles the defaulting team's debt but never reinstates the fixture.
  v_status:=public.record_team_fixture_payment_success(
    v_home_obligation,'pi_ci_team_payment_home_001',v_grace_ends+interval '1 minute');
  if v_status<>'paid_after_cancellation' then
    raise exception 'Payment after the grace period must not reinstate the fixture';
  end if;
  if (select status from public.fixtures where id=v_fixture)<>'cancelled' then
    raise exception 'Late payment incorrectly reinstated a cancelled fixture';
  end if;
  perform public.record_team_fixture_payment_success(
    v_home_obligation,'pi_ci_team_payment_home_001',v_grace_ends+interval '1 minute');
  if (select count(*) from public.finance_entries
      where fixture_id=v_fixture and entry_type='payment' and reference='pi_ci_team_payment_home_001')<>1 then
    raise exception 'Duplicate payment webhook created duplicate finance entries';
  end if;
  if (select count(*) from public.team_payment_strikes where obligation_id=v_home_obligation)<>1 then
    raise exception 'Duplicate payment webhook created a duplicate strike';
  end if;

  perform public.record_team_fixture_payment_refund_result(
    v_refund,true,'re_ci_team_payment_away_001',null);
  if (select status from public.team_fixture_payment_obligations where id=v_away_obligation)<>'refunded' then
    raise exception 'Confirmed opponent refund did not update the payment obligation';
  end if;
  if (select count(*) from public.finance_entries
      where fixture_id=v_fixture and season_team_id=v_away_season_team and entry_type='refund')<>1
     or (select count(*) from public.finance_entries
      where fixture_id=v_fixture and season_team_id=v_away_season_team and entry_type='credit')<>1 then
    raise exception 'Confirmed refund must record both the cash refund and the matching fee-waiver credit';
  end if;
  if (select team_balance_pence from public.get_finance_ledger(v_season,v_away_season_team)
      where fixture_id=v_fixture and entry_type='credit' limit 1)<>0 then
    raise exception 'Paid team balance must return to zero after its Stripe refund and fee waiver';
  end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  if (select count(*) from public.get_admin_team_fixture_payment_queue(v_season))<>2 then
    raise exception 'Finance administrator queue did not return both team obligations';
  end if;
  execute 'reset role';

  if (select count(*) from public.team_fixture_payment_history where obligation_id in (v_home_obligation,v_away_obligation))<6 then
    raise exception 'Payment lifecycle history is incomplete';
  end if;
end;
$team_weekly_payment$;

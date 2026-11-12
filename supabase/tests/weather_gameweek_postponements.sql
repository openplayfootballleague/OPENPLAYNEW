-- Weather postponement: stable gameweek IDs, full refunds, unpaid-cycle credits,
-- replacement payment cycles and chronological renumbering.
do $weather_gameweek$
declare
  v_admin constant uuid:='98100000-0000-4000-8000-000000000001';
  v_home_captain constant uuid:='98100000-0000-4000-8000-000000000002';
  v_away_captain constant uuid:='98100000-0000-4000-8000-000000000003';
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_home_team uuid;
  v_away_team uuid;
  v_home_season_team uuid;
  v_away_season_team uuid;
  v_week_one_fixture uuid;
  v_week_two_fixture uuid;
  v_week_two_completed_fixture uuid;
  v_week_three_fixture uuid;
  v_week_four_fixture uuid;
  v_week_four_id uuid;
  v_home_old_obligation uuid;
  v_away_old_obligation uuid;
  v_home_new_obligation uuid;
  v_away_new_obligation uuid;
  v_deadline timestamptz;
  v_replacement timestamptz:=now()+interval '10 days';
  v_result jsonb;
  v_retry_result jsonb;
  v_admin_weeks integer;
  v_list_fixture_count bigint;
  v_list_paid_team_count bigint;
begin
  -- Deadline processing must never refund a receipt from a superseded cycle
  -- after a gameweek has been postponed and a replacement cycle created.
  if position('order by payment_cycle desc' in pg_get_functiondef(
    'public.process_team_fixture_payment_deadlines(timestamptz)'::regprocedure
  ))=0 then
    raise exception 'Opponent refunds must select the latest payment cycle only';
  end if;

  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-weather-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_home_captain,'authenticated','authenticated','ci-weather-home@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_away_captain,'authenticated','authenticated','ci-weather-away@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned,is_genuine)
  values
    (v_home_captain,'Weather Home Captain','07700900820','ci-weather-home-player@openplay.invalid',date '1990-04-10','registered',false,true),
    (v_away_captain,'Weather Away Captain','07700900821','ci-weather-away-player@openplay.invalid',date '1990-04-11','registered',false,true);
  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'admin',v_admin);

  -- Keep this regression independent of seed data and the execution order of other SQL tests.
  -- Test-only location remains inactive to respect the first-release
  -- single-active-location constraint while keeping fixture data isolated.
  insert into public.locations(name,slug,town,region,is_active)
  values('Weather Postponement Test Location','ci-weather-postponement-test-location','Bideford','Devon',false)
  returning id into v_location;
  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Weather Postponement League','ci-weather-postponement-league',false)
  returning id into v_league;
  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Weather Postponement Season',994,'active',false)
  returning id into v_season;

  insert into public.teams(created_by) values(v_admin) returning id into v_home_team;
  insert into public.teams(created_by) values(v_admin) returning id into v_away_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values
    (v_home_team,v_season,'Weather Home','ci-weather-home','approved',now(),v_admin),
    (v_away_team,v_season,'Weather Away','ci-weather-away','approved',now(),v_admin);
  select id into v_home_season_team from public.season_teams where slug='ci-weather-home';
  select id into v_away_season_team from public.season_teams where slug='ci-weather-away';
  insert into public.team_memberships(season_team_id,user_id,status,is_captain,joined_at)
  values
    (v_home_season_team,v_home_captain,'active',true,now()),
    (v_away_season_team,v_away_captain,'active',true,now());
  insert into public.season_fee_configs(season_id,team_fee_pence,effective_from_gameweek,reason,changed_by)
  values(v_season,3500,1,'CI weather postponement fee',v_admin);

  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values
    (v_season,1,1,v_home_season_team,v_away_season_team,v_location,now()-interval '7 days','completed'),
    (v_season,2,1,v_home_season_team,v_away_season_team,v_location,now()+interval '7 days','scheduled'),
    (v_season,2,2,v_away_season_team,v_home_season_team,v_location,now()+interval '8 days','completed'),
    (v_season,3,1,v_home_season_team,v_away_season_team,v_location,now()+interval '14 days','scheduled'),
    (v_season,4,1,v_home_season_team,v_away_season_team,v_location,now()+interval '21 days','scheduled');

  select id into v_week_one_fixture from public.fixtures where season_id=v_season and gameweek=1;
  select id into v_week_two_fixture from public.fixtures where season_id=v_season and gameweek=2 and fixture_number=1;
  select id into v_week_two_completed_fixture from public.fixtures where season_id=v_season and gameweek=2 and fixture_number=2;
  select id into v_week_three_fixture from public.fixtures where season_id=v_season and gameweek=3;
  select id,gameweek_id into v_week_four_fixture,v_week_four_id
    from public.fixtures where season_id=v_season and gameweek=4;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  select obligation_id into v_home_old_obligation
  from public.create_team_fixture_payment_obligation(v_week_four_fixture,v_home_season_team);
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_away_captain::text,true);
  select obligation_id,deadline_at into v_away_old_obligation,v_deadline
  from public.create_team_fixture_payment_obligation(v_week_four_fixture,v_away_season_team);
  execute 'reset role';

  execute 'set local role service_role';
  perform public.record_team_fixture_payment_success(
    v_away_old_obligation,'pi_ci_weather_away_001',v_deadline-interval '1 minute');
  execute 'reset role';

  -- Captains may create their own payment obligations but must not enumerate or
  -- postpone a whole gameweek through the administrator-only API.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  begin
    perform count(*) from public.get_admin_postponable_gameweeks(v_season);
    raise exception 'A team captain was able to enumerate admin-postponable gameweeks';
  exception when others then
    if position('Administrator permission required' in sqlerrm)=0 then raise; end if;
  end;
  begin
    perform public.admin_postpone_gameweek(
      v_week_four_id,v_replacement,'Weather cancellation: captain must be denied'
    );
    raise exception 'A team captain was able to postpone a gameweek';
  exception when others then
    if position('Administrator permission required' in sqlerrm)=0 then raise; end if;
  end;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  select count(*) into v_admin_weeks
  from public.get_admin_postponable_gameweeks(v_season);
  if v_admin_weeks<>2 then raise exception 'Admin gameweek list should exclude the partially completed round'; end if;
  select fixture_count,paid_team_count
    into v_list_fixture_count,v_list_paid_team_count
  from public.get_admin_postponable_gameweeks(v_season)
  where gameweek_id=v_week_four_id;
  if v_list_fixture_count<>1 or v_list_paid_team_count<>1 then
    raise exception 'Postponable gameweek list must count distinct fixtures and paid team obligations';
  end if;

  begin
    perform public.admin_postpone_gameweek(
      v_week_four_id,now()+interval '35 hours','Weather cancellation: replacement too soon'
    );
    raise exception 'A replacement kickoff inside the 36-hour safety window was accepted';
  exception when others then
    if position('36 hours' in sqlerrm)=0 then raise; end if;
  end;

  select public.admin_postpone_gameweek(v_week_four_id,v_replacement,'Weather cancellation: unsafe pitch conditions')
    into v_result;
  select public.admin_postpone_gameweek(v_week_four_id,v_replacement,'Weather cancellation: unsafe pitch conditions')
    into v_retry_result;
  execute 'reset role';

  if coalesce(v_retry_result->>'already_applied','false')<>'true' then
    raise exception 'A duplicate postponement request was not treated idempotently';
  end if;
  if (select max(payment_cycle) from public.team_fixture_payment_obligations
      where fixture_id=v_week_four_fixture)<>2 then
    raise exception 'Duplicate postponement created an extra payment cycle';
  end if;

  if (select gameweek from public.fixtures where id=v_week_one_fixture)<>1 then
    raise exception 'Completed historical gameweek number was changed';
  end if;
  if (select gameweek from public.fixtures where id=v_week_two_fixture)<>2
     or (select gameweek from public.fixtures where id=v_week_two_completed_fixture)<>2 then
    raise exception 'A partially completed historical round must retain its published gameweek number';
  end if;
  if (select gameweek from public.fixtures where id=v_week_four_fixture)<>3 then
    raise exception 'Moved final gameweek was not renumbered into its chronological position';
  end if;
  if (select gameweek from public.fixtures where id=v_week_three_fixture)<>4 then
    raise exception 'The round displaced by the postponed gameweek was not renumbered';
  end if;
  if (select scheduled_at from public.fixtures where id=v_week_four_fixture)<>v_replacement then
    raise exception 'Replacement date was not applied to the postponed gameweek';
  end if;
  if (select gameweek_id from public.fixtures where id=v_week_four_fixture)<>v_week_four_id then
    raise exception 'Stable gameweek identity was not preserved through renumbering';
  end if;

  if (select status from public.team_fixture_payment_obligations where id=v_away_old_obligation)<>'refund_pending' then
    raise exception 'Paid team was not queued for a full refund';
  end if;
  if (select status from public.team_fixture_payment_obligations where id=v_home_old_obligation)<>'cancelled' then
    raise exception 'Unpaid previous-cycle obligation was not cancelled';
  end if;
  if (select count(*) from public.team_fixture_payment_refunds where obligation_id=v_away_old_obligation)<>1 then
    raise exception 'Exactly one Stripe refund obligation should exist for the paid team';
  end if;
  if (select count(*) from public.finance_entries where fixture_id=v_week_four_fixture
      and season_team_id=v_home_season_team and entry_type='credit')<>1 then
    raise exception 'Unpaid old-cycle fee was not credited';
  end if;

  select id into v_home_new_obligation from public.team_fixture_payment_obligations
  where fixture_id=v_week_four_fixture and season_team_id=v_home_season_team and payment_cycle=2;
  select id into v_away_new_obligation from public.team_fixture_payment_obligations
  where fixture_id=v_week_four_fixture and season_team_id=v_away_season_team and payment_cycle=2;
  if v_home_new_obligation is null or v_away_new_obligation is null then
    raise exception 'A fresh payment cycle was not created for both teams';
  end if;
  if exists(select 1 from public.team_fixture_payment_obligations
    where id in (v_home_new_obligation,v_away_new_obligation)
      and (status<>'due' or scheduled_at_snapshot<>v_replacement
        or deadline_at<>v_replacement-interval '24 hours'
        or grace_ends_at<>v_replacement-interval '12 hours')) then
    raise exception 'New payment cycle did not snapshot the replacement date and deadlines';
  end if;
  if (v_result->>'new_week_number')::integer<>3
     or (v_result->>'refunds_queued')::integer<>1
     or (v_result->>'unpaid_cycles_credited')::integer<>1 then
    raise exception 'Postponement summary did not report the correct renumbering and payment reconciliation';
  end if;
  if (select count(*) from public.gameweek_postponement_history where gameweek_id=v_week_four_id)<>1 then
    raise exception 'Weather postponement audit history was not written';
  end if;
  if exists(select 1 from public.team_payment_strikes where fixture_id=v_week_four_fixture) then
    raise exception 'Weather postponement must not create payment strikes';
  end if;
end;
$weather_gameweek$;
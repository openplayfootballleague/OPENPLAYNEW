-- Whole-gameweek weather postponement, fee treatment and chronological renumbering regression.
-- Runs only against the disposable local Supabase database created by CI.
do $weather_postponement$
declare
  v_admin constant uuid:='98000000-0000-4000-8000-000000000001';
  v_home_captain constant uuid:='98000000-0000-4000-8000-000000000002';
  v_away_captain constant uuid:='98000000-0000-4000-8000-000000000003';
  v_home_identity uuid:=gen_random_uuid();
  v_away_identity uuid:=gen_random_uuid();
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_home_team uuid;
  v_away_team uuid;
  v_home_season_team uuid;
  v_away_season_team uuid;
  v_completed_fixture uuid;
  v_weather_fixture uuid;
  v_next_fixture uuid;
  v_last_fixture uuid;
  v_home_obligation uuid;
  v_away_obligation uuid;
  v_new_home_obligation uuid;
  v_new_away_obligation uuid;
  v_deadline timestamptz;
  v_grace timestamptz;
  v_replacement_date date:=(now() at time zone 'Europe/London')::date+30;
  v_replacement_time timestamptz;
  v_original_local_time time;
  v_refund uuid;
  v_postponement uuid;
  v_result jsonb;
  v_rejected boolean:=false;
  v_cycle integer;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-weather-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_home_captain,'authenticated','authenticated','ci-weather-home@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_away_captain,'authenticated','authenticated','ci-weather-away@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'admin',v_admin);
  insert into public.competition_player_identities(id,display_name,counts_for_statistics)
  values
    (v_home_identity,'Weather Home Captain',true),
    (v_away_identity,'Weather Away Captain',true);
  insert into public.players(
    user_id,competition_player_id,full_name,phone,email,date_of_birth,
    registration_status,is_banned,is_genuine
  ) values
    (v_home_captain,v_home_identity,'Weather Home Captain','07700900911',
      'ci-weather-home@openplay.invalid',date '1990-04-11','registered',false,true),
    (v_away_captain,v_away_identity,'Weather Away Captain','07700900912',
      'ci-weather-away@openplay.invalid',date '1990-04-12','registered',false,true);
  select id into v_location from public.locations where is_active=true order by created_at limit 1;
  if v_location is null then raise exception 'Expected an active location from earlier regressions'; end if;

  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Weather League','ci-weather-league',false) returning id into v_league;
  insert into public.seasons(league_id,name,season_number,status,is_public,ends_on)
  values(v_league,'CI Weather Season',994,'active',false,(now() at time zone 'Europe/London')::date+20)
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
  values(v_season,3500,1,'CI weather fee',v_admin);

  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,1,1,v_home_season_team,v_away_season_team,v_location,now()-interval '7 days','completed')
  returning id into v_completed_fixture;
  insert into public.fixture_results(fixture_id,home_score,away_score,confirmed_at,confirmed_by)
  values(v_completed_fixture,1,0,now()-interval '6 days',v_admin);

  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,2,1,v_home_season_team,v_away_season_team,v_location,
    (((now() at time zone 'Europe/London')::date+2)+time '20:00') at time zone 'Europe/London','scheduled')
  returning id into v_weather_fixture;
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,3,1,v_home_season_team,v_away_season_team,v_location,
    (((now() at time zone 'Europe/London')::date+9)+time '20:00') at time zone 'Europe/London','scheduled')
  returning id into v_next_fixture;
  insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,venue_id,scheduled_at,status)
  values(v_season,4,1,v_home_season_team,v_away_season_team,v_location,
    (((now() at time zone 'Europe/London')::date+16)+time '20:00') at time zone 'Europe/London','scheduled')
  returning id into v_last_fixture;
  select (scheduled_at at time zone 'Europe/London')::time into v_original_local_time
  from public.fixtures where id=v_weather_fixture;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  select obligation_id,deadline_at,grace_ends_at into v_home_obligation,v_deadline,v_grace
  from public.create_team_fixture_payment_obligation(v_weather_fixture,v_home_season_team);
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_away_captain::text,true);
  select obligation_id into v_away_obligation
  from public.create_team_fixture_payment_obligation(v_weather_fixture,v_away_season_team);
  execute 'reset role';

  execute 'set local role service_role';
  perform public.record_team_fixture_payment_success(
    v_home_obligation,'pi_ci_weather_paid_home_001',v_deadline-interval '1 minute'
  );
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_result:=public.admin_postpone_gameweek_weather(
    v_season,2,v_replacement_date,'Pitch waterlogged after heavy rainfall'
  );
  v_postponement:=(v_result->>'postponement_id')::uuid;
  execute 'reset role';

  if (select gameweek from public.fixtures where id=v_completed_fixture)<>1 then
    raise exception 'Completed/published gameweek 1 was silently renumbered';
  end if;
  if (select gameweek from public.fixtures where id=v_next_fixture)<>2 then
    raise exception 'The next chronological gameweek was not renumbered to gameweek 2';
  end if;
  if (select gameweek from public.fixtures where id=v_last_fixture)<>3 then
    raise exception 'The following chronological gameweek was not renumbered to gameweek 3';
  end if;
  if (select gameweek from public.fixtures where id=v_weather_fixture)<>4 then
    raise exception 'The postponed gameweek replacement date should become the final gameweek 4';
  end if;
  if ((select scheduled_at from public.fixtures where id=v_weather_fixture)
        at time zone 'Europe/London')::date<>v_replacement_date
     or ((select scheduled_at from public.fixtures where id=v_weather_fixture)
        at time zone 'Europe/London')::time<>v_original_local_time then
    raise exception 'Replacement date did not preserve the original local kickoff time';
  end if;
  if (select status from public.fixtures where id=v_weather_fixture)<>'scheduled' then
    raise exception 'Rescheduled weather fixture should return to scheduled status';
  end if;
  if (select ends_on from public.seasons where id=v_season)<>v_replacement_date then
    raise exception 'Season end date was not extended to include the replacement date';
  end if;

  if (select status from public.team_fixture_payment_obligations where id=v_home_obligation)<>'refund_pending' then
    raise exception 'A paid team was not queued for a full weather refund';
  end if;
  if (select reason from public.team_fixture_payment_refunds where obligation_id=v_home_obligation)<>'weather_postponement' then
    raise exception 'Paid-team refund was not classified as a weather postponement';
  end if;
  select id into v_refund from public.team_fixture_payment_refunds where obligation_id=v_home_obligation;
  execute 'set local role service_role';
  perform public.record_team_fixture_payment_refund_result(v_refund,true,'re_ci_weather_refund_home_001',null);
  execute 'reset role';
  if (select count(*) from public.finance_entries
      where fixture_id=v_weather_fixture and season_team_id=v_home_season_team
        and entry_type='refund')<>1
     or (select count(*) from public.finance_entries
      where fixture_id=v_weather_fixture and season_team_id=v_home_season_team
        and entry_type='credit')<>1 then
    raise exception 'Weather refund must record both the cash refund and the matching fee waiver';
  end if;
  if (select team_balance_pence from public.get_finance_ledger(v_season,v_home_season_team)
      where fixture_id=v_weather_fixture and entry_type='credit' limit 1)<>0 then
    raise exception 'Paid home team balance was not reconciled after the weather refund';
  end if;
  if (select status from public.team_fixture_payment_obligations where id=v_away_obligation)<>'weather_cancelled' then
    raise exception 'An unpaid team was not released from its original fee obligation';
  end if;
  if (select count(*) from public.finance_entries
      where fixture_id=v_weather_fixture and season_team_id=v_away_season_team
        and entry_type='credit' and reference='weather-waiver:'||v_away_obligation::text)<>1 then
    raise exception 'Unpaid weather-cancelled fee was not waived in the finance ledger';
  end if;
  if (select team_balance_pence from public.get_finance_ledger(v_season,v_away_season_team)
      where fixture_id=v_weather_fixture and entry_type='credit' limit 1)<>0 then
    raise exception 'Unpaid team balance was not cleared after weather cancellation';
  end if;
  if exists(select 1 from public.team_payment_strikes
      where obligation_id in (v_home_obligation,v_away_obligation)) then
    raise exception 'Weather postponement must not create payment strikes';
  end if;

  -- The replacement fixture receives a fresh 24-hour/12-hour payment cycle.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_home_captain::text,true);
  select obligation_id into v_new_home_obligation
  from public.create_team_fixture_payment_obligation(v_weather_fixture,v_home_season_team);
  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_away_captain::text,true);
  select obligation_id into v_new_away_obligation
  from public.create_team_fixture_payment_obligation(v_weather_fixture,v_away_season_team);
  execute 'reset role';

  select payment_cycle into v_cycle from public.team_fixture_payment_obligations
  where id=v_new_home_obligation;
  if v_cycle<>2 then raise exception 'Paid team did not receive a fresh payment cycle after rescheduling'; end if;
  select payment_cycle into v_cycle from public.team_fixture_payment_obligations
  where id=v_new_away_obligation;
  if v_cycle<>2 then raise exception 'Unpaid team did not receive a fresh payment cycle after rescheduling'; end if;

  -- A delayed successful webhook for the old checkout must also be refunded, without a strike.
  execute 'set local role service_role';
  perform public.record_team_fixture_payment_success(
    v_away_obligation,'pi_ci_weather_late_away_001',now()
  );
  execute 'reset role';
  if (select status from public.team_fixture_payment_obligations where id=v_away_obligation)<>'refund_pending' then
    raise exception 'Late provider success after weather cancellation was not automatically queued for refund';
  end if;
  if not exists(select 1 from public.team_fixture_payment_refunds
      where obligation_id=v_away_obligation and reason='weather_postponement') then
    raise exception 'Delayed weather-cancelled payment is missing its automatic refund obligation';
  end if;
  if exists(select 1 from public.team_payment_strikes where obligation_id=v_away_obligation) then
    raise exception 'A delayed webhook after weather postponement must not create a payment strike';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_rejected:=false;
  begin
    perform public.admin_postpone_gameweek_weather(
      v_season,1,v_replacement_date,'Attempt to postpone a completed gameweek'
    );
  exception when others then
    v_rejected:=sqlerrm like '%Completed/published gameweeks cannot be silently postponed or renumbered%';
  end;
  if not v_rejected then raise exception 'Completed gameweek postponement was not rejected'; end if;
  if (select count(*) from public.get_admin_weather_postponements(v_season))<>1 then
    raise exception 'Admin weather postponement history did not retain the event';
  end if;
  execute 'reset role';

  if (select count(*) from public.weather_postponement_fixtures where postponement_id=v_postponement)<>1 then
    raise exception 'Weather postponement fixture history is incomplete';
  end if;
  if (select count(*) from public.fixture_gameweek_renumber_history where postponement_id=v_postponement)<>3 then
    raise exception 'Chronological gameweek renumbering audit history is incomplete';
  end if;
end;
$weather_postponement$;

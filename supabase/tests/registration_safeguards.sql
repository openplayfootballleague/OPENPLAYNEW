-- Registration safeguard regression tests.
-- Runs only in the disposable local Supabase database created by CI.

do $phone_normalisation$
declare
  v_rejected boolean;
begin
  if public.normalize_player_phone('07700 900 301') <> '+447700900301' then
    raise exception 'UK national phone number was not canonicalised to E.164';
  end if;
  if public.normalize_player_phone('0044 7700 900 302') <> '+447700900302' then
    raise exception 'Explicit international 00 prefix was not preserved consistently';
  end if;
  if public.normalize_player_phone('+1 (202) 555-0100') <> '+12025550100' then
    raise exception 'International plus-prefixed number was not canonicalised';
  end if;
  if public.normalize_player_phone('020 7946 0958') <> '+442079460958' then
    raise exception 'UK geographic number was not canonicalised';
  end if;
  if public.normalize_player_phone('07700 900 301')
     <> public.normalize_player_phone('+44 7700 900 301') then
    raise exception 'Equivalent UK national and international numbers do not share a canonical value';
  end if;

  v_rejected := false;
  begin
    perform public.normalize_player_phone('07700 CALL ME');
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Phone normaliser accepted alphabetic characters';
  end if;

  v_rejected := false;
  begin
    perform public.normalize_player_phone('12345');
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Phone normaliser accepted a number without a UK or international prefix';
  end if;
end;
$phone_normalisation$;

do $ban_and_captain_succession$
declare
  v_admin constant uuid := '90000000-0000-4000-8000-000000000300';
  v_target constant uuid := '90000000-0000-4000-8000-000000000301';
  v_highest constant uuid := '90000000-0000-4000-8000-000000000302';
  v_tie_zara constant uuid := '90000000-0000-4000-8000-000000000303';
  v_tie_aaron constant uuid := '90000000-0000-4000-8000-000000000304';
  v_single constant uuid := '90000000-0000-4000-8000-000000000305';
  v_pending_captain constant uuid := '90000000-0000-4000-8000-000000000306';
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_team_a uuid;
  v_team_b uuid;
  v_team_c uuid;
  v_team_d uuid;
  v_team_e uuid;
  v_fixture uuid;
  v_sheet uuid;
  v_rejected boolean;
  v_count integer;
  v_phone_target text;
  v_phone_highest text;
begin
  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-ban-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_target,'authenticated','authenticated','ci-ban-target@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_highest,'authenticated','authenticated','ci-ban-highest@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_tie_zara,'authenticated','authenticated','ci-ban-zara@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_tie_aaron,'authenticated','authenticated','ci-ban-aaron@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_single,'authenticated','authenticated','ci-ban-single@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_pending_captain,'authenticated','authenticated','ci-ban-pending-captain@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.user_roles(user_id,role,granted_by)
  values(v_admin,'admin',v_admin);

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status)
  values
    (v_target,'Ban Target','07700900301','ci-ban-target@openplay.invalid',date '1990-01-01','registered'),
    (v_highest,'Highest Appearances','07700900302','ci-ban-highest@openplay.invalid',date '1990-01-02','registered'),
    (v_tie_zara,'Zara Tie Break','07700900303','ci-ban-zara@openplay.invalid',date '1990-01-03','registered'),
    (v_tie_aaron,'Aaron Tie Break','07700900304','ci-ban-aaron@openplay.invalid',date '1990-01-04','registered'),
    (v_single,'Only Successor','07700900305','ci-ban-single@openplay.invalid',date '1990-01-05','registered'),
    (v_pending_captain,'Unaffected Captain','07700900306','ci-ban-pending-captain@openplay.invalid',date '1990-01-06','registered');

  -- Exercise the migration's historical-collision guard against two distinct
  -- legacy strings that resolve to the same E.164 identity.
  select phone into v_phone_target from public.players where user_id=v_target;
  select phone into v_phone_highest from public.players where user_id=v_highest;
  alter table public.players disable trigger players_canonicalize_phone;
  update public.players set phone='07700 900 399' where user_id=v_target;
  update public.players set phone='+44 7700 900 399' where user_id=v_highest;
  v_rejected := false;
  begin
    if exists (
      select public.normalize_player_phone(phone)
      from public.players
      group by public.normalize_player_phone(phone)
      having count(*) > 1
    ) then
      raise exception 'Phone normalisation found duplicate canonical numbers; resolve identity collisions before applying this migration';
    end if;
  exception when others then
    v_rejected := true;
  end;
  update public.players set phone=v_phone_target where user_id=v_target;
  update public.players set phone=v_phone_highest where user_id=v_highest;
  alter table public.players enable trigger players_canonicalize_phone;
  if not v_rejected then
    raise exception 'Historical phone collision guard did not reject equivalent legacy phone formats';
  end if;

  insert into public.locations(name,slug,town,region,is_active)
  values('CI Registration Safeguards','ci-registration-safeguards','Bideford','North Devon',false)
  returning id into v_location;

  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Registration Safeguards','ci-registration-safeguards',false)
  returning id into v_league;

  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Registration Safeguards',999,'active',false)
  returning id into v_season;

  insert into public.teams(created_by) values(v_admin) returning id into v_team_a;
  insert into public.teams(created_by) values(v_admin) returning id into v_team_b;
  insert into public.teams(created_by) values(v_admin) returning id into v_team_c;
  insert into public.teams(created_by) values(v_admin) returning id into v_team_d;
  insert into public.teams(created_by) values(v_admin) returning id into v_team_e;

  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values
    (v_team_a,v_season,'Appearance Ranking','ci-appearance-ranking','approved',now(),v_admin),
    (v_team_b,v_season,'Tie Break','ci-tie-break','approved',now(),v_admin),
    (v_team_c,v_season,'Single Successor','ci-single-successor','approved',now(),v_admin),
    (v_team_d,v_season,'No Successor','ci-no-successor','approved',now(),v_admin),
    (v_team_e,v_season,'Pending Membership','ci-pending-membership','approved',now(),v_admin)
;

  select id into v_team_a from public.season_teams where slug='ci-appearance-ranking';
  select id into v_team_b from public.season_teams where slug='ci-tie-break';
  select id into v_team_c from public.season_teams where slug='ci-single-successor';
  select id into v_team_d from public.season_teams where slug='ci-no-successor';
  select id into v_team_e from public.season_teams where slug='ci-pending-membership';

  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values
    (v_team_a,v_target,'active',true),
    (v_team_a,v_highest,'active',false),
    (v_team_a,v_tie_zara,'active',false),
    (v_team_a,v_tie_aaron,'active',false),
    (v_team_b,v_target,'active',true),
    (v_team_b,v_tie_zara,'active',false),
    (v_team_b,v_tie_aaron,'active',false),
    (v_team_c,v_target,'active',true),
    (v_team_c,v_single,'active',false),
    (v_team_d,v_target,'active',true),
    (v_team_e,v_pending_captain,'active',true),
    (v_team_e,v_target,'pending',false);

  -- Four appearances for the leading candidate, three for each tied candidate.
  for i in 1..4 loop
    insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id)
    values(v_season,i,1,v_team_a,v_team_b)
    returning id into v_fixture;

    insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by)
    values(v_fixture,v_team_a,v_target)
    returning id into v_sheet;

    insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,did_appear)
    values(v_sheet,v_highest,'starter',true);

    if i <= 3 then
      insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,did_appear)
      values(v_sheet,v_tie_zara,'starter',true),(v_sheet,v_tie_aaron,'starter',true);
    end if;
  end loop;

  -- Equal appearance counts are resolved by deterministic full-name order.
  for i in 5..6 loop
    insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id)
    values(v_season,i,1,v_team_b,v_team_a)
    returning id into v_fixture;

    insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by)
    values(v_fixture,v_team_b,v_target)
    returning id into v_sheet;

    insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,did_appear)
    values
      (v_sheet,v_tie_zara,'starter',true),
      (v_sheet,v_tie_aaron,'starter',true);
  end loop;

  -- Invalid reasons must fail before any ban state is changed.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_rejected := false;
  begin
    perform public.admin_set_player_ban(v_target,true,'no');
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then raise exception 'Ban RPC accepted an invalid audit reason'; end if;
  execute 'reset role';

  -- Force a failure after captain succession has begun. The RPC must roll
  -- back its membership changes, audit rows and queued notifications atomically.
  execute $ddl$
    create function pg_temp.fail_captain_handover_notification()
    returns trigger language plpgsql as $fn$
    begin
      if new.event_type='team.captain.handover_completed'
         and new.user_id='90000000-0000-4000-8000-000000000302'::uuid then
        raise exception 'CI forced notification failure';
      end if;
      return new;
    end;
    $fn$
  $ddl$;
  execute 'create trigger ci_fail_captain_handover_notification
    before insert on public.notification_events
    for each row execute function pg_temp.fail_captain_handover_notification()';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_rejected := false;
  begin
    perform public.admin_set_player_ban(v_target,true,'CI forced rollback test');
  exception when others then
    v_rejected := true;
  end;
  execute 'reset role';
  drop trigger ci_fail_captain_handover_notification on public.notification_events;
  if not v_rejected then
    raise exception 'Injected notification failure did not abort the ban transaction';
  end if;
  if (select is_banned from public.players where user_id=v_target) then
    raise exception 'Failed ban transaction left the player banned';
  end if;
  if (select is_captain from public.team_memberships where season_team_id=v_team_a and user_id=v_target) is not true then
    raise exception 'Failed ban transaction did not restore the former captain membership';
  end if;
  if (select is_captain from public.team_memberships where season_team_id=v_team_a and user_id=v_highest) is not false then
    raise exception 'Failed ban transaction left a partial captain succession';
  end if;
  if exists(select 1 from public.notification_events where event_type='team.captain.handover_completed' and user_id=v_highest) then
    raise exception 'Failed ban transaction left a partial captain handover notification';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform public.admin_set_player_ban(v_target,true,'CI registration safeguard test');
  execute 'reset role';

  if not (select is_banned from public.players where user_id=v_target) then
    raise exception 'Ban RPC did not mark the player as banned';
  end if;

  if (select is_captain from public.team_memberships where season_team_id=v_team_a and user_id=v_highest) is not true then
    raise exception 'Highest-appearance eligible teammate was not appointed captain';
  end if;
  if (select is_captain from public.team_memberships where season_team_id=v_team_b and user_id=v_tie_aaron) is not true then
    raise exception 'Full-name tie-break did not select Aaron ahead of Zara';
  end if;
  if (select is_captain from public.team_memberships where season_team_id=v_team_c and user_id=v_single) is not true then
    raise exception 'The only eligible successor was not appointed captain';
  end if;
  if exists(select 1 from public.team_memberships where season_team_id=v_team_d and is_captain) then
    raise exception 'A captain was incorrectly appointed when no eligible successor existed';
  end if;
  if not exists(
    select 1 from public.notification_events
    where user_id=v_admin and event_type='team.captain.successor_missing'
  ) then
    raise exception 'Global administrator was not notified when a team had no eligible successor';
  end if;
  if not exists(
    select 1 from public.audit_log
    where action='team.captain.successor_missing' and entity_id=v_team_d::text
  ) then
    raise exception 'Missing-successor admin action was not audited';
  end if;

  if exists(select 1 from public.team_memberships where user_id=v_target and status in ('active','pending')) then
    raise exception 'Ban did not revoke active memberships and reject pending membership requests';
  end if;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_target::text,true);
  if public.is_active_team_captain(v_team_a) then
    raise exception 'Banned former captain still passes the active-captain authorization helper';
  end if;
  v_rejected := false;
  begin
    perform * from public.get_captain_fixtures();
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Banned former captain could still call the captain-only fixture RPC';
  end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform public.admin_set_player_ban(v_target,false,'CI unban regression test');
  execute 'reset role';

  if (select is_banned from public.players where user_id=v_target) then
    raise exception 'Unban RPC did not clear the ban flag';
  end if;
  if (select registration_status::text from public.players where user_id=v_target) <> 'rejected' then
    raise exception 'Unban must require a fresh registration decision';
  end if;
  if exists(select 1 from public.team_memberships where user_id=v_target and status='active') then
    raise exception 'Unban unexpectedly reactivated historical memberships';
  end if;
  if exists(select 1 from public.team_memberships where user_id=v_target and status='pending') then
    raise exception 'Unban unexpectedly restored pending membership requests';
  end if;

  select count(*) into v_count
  from public.audit_log
  where actor_user_id=v_admin
    and entity_type='player'
    and entity_id=v_target::text
    and action in ('player.banned','player.unbanned');
  if v_count <> 2 then raise exception 'Ban and unban actions were not both audited'; end if;
end;
$ban_and_captain_succession$;

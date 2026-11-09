-- Player account retention and reactivation regression tests.
-- Runs only in the disposable local Supabase database created by CI.

do $player_account_retention$
declare
  v_inactive constant uuid := '92000000-0000-4000-8000-000000000001';
  v_member constant uuid := '92000000-0000-4000-8000-000000000002';
  v_admin constant uuid := '92000000-0000-4000-8000-000000000003';
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_team uuid;
  v_season_team uuid;
  v_token constant text := repeat('e',64);
  v_token_hash text;
  v_count integer;
  v_closed boolean;
  v_reactivated boolean;
  v_marked boolean;
  v_status text;
  v_archive_expires_at timestamptz;
begin
  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at,last_sign_in_at)
  values
    (v_inactive,'authenticated','authenticated','ci-retention-inactive@openplay.invalid','','{}'::jsonb,now(),now()-interval '2 years',now(),now()-interval '13 months'),
    (v_member,'authenticated','authenticated','ci-retention-member@openplay.invalid','','{}'::jsonb,now(),now()-interval '2 years',now(),now()-interval '13 months'),
    (v_admin,'authenticated','authenticated','ci-retention-admin@openplay.invalid','','{}'::jsonb,now(),now()-interval '2 years',now(),now()-interval '13 months');

  update public.profiles
  set last_sign_in_at=now()-interval '13 months'
  where id in (v_inactive,v_member,v_admin);

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status)
  values
    (v_inactive,'Inactive Retention Player','07700900401','ci-retention-inactive@openplay.invalid',date '1990-01-01','registered'),
    (v_member,'Active Membership Player','07700900402','ci-retention-member@openplay.invalid',date '1990-01-02','registered');

  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'admin',v_admin);

  insert into public.locations(name,slug,town) values('Retention Test Location','retention-test','Bideford') returning id into v_location;
  insert into public.leagues(location_id,name,slug) values(v_location,'Retention Test League','retention-test-league') returning id into v_league;
  insert into public.seasons(league_id,name,status) values(v_league,'Retention Test Season','active') returning id into v_season;
  insert into public.teams(created_by) values(v_admin) returning id into v_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status)
  values(v_team,v_season,'Retention Test Team','retention-test-team','approved') returning id into v_season_team;
  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_season_team,v_member,'active',true);

  if has_function_privilege('anon','public.admin_list_inactive_player_accounts()','EXECUTE')
     or has_function_privilege('authenticated','public.admin_list_inactive_player_accounts()','EXECUTE')
     or has_function_privilege('anon','public.complete_player_account_reactivation(uuid,text)','EXECUTE')
     or has_function_privilege('authenticated','public.complete_player_account_reactivation(uuid,text)','EXECUTE') then
    raise exception 'A client role can execute a privileged account-retention function';
  end if;

  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  select count(*) into v_count from public.admin_list_inactive_player_accounts();
  if v_count <> 1 then
    raise exception 'Expected only the inactive unattached player to be eligible; found % candidates',v_count;
  end if;

  select public.admin_close_inactive_player_account(v_inactive) into v_closed;
  if not v_closed then raise exception 'Eligible inactive player account was not closed'; end if;
  select account_retention_status,archive_expires_at into v_status,v_archive_expires_at
  from public.profiles where id=v_inactive;
  if v_status <> 'closed' or v_archive_expires_at < now()+interval '11 months 29 days' then
    raise exception 'Account closure did not start the 12-month restricted archive';
  end if;

  -- A second request within the cooldown returns no row.
  v_token_hash:=public.hash_guardian_consent_token(v_token);
  perform * from public.request_player_account_reactivation('ci-retention-inactive@openplay.invalid',v_token_hash);
  select count(*) into v_count
  from public.request_player_account_reactivation('ci-retention-inactive@openplay.invalid',repeat('f',64));
  if v_count <> 0 then raise exception 'Reactivation request cooldown was not enforced'; end if;

  if public.get_player_account_reactivation_target(v_token_hash) <> v_inactive then
    raise exception 'Valid reactivation token did not resolve to its player account';
  end if;
  select public.complete_player_account_reactivation(v_inactive,v_token_hash) into v_reactivated;
  if not v_reactivated then raise exception 'Valid reactivation token did not reactivate the account'; end if;

  select account_retention_status,account_closed_at,archive_expires_at
    into v_status,v_archive_expires_at,v_archive_expires_at
  from public.profiles where id=v_inactive;
  if v_status <> 'active' or exists (
    select 1 from public.team_memberships where user_id=v_inactive and status in ('active','pending')
  ) then
    raise exception 'Reactivated player was not restored as an unattached registered player';
  end if;

  select public.complete_player_account_reactivation(v_inactive,v_token_hash) into v_reactivated;
  if v_reactivated then raise exception 'Reactivation token was reusable'; end if;

  -- An expired archive is moved to the controlled erasure queue, not hard-deleted.
  update public.profiles
  set account_retention_status='closed',
      account_closed_at=now()-interval '13 months',
      archive_expires_at=now()-interval '1 minute'
  where id=v_inactive;
  select public.admin_mark_player_account_erasure_due(v_inactive) into v_marked;
  if not v_marked then raise exception 'Expired archive was not marked erasure_due'; end if;
  if not exists(select 1 from public.profiles where id=v_inactive and account_retention_status='erasure_due') then
    raise exception 'Expired archive did not enter erasure_due state';
  end if;

  execute 'reset role';

  if not exists(select 1 from public.team_memberships where user_id=v_member and status='active' and is_captain) then
    raise exception 'The active member/captain was altered by the retention workflow';
  end if;
end;
$player_account_retention$;

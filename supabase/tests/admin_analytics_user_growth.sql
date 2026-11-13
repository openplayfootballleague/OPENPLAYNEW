-- Aggregate-only user-growth RPC regression. Run on a disposable clean Supabase database.
do $analytics_user_growth$
declare
  v_account_signups bigint;
  v_player_registrations bigint;
  v_team_applications bigint;
  v_team_approvals bigint;
  v_bucket_count integer;
  v_denied boolean := false;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values
    ('00000000-0000-4000-8000-000000000001','authenticated','authenticated','ci-growth-global@openplay.invalid','','{}'::jsonb,now(),now()),
    ('00000000-0000-4000-8000-000000000002','authenticated','authenticated','ci-growth-location@openplay.invalid','','{}'::jsonb,now(),now()),
    ('00000000-0000-4000-8000-000000000003','authenticated','authenticated','ci-growth-player-a@openplay.invalid','','{}'::jsonb,now(),now()),
    ('00000000-0000-4000-8000-000000000004','authenticated','authenticated','ci-growth-player-b@openplay.invalid','','{}'::jsonb,now(),now());

  update public.profiles
  set created_at = case id
    when '00000000-0000-4000-8000-000000000001' then timestamptz '2001-01-01 10:00:00+00'
    when '00000000-0000-4000-8000-000000000002' then timestamptz '2001-01-01 11:00:00+00'
    when '00000000-0000-4000-8000-000000000003' then timestamptz '2001-01-02 10:00:00+00'
    else timestamptz '2001-01-03 10:00:00+00'
  end
  where id in (
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000003',
    '00000000-0000-4000-8000-000000000004'
  );

  insert into public.user_roles(user_id,role,granted_by)
  values
    ('00000000-0000-4000-8000-000000000001','admin','00000000-0000-4000-8000-000000000001'),
    ('00000000-0000-4000-8000-000000000002','league_admin','00000000-0000-4000-8000-000000000001');

  insert into public.locations(id,name,slug,town,region,is_active)
  values
    ('00000000-0000-4000-8000-000000000010','Growth Location A','ci-growth-location-a','Bideford','Devon',false),
    ('00000000-0000-4000-8000-000000000011','Growth Location B','ci-growth-location-b','Barnstaple','Devon',false);

  insert into public.location_admin_assignments(user_id,location_id,assigned_by)
  values ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000001');

  insert into public.leagues(id,location_id,name,slug,is_published)
  values
    ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010','Growth League A','ci-growth-league-a',false),
    ('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000011','Growth League B','ci-growth-league-b',false);

  insert into public.seasons(id,league_id,name,season_number,is_public,status)
  values
    ('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000020','Growth Season A',1,false,'registration_open'),
    ('00000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000021','Growth Season B',1,false,'registration_open');

  insert into public.teams(id,created_by)
  values
    ('00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000003'),
    ('00000000-0000-4000-8000-000000000041','00000000-0000-4000-8000-000000000004');

  insert into public.season_teams(id,team_id,season_id,name,slug,registration_status,created_at,approved_at)
  values
    ('00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000030','Growth Team A','ci-growth-team-a','approved',timestamptz '2001-01-01 12:00:00+00',timestamptz '2001-01-02 12:00:00+00'),
    ('00000000-0000-4000-8000-000000000051','00000000-0000-4000-8000-000000000041','00000000-0000-4000-8000-000000000031','Growth Team B','ci-growth-team-b','approved',timestamptz '2001-01-03 12:00:00+00',timestamptz '2001-01-03 13:00:00+00');

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,created_at)
  values
    ('00000000-0000-4000-8000-000000000003','Growth Player A','+447700900103','ci-growth-player-a@openplay.invalid',date '1990-01-03','registered',timestamptz '2001-01-02 14:00:00+00'),
    ('00000000-0000-4000-8000-000000000004','Growth Player B','+447700900104','ci-growth-player-b@openplay.invalid',date '1990-01-04','registered',timestamptz '2001-01-03 14:00:00+00');

  insert into public.team_memberships(id,season_team_id,user_id,status,is_captain)
  values
    ('00000000-0000-4000-8000-000000000060','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000003','active',true),
    ('00000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000051','00000000-0000-4000-8000-000000000004','active',true);

  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}',true);

  select count(*),sum(account_signups),sum(player_registrations),sum(team_applications),sum(team_approvals)
  into v_bucket_count,v_account_signups,v_player_registrations,v_team_applications,v_team_approvals
  from public.get_admin_user_growth(date '2001-01-01',date '2001-01-03');

  if v_bucket_count<>3 or v_account_signups<>4 or v_player_registrations<>2
     or v_team_applications<>2 or v_team_approvals<>2 then
    raise exception 'Global growth totals or inclusive date boundaries are incorrect: buckets %, accounts %, players %, applications %, approvals %',
      v_bucket_count,v_account_signups,v_player_registrations,v_team_applications,v_team_approvals;
  end if;

  select sum(account_signups) into v_account_signups
  from public.get_admin_user_growth(date '2001-01-01',date '2001-01-03','00000000-0000-4000-8000-000000000010');

  if v_account_signups is not null then
    raise exception 'Scoped reporting must not expose platform-wide account signups';
  end if;

  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated"}',true);

  select sum(account_signups),sum(player_registrations),sum(team_applications),sum(team_approvals)
  into v_account_signups,v_player_registrations,v_team_applications,v_team_approvals
  from public.get_admin_user_growth(date '2001-01-01',date '2001-01-03','00000000-0000-4000-8000-000000000010');

  if v_account_signups is not null or v_player_registrations<>1
     or v_team_applications<>1 or v_team_approvals<>1 then
    raise exception 'Location admin report leaked cross-location data or returned incorrect totals';
  end if;

  begin
    perform * from public.get_admin_user_growth(
      date '2001-01-01',date '2001-01-03','00000000-0000-4000-8000-000000000011'
    );
    v_denied := false;
  exception when others then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Location admin accessed an unassigned location'; end if;

  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
  begin
    perform * from public.get_admin_user_growth(date '2001-01-01',date '2001-01-03');
    v_denied := false;
  exception when others then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Ordinary player accessed administrator growth reporting'; end if;

  if pg_catalog.has_function_privilege('anon','public.get_admin_user_growth(date,date,uuid,uuid,uuid)','EXECUTE') then
    raise exception 'Anonymous role must not execute administrator growth reporting';
  end if;

  raise notice 'Analytics user growth aggregate, date boundary and location isolation regressions passed';
end;
$analytics_user_growth$;

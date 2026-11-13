-- Aggregate-only registration conversion regression. Run on a disposable clean Supabase database.
do $registration_conversion$
declare
  v_players bigint;
  v_pending_players bigint;
  v_rejected_players bigint;
  v_applications bigint;
  v_approved bigint;
  v_rejected bigint;
  v_pending bigint;
  v_requests bigint;
  v_accepted bigint;
  v_membership_rejected bigint;
  v_membership_pending bigint;
  v_denied boolean := false;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values
    ('f1000000-0000-4000-8000-000000000001','authenticated','authenticated','ci-conv-global@openplay.invalid','','{}'::jsonb,now(),now()),
    ('f1000000-0000-4000-8000-000000000002','authenticated','authenticated','ci-conv-location@openplay.invalid','','{}'::jsonb,now(),now()),
    ('f1000000-0000-4000-8000-000000000003','authenticated','authenticated','ci-conv-player-a@openplay.invalid','','{}'::jsonb,now(),now()),
    ('f1000000-0000-4000-8000-000000000004','authenticated','authenticated','ci-conv-player-b@openplay.invalid','','{}'::jsonb,now(),now()),
    ('f1000000-0000-4000-8000-000000000005','authenticated','authenticated','ci-conv-player-c@openplay.invalid','','{}'::jsonb,now(),now());

  insert into public.user_roles(user_id,role,granted_by)
  values
    ('f1000000-0000-4000-8000-000000000001','admin','f1000000-0000-4000-8000-000000000001'),
    ('f1000000-0000-4000-8000-000000000002','league_admin','f1000000-0000-4000-8000-000000000001');

  insert into public.locations(id,name,slug,town,region,is_active)
  values
    ('f1000000-0000-4000-8000-000000000010','Conversion Location A','ci-conv-location-a','Bideford','Devon',false),
    ('f1000000-0000-4000-8000-000000000011','Conversion Location B','ci-conv-location-b','Barnstaple','Devon',false);

  insert into public.location_admin_assignments(user_id,location_id,assigned_by)
  values ('f1000000-0000-4000-8000-000000000002','f1000000-0000-4000-8000-000000000010','f1000000-0000-4000-8000-000000000001');

  insert into public.leagues(id,location_id,name,slug,is_published)
  values
    ('f1000000-0000-4000-8000-000000000020','f1000000-0000-4000-8000-000000000010','Conversion League A','ci-conv-league-a',false),
    ('f1000000-0000-4000-8000-000000000021','f1000000-0000-4000-8000-000000000011','Conversion League B','ci-conv-league-b',false);

  insert into public.seasons(id,league_id,name,season_number,is_public,status,recruitment_status)
  values
    ('f1000000-0000-4000-8000-000000000030','f1000000-0000-4000-8000-000000000020','Conversion Season A',1,false,'registration_open','open'),
    ('f1000000-0000-4000-8000-000000000031','f1000000-0000-4000-8000-000000000021','Conversion Season B',1,false,'registration_open','open');

  insert into public.teams(id,created_by)
  values
    ('f1000000-0000-4000-8000-000000000040','f1000000-0000-4000-8000-000000000003'),
    ('f1000000-0000-4000-8000-000000000041','f1000000-0000-4000-8000-000000000004'),
    ('f1000000-0000-4000-8000-000000000042','f1000000-0000-4000-8000-000000000005');

  insert into public.season_teams(id,team_id,season_id,name,slug,registration_status,created_at,approved_at)
  values
    ('f1000000-0000-4000-8000-000000000050','f1000000-0000-4000-8000-000000000040','f1000000-0000-4000-8000-000000000030','Conversion Team Approved','ci-conv-team-approved','approved',timestamptz '2001-02-01 12:00:00+00',timestamptz '2001-02-02 12:00:00+00'),
    ('f1000000-0000-4000-8000-000000000051','f1000000-0000-4000-8000-000000000041','f1000000-0000-4000-8000-000000000030','Conversion Team Rejected','ci-conv-team-rejected','rejected',timestamptz '2001-02-01 13:00:00+00',null),
    ('f1000000-0000-4000-8000-000000000052','f1000000-0000-4000-8000-000000000042','f1000000-0000-4000-8000-000000000030','Conversion Team Pending','ci-conv-team-pending','pending',timestamptz '2001-02-01 14:00:00+00',null);

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,created_at)
  values
    ('f1000000-0000-4000-8000-000000000003','Conversion Player A','+447700901103','ci-conv-player-a@openplay.invalid',date '1990-02-01','registered',timestamptz '2001-02-01 10:00:00+00'),
    ('f1000000-0000-4000-8000-000000000004','Conversion Player B','+447700901104','ci-conv-player-b@openplay.invalid',date '1990-02-02','pending_review',timestamptz '2001-02-01 10:00:00+00'),
    ('f1000000-0000-4000-8000-000000000005','Conversion Player C','+447700901105','ci-conv-player-c@openplay.invalid',date '1990-02-03','rejected',timestamptz '2001-02-01 10:00:00+00');

  insert into public.team_memberships(id,season_team_id,user_id,status,is_captain,created_at,joined_at)
  values
    ('f1000000-0000-4000-8000-000000000060','f1000000-0000-4000-8000-000000000050','f1000000-0000-4000-8000-000000000003','active',true,timestamptz '2001-02-01 15:00:00+00',timestamptz '2001-02-02 15:00:00+00'),
    ('f1000000-0000-4000-8000-000000000061','f1000000-0000-4000-8000-000000000051','f1000000-0000-4000-8000-000000000004','rejected',false,timestamptz '2001-02-01 16:00:00+00',null),
    ('f1000000-0000-4000-8000-000000000062','f1000000-0000-4000-8000-000000000052','f1000000-0000-4000-8000-000000000005','pending',false,timestamptz '2001-02-01 17:00:00+00',null);

  perform set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
  perform set_config('request.jwt.claims','{"sub":"f1000000-0000-4000-8000-000000000001","role":"authenticated"}',true);

  select sum(player_registered),sum(player_pending_review),sum(player_rejected),
    sum(team_applications),sum(team_approved),sum(team_rejected),sum(team_pending),
    sum(membership_requests),sum(membership_accepted),sum(membership_rejected),sum(membership_pending)
  into v_players,v_pending_players,v_rejected_players,v_applications,v_approved,v_rejected,v_pending,
    v_requests,v_accepted,v_membership_rejected,v_membership_pending
  from public.get_admin_registration_conversion(date '2001-02-01',date '2001-02-01');

  if v_players<>1 or v_pending_players<>1 or v_rejected_players<>1
     or v_applications<>3 or v_approved<>1 or v_rejected<>1 or v_pending<>1
     or v_requests<>3 or v_accepted<>1 or v_membership_rejected<>1 or v_membership_pending<>1 then
    raise exception 'Global registration conversion cohort totals are incorrect';
  end if;

  perform set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000002',true);
  perform set_config('request.jwt.claims','{"sub":"f1000000-0000-4000-8000-000000000002","role":"authenticated"}',true);

  select sum(player_registered),sum(team_applications),sum(team_approved),sum(team_rejected),sum(team_pending),
    sum(membership_requests),sum(membership_accepted),sum(membership_rejected),sum(membership_pending)
  into v_players,v_applications,v_approved,v_rejected,v_pending,v_requests,v_accepted,v_membership_rejected,v_membership_pending
  from public.get_admin_registration_conversion(date '2001-02-01',date '2001-02-01','f1000000-0000-4000-8000-000000000010');

  if v_players is not null or v_applications<>3 or v_approved<>1 or v_rejected<>1
     or v_pending<>1 or v_requests<>3 or v_accepted<>1
     or v_membership_rejected<>1 or v_membership_pending<>1 then
    raise exception 'Location-scoped conversion reporting leaked player identity workflow totals or returned incorrect outcomes';
  end if;

  begin
    perform * from public.get_admin_registration_conversion(
      date '2001-02-01',date '2001-02-01','f1000000-0000-4000-8000-000000000011'
    );
    v_denied := false;
  exception when others then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Location administrator accessed an unassigned location'; end if;

  perform set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000003',true);
  perform set_config('request.jwt.claims','{"sub":"f1000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
  begin
    perform * from public.get_admin_registration_conversion(date '2001-02-01',date '2001-02-01');
    v_denied := false;
  exception when others then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Ordinary player accessed administrator registration conversion reporting'; end if;

  if pg_catalog.has_function_privilege('anon','public.get_admin_registration_conversion(date,date,uuid,uuid,uuid)','EXECUTE') then
    raise exception 'Anonymous role must not execute administrator registration conversion reporting';
  end if;
  if not pg_catalog.has_function_privilege('authenticated','public.get_admin_registration_conversion(date,date,uuid,uuid,uuid)','EXECUTE') then
    raise exception 'Authenticated role must execute the permission-checked registration conversion RPC';
  end if;

  raise notice 'Registration conversion aggregate, cohort outcomes and location isolation regressions passed';
end;
$registration_conversion$;

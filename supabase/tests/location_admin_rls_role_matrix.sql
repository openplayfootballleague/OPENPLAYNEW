-- Runtime RLS role matrix. All fixtures are synthetic and the transaction rolls back.
begin;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('10000000-0000-0000-0000-000000000001','authenticated','authenticated','rls-player-a@example.test','test-only',now(),'{}'::jsonb,'{}'::jsonb,now(),now()),
  ('10000000-0000-0000-0000-000000000002','authenticated','authenticated','rls-player-b@example.test','test-only',now(),'{}'::jsonb,'{}'::jsonb,now(),now()),
  ('10000000-0000-0000-0000-000000000003','authenticated','authenticated','rls-location-admin-a@example.test','test-only',now(),'{}'::jsonb,'{}'::jsonb,now(),now()),
  ('10000000-0000-0000-0000-000000000004','authenticated','authenticated','rls-location-admin-unassigned@example.test','test-only',now(),'{}'::jsonb,'{}'::jsonb,now(),now()),
  ('10000000-0000-0000-0000-000000000005','authenticated','authenticated','rls-global-admin@example.test','test-only',now(),'{}'::jsonb,'{}'::jsonb,now(),now()),
  ('10000000-0000-0000-0000-000000000006','authenticated','authenticated','rls-finance-admin@example.test','test-only',now(),'{}'::jsonb,'{}'::jsonb,now(),now());

insert into public.user_roles (user_id, role, granted_by) values
  ('10000000-0000-0000-0000-000000000003','league_admin','10000000-0000-0000-0000-000000000005'),
  ('10000000-0000-0000-0000-000000000004','league_admin','10000000-0000-0000-0000-000000000005'),
  ('10000000-0000-0000-0000-000000000005','admin','10000000-0000-0000-0000-000000000005'),
  ('10000000-0000-0000-0000-000000000006','finance_admin','10000000-0000-0000-0000-000000000005');

insert into public.locations (id,name,slug,town,is_active) values
  ('20000000-0000-0000-0000-000000000001','RLS Location A','rls-location-a','Test Town A',true),
  ('20000000-0000-0000-0000-000000000002','RLS Location B','rls-location-b','Test Town B',false);

insert into public.location_admin_assignments (user_id,location_id,assigned_by) values
  ('10000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000005');

insert into public.leagues (id,location_id,name,slug,is_published) values
  ('21000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','RLS League A','rls-league-a',false),
  ('21000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','RLS League B','rls-league-b',false);

insert into public.seasons (id,league_id,name,status,is_public) values
  ('22000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','RLS Season A','active',false),
  ('22000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000002','RLS Season B','active',false);

insert into public.teams (id,created_by) values
  ('23000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'),
  ('23000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001'),
  ('23000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002'),
  ('23000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000002');

insert into public.season_teams (id,team_id,season_id,name,slug,registration_status) values
  ('24000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','RLS Team A','rls-team-a','approved'),
  ('24000000-0000-0000-0000-000000000002','23000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000001','RLS Team A2','rls-team-a2','approved'),
  ('24000000-0000-0000-0000-000000000003','23000000-0000-0000-0000-000000000003','22000000-0000-0000-0000-000000000002','RLS Team B','rls-team-b','approved'),
  ('24000000-0000-0000-0000-000000000004','23000000-0000-0000-0000-000000000004','22000000-0000-0000-0000-000000000002','RLS Team B2','rls-team-b2','approved');

insert into public.players (id,user_id,full_name,phone,email,date_of_birth,registration_status) values
  ('25000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','RLS Player A','07123456781','rls-player-a@example.test',date '1990-01-01','registered'),
  ('25000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','RLS Player B','07123456782','rls-player-b@example.test',date '1991-01-01','registered');

insert into public.season_registrations (season_id,user_id,status) values
  ('22000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','approved'),
  ('22000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','approved');

insert into public.team_memberships (id,season_team_id,user_id,status,is_captain,joined_at) values
  ('26000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','active',true,now()),
  ('26000000-0000-0000-0000-000000000002','24000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','active',true,now());

insert into public.fixtures (id,season_id,gameweek,fixture_number,home_team_id,away_team_id,scheduled_at) values
  ('27000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001',1,1,'24000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000002',now()+interval '7 days'),
  ('27000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000002',1,1,'24000000-0000-0000-0000-000000000003','24000000-0000-0000-0000-000000000004',now()+interval '7 days');

insert into public.fixture_results (fixture_id,home_score,away_score) values
  ('27000000-0000-0000-0000-000000000001',1,0),
  ('27000000-0000-0000-0000-000000000002',2,1);

insert into public.fixture_team_sheets (id,fixture_id,season_team_id,submitted_by) values
  ('28000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'),
  ('28000000-0000-0000-0000-000000000002','27000000-0000-0000-0000-000000000002','24000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002');

insert into public.fixture_team_sheet_players (team_sheet_id,user_id,role,is_goalkeeper,did_appear) values
  ('28000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','starter',false,true),
  ('28000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','starter',false,true);

insert into public.fixture_availability (id,fixture_id,user_id,is_available) values
  ('29000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',true),
  ('29000000-0000-0000-0000-000000000002','27000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002',true);

insert into public.player_registration_reviews (id,player_id,name_matched,phone_matched,email_matched) values
  ('2a000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000002',true,true,false);

insert into public.player_transfer_requests (
  id,user_id,source_membership_id,source_season_team_id,destination_season_team_id,reason,status,requested_at,created_at,updated_at
) values
  ('2b000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000002','Test transfer A','pending',now(),now(),now()),
  ('2b000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','26000000-0000-0000-0000-000000000002','24000000-0000-0000-0000-000000000003','24000000-0000-0000-0000-000000000004','Test transfer B','pending',now(),now(),now());

insert into public.transfer_requests (id,player_id,from_membership_id,target_season_team_id,message)
values
  ('2c000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000002','Test transfer A'),
  ('2c000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','26000000-0000-0000-0000-000000000002','24000000-0000-0000-0000-000000000004','Test transfer B');

insert into public.notification_preferences (user_id) values
  ('10000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000002');

insert into public.notification_events (user_id,channel,event_type,status,payload) values
  ('10000000-0000-0000-0000-000000000001','in_app','rls.test','sent','{}'::jsonb),
  ('10000000-0000-0000-0000-000000000002','in_app','rls.test','sent','{}'::jsonb);

insert into public.season_fee_configs (season_id,team_fee_pence,effective_from_gameweek) values
  ('22000000-0000-0000-0000-000000000001',3000,1),
  ('22000000-0000-0000-0000-000000000002',3000,1);

insert into public.payment_records (season_team_id,amount_pence,fee_snapshot) values
  ('24000000-0000-0000-0000-000000000001',3000,'{"team_fee_pence":3000}'::jsonb),
  ('24000000-0000-0000-0000-000000000003',3000,'{"team_fee_pence":3000}'::jsonb);

set local role authenticated;

do $location_admin_role_matrix$
declare
  v_count integer;
  v_rows integer;
  v_dashboard jsonb;
  v_denied boolean;
begin
  -- Assigned location administrator: only location A data is visible.
  perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
  perform set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}',true);

  if not public.can_administer_location('20000000-0000-0000-0000-000000000001')
     or public.can_administer_location('20000000-0000-0000-0000-000000000002') then
    raise exception 'Assigned location administrator scope helper returned the wrong result';
  end if;

  select count(*) into v_count from public.profiles
  where id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Location admin can read profiles outside the assigned location'; end if;

  select count(*) into v_count from public.players
  where user_id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Location admin can read player identities outside the assigned location'; end if;

  select count(*) into v_count from public.user_roles
  where user_id <> '10000000-0000-0000-0000-000000000003';
  if v_count <> 0 then raise exception 'Location admin can read other users role grants'; end if;

  select count(*) into v_count from public.team_memberships
  where id in ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Location admin can read memberships outside the assigned location'; end if;

  select count(*) into v_count from public.fixtures
  where id in ('27000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Location admin can read fixtures outside the assigned location'; end if;

  select count(*) into v_count from public.fixture_results
  where fixture_id in ('27000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Location admin can read results outside the assigned location'; end if;

  select count(*) into v_count from public.fixture_team_sheets
  where id in ('28000000-0000-0000-0000-000000000001','28000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Location admin can read team sheets outside the assigned location'; end if;

  select count(*) into v_count from public.fixture_team_sheet_players
  where user_id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Location admin can read team-sheet players outside the assigned location'; end if;

  select count(*) into v_count from public.season_registrations
  where user_id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Location admin can read season registrations outside the assigned location'; end if;

  select count(*) into v_count from public.player_registration_reviews;
  if v_count <> 0 then raise exception 'Location admin can read global player identity-review records'; end if;

  select count(*) into v_count from public.notification_events
  where user_id = '10000000-0000-0000-0000-000000000002';
  if v_count <> 0 then raise exception 'Location admin can read another players notification events'; end if;

  select count(*) into v_count from public.notification_preferences
  where user_id = '10000000-0000-0000-0000-000000000002';
  if v_count <> 0 then raise exception 'Location admin can read another players notification preferences'; end if;

  select count(*) into v_count from public.player_transfer_requests
  where id in ('2b000000-0000-0000-0000-000000000001','2b000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Location admin can read transfer requests outside the assigned location'; end if;

  select count(*) into v_count from public.transfer_requests
  where id in ('2c000000-0000-0000-0000-000000000001','2c000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Location admin can read legacy transfer requests outside the assigned location'; end if;

  select count(*) into v_count from public.fixture_availability
  where id = '29000000-0000-0000-0000-000000000002';
  if v_count <> 0 then raise exception 'Location admin can read availability outside the assigned location'; end if;

  update public.fixture_availability
  set is_available = false
  where id = '29000000-0000-0000-0000-000000000001';
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then raise exception 'Assigned location admin cannot update availability in their own location'; end if;

  update public.fixture_availability
  set is_available = false
  where id = '29000000-0000-0000-0000-000000000002';
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then raise exception 'Location admin updated availability outside the assigned location'; end if;

  v_denied := false;
  begin
    insert into public.fixture_availability (fixture_id,user_id,is_available)
    values ('27000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002',false);
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Location admin inserted availability outside the assigned location'; end if;

  update public.profiles set phone = '07000000000'
  where id = '10000000-0000-0000-0000-000000000002';
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then raise exception 'Location admin updated a profile outside the assigned location'; end if;

  v_dashboard := public.get_admin_dashboard_contextual('20000000-0000-0000-0000-000000000001',null,null);
  if v_dashboard is null then raise exception 'Assigned location admin dashboard returned no result'; end if;

  v_denied := false;
  begin
    perform public.get_admin_dashboard_contextual('20000000-0000-0000-0000-000000000002',null,null);
  exception when others then
    if sqlerrm not like '%not assigned to this location%' then raise; end if;
    v_denied := true;
  end;
  if not v_denied then raise exception 'Contextual dashboard accepted an unassigned location'; end if;

  select count(*) into v_count
  from public.get_admin_player_register_contextual(null,'all',50,0,'20000000-0000-0000-0000-000000000001',null,null);
  if v_count <> 1 then raise exception 'Assigned location player register returned the wrong scoped rows'; end if;

  v_denied := false;
  begin
    perform * from public.get_admin_player_register_contextual(null,'all',50,0,'20000000-0000-0000-0000-000000000002',null,null);
  exception when others then
    if sqlerrm not like '%not assigned to this location%' then raise; end if;
    v_denied := true;
  end;
  if not v_denied then raise exception 'Contextual player register accepted an unassigned location'; end if;

  select count(*) into v_count
  from public.get_admin_team_sheets_contextual('20000000-0000-0000-0000-000000000001',null,null);
  if v_count <> 1 then raise exception 'Assigned location team-sheet query returned the wrong scoped rows'; end if;

  v_denied := false;
  begin
    perform * from public.get_admin_team_sheets_contextual('20000000-0000-0000-0000-000000000002',null,null);
  exception when others then
    if sqlerrm not like '%not assigned to this location%' then raise; end if;
    v_denied := true;
  end;
  if not v_denied then raise exception 'Contextual team-sheet query accepted an unassigned location'; end if;

  select count(*) into v_count
  from public.admin_get_transfer_requests_contextual('all','20000000-0000-0000-0000-000000000001',null,null);
  if v_count <> 1 then raise exception 'Assigned location transfer query returned the wrong scoped rows'; end if;

  v_denied := false;
  begin
    perform * from public.admin_get_transfer_requests_contextual('all','20000000-0000-0000-0000-000000000002',null,null);
  exception when others then
    if sqlerrm not like '%not assigned to this location%' then raise; end if;
    v_denied := true;
  end;
  if not v_denied then raise exception 'Contextual transfer query accepted an unassigned location'; end if;

  select count(*) into v_count
  from public.get_admin_contextual_fixtures('20000000-0000-0000-0000-000000000001',null,null);
  if v_count <> 1 then raise exception 'Assigned location fixture query returned the wrong scoped rows'; end if;

  v_denied := false;
  begin
    perform * from public.get_admin_contextual_fixtures('20000000-0000-0000-0000-000000000002',null,null);
  exception when others then
    if sqlerrm not like '%not assigned to this location%' then raise; end if;
    v_denied := true;
  end;
  if not v_denied then raise exception 'Contextual fixture query accepted an unassigned location'; end if;

  -- An unassigned league admin must not gain data access from the broad platform role.
  perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
  perform set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000004","role":"authenticated"}',true);

  if public.can_administer_location('20000000-0000-0000-0000-000000000001') then
    raise exception 'Unassigned league admin unexpectedly administers location A';
  end if;
  select count(*) into v_count from public.profiles
  where id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
  if v_count <> 0 then raise exception 'Unassigned league admin can read player profiles'; end if;

  v_denied := false;
  begin
    perform public.get_admin_dashboard_contextual(null,null,null);
  exception when others then
    if sqlerrm not like '%must select an assigned location%' then raise; end if;
    v_denied := true;
  end;
  if not v_denied then raise exception 'Unassigned league admin accessed an unscoped dashboard'; end if;

  -- Finance admins retain global finance access but not platform-admin data access.
  perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000006',true);
  perform set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000006","role":"authenticated"}',true);

  if not public.has_finance_access() or public.has_platform_role() then
    raise exception 'Finance role has an unexpected platform/finance permission combination';
  end if;
  select count(*) into v_count from public.payment_records;
  if v_count <> 2 then raise exception 'Finance admin cannot read all payment records'; end if;
  select count(*) into v_count from public.season_fee_configs;
  if v_count <> 2 then raise exception 'Finance admin cannot read all season fee configurations'; end if;
  select count(*) into v_count from public.profiles
  where id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
  if v_count <> 0 then raise exception 'Finance admin gained unrelated profile access'; end if;
  select count(*) into v_count from public.fixtures
  where id in ('27000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000002');
  if v_count <> 0 then raise exception 'Finance admin gained platform fixture access'; end if;

  -- A captain sees only their own team's payment and fixture data.
  perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
  perform set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',true);

  select count(*) into v_count from public.payment_records
  where season_team_id in ('24000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000003');
  if v_count <> 1 then raise exception 'Captain can read payment records outside their own team'; end if;
  select count(*) into v_count from public.team_memberships
  where id in ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Captain can read memberships outside their own team'; end if;
  select count(*) into v_count from public.fixtures
  where id in ('27000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000002');
  if v_count <> 1 then raise exception 'Captain can read fixtures outside their own team'; end if;

  -- Global admin is the only role that receives cross-location identity/review access.
  perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',true);
  perform set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000005","role":"authenticated"}',true);

  select count(*) into v_count from public.profiles
  where id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
  if v_count <> 2 then raise exception 'Global admin cannot read both location profiles'; end if;
  select count(*) into v_count from public.player_registration_reviews;
  if v_count <> 1 then raise exception 'Global admin cannot read the global identity-review queue'; end if;
  select count(*) into v_count from public.fixture_availability
  where id in ('29000000-0000-0000-0000-000000000001','29000000-0000-0000-0000-000000000002');
  if v_count <> 2 then raise exception 'Global admin cannot read availability across locations'; end if;

  raise notice 'Location-admin, player, captain, finance-admin and global-admin RLS role matrix passed';
end;
$location_admin_role_matrix$;

reset role;
rollback;

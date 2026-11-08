-- Disposable role/RLS integration test. Every fixture row is rolled back.
-- The location admin is assigned to Location A only; Location B must stay private.
begin;

insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
values
 ('00000000-0000-4000-8000-000000000001','authenticated','authenticated','ci-player-a@openplay.invalid','','{}'::jsonb,now(),now()),
 ('00000000-0000-4000-8000-000000000002','authenticated','authenticated','ci-captain-a@openplay.invalid','','{}'::jsonb,now(),now()),
 ('00000000-0000-4000-8000-000000000003','authenticated','authenticated','ci-player-b@openplay.invalid','','{}'::jsonb,now(),now()),
 ('00000000-0000-4000-8000-000000000004','authenticated','authenticated','ci-location-admin@openplay.invalid','','{}'::jsonb,now(),now()),
 ('00000000-0000-4000-8000-000000000005','authenticated','authenticated','ci-global-admin@openplay.invalid','','{}'::jsonb,now(),now());

insert into public.locations (id,name,slug,town,region,is_active)
values
 ('00000000-0000-4000-8000-000000000010','CI Location A','ci-location-a','CI Test','CI',true),
 ('00000000-0000-4000-8000-000000000011','CI Location B','ci-location-b','CI Test','CI',false);

insert into public.user_roles (user_id,role,granted_by)
values
 ('00000000-0000-4000-8000-000000000004','league_admin','00000000-0000-4000-8000-000000000005'),
 ('00000000-0000-4000-8000-000000000005','admin','00000000-0000-4000-8000-000000000005');

insert into public.location_admin_assignments (user_id,location_id,assigned_by)
values ('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000005');

insert into public.leagues (id,location_id,name,slug,is_published)
values
 ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010','CI League A','ci-league-a',false),
 ('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000011','CI League B','ci-league-b',false);

insert into public.seasons (id,league_id,name,season_number,is_public)
values
 ('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000020','CI Season A',1,false),
 ('00000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000021','CI Season B',1,false);

insert into public.teams (id,created_by)
values
 ('00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000041','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000042','00000000-0000-4000-8000-000000000003'),
 ('00000000-0000-4000-8000-000000000043','00000000-0000-4000-8000-000000000003');

insert into public.season_teams (id,team_id,season_id,name,slug,registration_status)
values
 ('00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000030','CI A Team One','ci-a-team-one','approved'),
 ('00000000-0000-4000-8000-000000000051','00000000-0000-4000-8000-000000000041','00000000-0000-4000-8000-000000000030','CI A Team Two','ci-a-team-two','approved'),
 ('00000000-0000-4000-8000-000000000052','00000000-0000-4000-8000-000000000042','00000000-0000-4000-8000-000000000031','CI B Team One','ci-b-team-one','approved'),
 ('00000000-0000-4000-8000-000000000053','00000000-0000-4000-8000-000000000043','00000000-0000-4000-8000-000000000031','CI B Team Two','ci-b-team-two','approved');

insert into public.players (user_id,full_name,phone,email,date_of_birth,registration_status)
values
 ('00000000-0000-4000-8000-000000000001','CI Player A','+447700900001','ci-player-a@openplay.invalid',date '1990-01-01','registered'),
 ('00000000-0000-4000-8000-000000000002','CI Captain A','+447700900002','ci-captain-a@openplay.invalid',date '1990-01-02','registered'),
 ('00000000-0000-4000-8000-000000000003','CI Player B','+447700900003','ci-player-b@openplay.invalid',date '1990-01-03','registered');

insert into public.team_memberships (id,season_team_id,user_id,status,is_captain)
values
 ('00000000-0000-4000-8000-000000000060','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000002','active',true),
 ('00000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000001','active',false),
 ('00000000-0000-4000-8000-000000000062','00000000-0000-4000-8000-000000000052','00000000-0000-4000-8000-000000000003','active',true);

insert into public.fixtures (id,season_id,gameweek,fixture_number,home_team_id,away_team_id)
values
 ('00000000-0000-4000-8000-000000000070','00000000-0000-4000-8000-000000000030',1,1,'00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000051'),
 ('00000000-0000-4000-8000-000000000071','00000000-0000-4000-8000-000000000031',1,1,'00000000-0000-4000-8000-000000000052','00000000-0000-4000-8000-000000000053');

-- Ordinary player: own profile/player record and own team's public/member surface only.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $player_role$
declare v_count integer; v_denied boolean := false;
begin
  if public.has_global_admin_role() or public.has_platform_role() then
    raise exception 'Ordinary player unexpectedly has an admin role';
  end if;
  select count(*) into v_count from public.profiles where id='00000000-0000-4000-8000-000000000001';
  if v_count <> 1 then raise exception 'Player cannot read their own profile'; end if;
  select count(*) into v_count from public.profiles where id='00000000-0000-4000-8000-000000000003';
  if v_count <> 0 then raise exception 'Player can read another profile'; end if;
  select count(*) into v_count from public.players where user_id='00000000-0000-4000-8000-000000000001';
  if v_count <> 1 then raise exception 'Player cannot read their own player record'; end if;
  select count(*) into v_count from public.players where user_id='00000000-0000-4000-8000-000000000003';
  if v_count <> 0 then raise exception 'Player can read another player record'; end if;
  select count(*) into v_count from public.fixtures where id='00000000-0000-4000-8000-000000000070';
  if v_count <> 1 then raise exception 'Player cannot see their active team fixture'; end if;
  select count(*) into v_count from public.fixtures where id='00000000-0000-4000-8000-000000000071';
  if v_count <> 0 then raise exception 'Player can see an unrelated location fixture'; end if;
  begin
    perform public.get_admin_competition_setup();
  exception when others then
    if sqlerrm = 'Administrator permission required' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Ordinary player unexpectedly accessed admin setup'; end if;
end;
$player_role$;
reset role;

-- Captain: can see their own team's memberships and fixtures, never another location.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $captain_role$
declare v_count integer; v_denied boolean := false;
begin
  if not public.is_active_team_captain('00000000-0000-4000-8000-000000000050') then
    raise exception 'Captain membership was not recognised';
  end if;
  if public.has_global_admin_role() or public.has_platform_role() then
    raise exception 'Captain unexpectedly has an admin role';
  end if;
  select count(*) into v_count from public.team_memberships where season_team_id='00000000-0000-4000-8000-000000000050';
  if v_count <> 2 then raise exception 'Captain cannot see their own team roster'; end if;
  select count(*) into v_count from public.team_memberships where season_team_id='00000000-0000-4000-8000-000000000052';
  if v_count <> 0 then raise exception 'Captain can see another location roster'; end if;
  select count(*) into v_count from public.fixtures where id='00000000-0000-4000-8000-000000000070';
  if v_count <> 1 then raise exception 'Captain cannot see their own team fixture'; end if;
  select count(*) into v_count from public.fixtures where id='00000000-0000-4000-8000-000000000071';
  if v_count <> 0 then raise exception 'Captain can see another location fixture'; end if;
  begin
    perform public.get_admin_competition_setup();
  exception when others then
    if sqlerrm = 'Administrator permission required' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Captain unexpectedly accessed admin setup'; end if;
end;
$captain_role$;
reset role;

-- Location admin: direct RLS reads are not a shortcut around scoped admin RPCs.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',true);
do $location_admin_role$
declare v_count integer; v_setup jsonb; v_denied boolean := false;
begin
  if not public.has_platform_role() then raise exception 'Location admin role was not recognised'; end if;
  if public.has_global_admin_role() then raise exception 'Location admin was incorrectly classified as global'; end if;
  select count(*) into v_count from public.leagues where id in ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000021');
  if v_count <> 0 then raise exception 'Location admin can directly read private leagues'; end if;
  select count(*) into v_count from public.profiles where id in ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000003');
  if v_count <> 0 then raise exception 'Location admin can directly read player profiles'; end if;
  select count(*) into v_count from public.players where user_id in ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000003');
  if v_count <> 0 then raise exception 'Location admin can directly read player identity records'; end if;
  select count(*) into v_count from public.user_roles where user_id='00000000-0000-4000-8000-000000000005';
  if v_count <> 0 then raise exception 'Location admin can directly read another administrator role'; end if;
  select count(*) into v_count from public.team_memberships where season_team_id in ('00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000052');
  if v_count <> 0 then raise exception 'Location admin can directly read team memberships'; end if;
  v_setup := public.get_admin_competition_setup();
  if jsonb_array_length(v_setup->'locations') <> 1
     or v_setup->'locations'->0->>'id' <> '00000000-0000-4000-8000-000000000010' then
    raise exception 'Scoped admin setup did not return only the assigned location';
  end if;
  if jsonb_array_length(v_setup->'leagues') <> 1
     or v_setup->'leagues'->0->>'id' <> '00000000-0000-4000-8000-000000000020' then
    raise exception 'Scoped admin setup did not return only the assigned league';
  end if;
  if exists (
    select 1 from jsonb_array_elements(v_setup->'registered_players') item
    where item->>'user_id' = '00000000-0000-4000-8000-000000000003'
  ) then raise exception 'Scoped admin setup leaked a player from another location'; end if;

  perform public.admin_create_league('00000000-0000-4000-8000-000000000010','CI Assigned League','six_a_side',null);
  begin
    perform public.admin_create_league('00000000-0000-4000-8000-000000000011','CI Unassigned League','six_a_side',null);
  exception when others then
    if sqlerrm = 'You are not assigned to this location' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin created a league outside their assignment'; end if;

  v_denied := false;
  begin
    perform public.admin_list_location_assignments(null);
  exception when others then
    if sqlerrm = 'Global administrator permission required' then v_denied := true; else raise; end if;
  end;
  if not v_denied then raise exception 'Location admin accessed global assignment administration'; end if;
end;
$location_admin_role$;
reset role;

-- Global admin: global visibility and global-only assignment administration remain available.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
do $global_admin_role$
declare v_count integer; v_setup jsonb;
begin
  if not public.has_global_admin_role() then raise exception 'Global admin role was not recognised'; end if;
  select count(*) into v_count from public.profiles where id in (
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000003'
  );
  if v_count <> 3 then raise exception 'Global admin cannot read all player profiles'; end if;
  select count(*) into v_count from public.leagues where id in ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000021');
  if v_count <> 2 then raise exception 'Global admin cannot read both private leagues'; end if;
  select count(*) into v_count from public.admin_list_location_assignments(null);
  if v_count <> 1 then raise exception 'Global admin cannot list location assignments'; end if;
  v_setup := public.get_admin_competition_setup();
  if jsonb_array_length(v_setup->'locations') <> 2 then
    raise exception 'Global admin setup did not return all locations';
  end if;
end;
$global_admin_role$;
reset role;

rollback;

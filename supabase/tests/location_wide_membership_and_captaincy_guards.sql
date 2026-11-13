-- Location-wide membership exclusivity, cross-area independence and future
-- season captaincy. Runs only against the disposable local Supabase database.
do $location_membership_guards$
declare
  v_player uuid:=gen_random_uuid();
  v_player_two uuid:=gen_random_uuid();
  v_captain_a uuid:=gen_random_uuid();
  v_captain_b uuid:=gen_random_uuid();
  v_captain_c uuid:=gen_random_uuid();
  v_location_a uuid;
  v_location_b uuid;
  v_league_a uuid;
  v_league_a_two uuid;
  v_league_b uuid;
  v_season_a uuid;
  v_season_a_two uuid;
  v_future_season uuid;
  v_season_b uuid;
  v_team_a uuid;
  v_team_a_two uuid;
  v_team_b uuid;
  v_team_future uuid;
  v_st_a uuid;
  v_st_a_two uuid;
  v_st_b uuid;
  v_st_future uuid;
  v_player_membership uuid;
  v_pending_membership uuid;
  v_error text;
begin
  if has_table_privilege('authenticated','public.team_memberships','INSERT')
     or has_table_privilege('authenticated','public.team_memberships','UPDATE') then
    raise exception 'Authenticated users retain direct membership table write privileges';
  end if;

  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_player,'authenticated','authenticated','ci-area-player@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player_two,'authenticated','authenticated','ci-area-player-two@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_captain_a,'authenticated','authenticated','ci-area-captain-a@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_captain_b,'authenticated','authenticated','ci-area-captain-b@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_captain_c,'authenticated','authenticated','ci-area-captain-c@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_genuine)
  values
    (v_player,'Area Test Player','+447700930001','ci-area-player@openplay.invalid',date '1990-01-01','registered',true),
    (v_player_two,'Area Test Player Two','+447700930002','ci-area-player-two@openplay.invalid',date '1990-01-02','registered',true),
    (v_captain_a,'Area Captain A','+447700930003','ci-area-captain-a@openplay.invalid',date '1990-01-03','registered',true),
    (v_captain_b,'Area Captain B','+447700930004','ci-area-captain-b@openplay.invalid',date '1990-01-04','registered',true),
    (v_captain_c,'Area Captain C','+447700930005','ci-area-captain-c@openplay.invalid',date '1990-01-05','registered',true);

  insert into public.locations(name,slug,town)
  values('Area Guard Location A','area-guard-a','Bideford')
  returning id into v_location_a;
  insert into public.locations(name,slug,town)
  values('Area Guard Location B','area-guard-b','Barnstaple')
  returning id into v_location_b;

  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location_a,'Area Guard League A','area-guard-league-a','six_a_side',true)
  returning id into v_league_a;
  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location_a,'Area Guard League A2','area-guard-league-a2','six_a_side',true)
  returning id into v_league_a_two;
  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location_b,'Area Guard League B','area-guard-league-b','six_a_side',true)
  returning id into v_league_b;

  insert into public.seasons(league_id,name,status,is_public)
  values(v_league_a,'Area Guard Season A','registration_open',true)
  returning id into v_season_a;
  insert into public.seasons(league_id,name,status,is_public)
  values(v_league_a_two,'Area Guard Season A2','registration_open',true)
  returning id into v_season_a_two;
  insert into public.seasons(league_id,name,status,is_public)
  values(v_league_b,'Area Guard Season B','registration_open',true)
  returning id into v_season_b;

  insert into public.teams(created_by) values(v_captain_a) returning id into v_team_a;
  insert into public.teams(created_by) values(v_captain_b) returning id into v_team_a_two;
  insert into public.teams(created_by) values(v_captain_c) returning id into v_team_b;

  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_team_a,v_season_a,'Area A Club','area-a-club','approved',v_captain_a)
  returning id into v_st_a;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_team_a_two,v_season_a_two,'Area A Other League Club','area-a-other-league-club','approved',v_captain_b)
  returning id into v_st_a_two;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_team_b,v_season_b,'Area B Club','area-b-club','approved',v_captain_c)
  returning id into v_st_b;

  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values
    (v_st_a,v_captain_a,'active',true),
    (v_st_a,v_player,'active',false),
    (v_st_a_two,v_captain_b,'active',true),
    (v_st_b,v_captain_c,'active',true);

  select id into v_player_membership from public.team_memberships
  where season_team_id=v_st_a and user_id=v_player;

  -- Same area, different league: joining another club is blocked until leaving.
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  begin
    perform public.request_team_membership(v_st_a_two);
    raise exception 'Player was incorrectly allowed to request a second club in the same area';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'You are already attached to another club in this area%' then raise; end if;
  end;

  -- Player leaves first; a captain-approved join in another league of the same
  -- area is then allowed, with the old membership retained as history.
  perform public.leave_team_membership(v_player_membership);
  perform public.request_team_membership(v_st_a_two);
  select id into v_pending_membership from public.team_memberships
  where season_team_id=v_st_a_two and user_id=v_player and status='pending';
  perform set_config('request.jwt.claim.sub',v_captain_b::text,true);
  perform public.resolve_team_membership_request(v_pending_membership,'approved');
  if not exists(select 1 from public.team_memberships where id=v_player_membership and status='left')
     or not exists(select 1 from public.team_memberships where season_team_id=v_st_a_two and user_id=v_player and status='active') then
    raise exception 'Player did not move between clubs through the leave-then-captain-approval workflow';
  end if;

  -- A second pending club request in the same area is blocked.
  perform set_config('request.jwt.claim.sub',v_player_two::text,true);
  perform public.request_team_membership(v_st_a);
  begin
    perform public.request_team_membership(v_st_a_two);
    raise exception 'Player was incorrectly allowed multiple pending club requests in one area';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'You already have a pending team request for another club in this area%' then raise; end if;
  end;

  -- Different locations remain independent.
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  perform public.request_team_membership(v_st_b);
  select id into v_pending_membership from public.team_memberships
  where season_team_id=v_st_b and user_id=v_player and status='pending';
  perform set_config('request.jwt.claim.sub',v_captain_c::text,true);
  perform public.resolve_team_membership_request(v_pending_membership,'approved');
  if not exists(select 1 from public.team_memberships where season_team_id=v_st_b and user_id=v_player and status='active') then
    raise exception 'A player could not join a club in a different location';
  end if;

  -- A player cannot hold captaincy for a second club in the same active area.
  perform set_config('request.jwt.claim.sub',v_captain_a::text,true);
  begin
    insert into public.team_memberships(season_team_id,user_id,status,is_captain)
    values(v_st_a_two,v_captain_a,'active',true);
    raise exception 'Player was incorrectly allowed captaincy for two clubs in one area';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error not like 'A player can represent only one club in the same area%' then raise; end if;
  end;

  -- A captain may hold a separate future-season captaincy after the prior
  -- season is complete; completed-season membership is historical, not active.
  update public.seasons set status='completed' where id=v_season_a_two;
  insert into public.seasons(league_id,name,status,is_public)
  values(v_league_a_two,'Area Guard Future Season','registration_open',true)
  returning id into v_future_season;
  insert into public.teams(created_by) values(v_captain_b) returning id into v_team_future;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_team_future,v_future_season,'Area Future Club','area-future-club','approved',v_captain_b)
  returning id into v_st_future;
  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_st_future,v_captain_b,'active',true);
  if not exists(select 1 from public.team_memberships where season_team_id=v_st_future and user_id=v_captain_b and status='active' and is_captain=true) then
    raise exception 'Future-season captaincy did not activate after the prior season completed';
  end if;
end;
$location_membership_guards$;

-- Team Instagram profile validation and persistence regression tests.
-- Runs only against the disposable local Supabase database in CI.
do $team_instagram_profiles$
declare
  v_user_one constant uuid := '93000000-0000-4000-8000-000000000001';
  v_user_two constant uuid := '93000000-0000-4000-8000-000000000002';
  v_user_three constant uuid := '93000000-0000-4000-8000-000000000003';
  v_user_four constant uuid := '93000000-0000-4000-8000-000000000004';
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_team public.season_teams;
  v_rejected boolean;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values
    (v_user_one,'authenticated','authenticated','ci-instagram-one@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_user_two,'authenticated','authenticated','ci-instagram-two@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_user_three,'authenticated','authenticated','ci-instagram-three@openplay.invalid','','{}'::jsonb,now(),now()),
    (v_user_four,'authenticated','authenticated','ci-instagram-four@openplay.invalid','','{}'::jsonb,now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status)
  values
    (v_user_one,'Instagram Player One','+447700901101','ci-instagram-one@openplay.invalid',date '1990-01-01','registered'),
    (v_user_two,'Instagram Player Two','+447700901102','ci-instagram-two@openplay.invalid',date '1990-01-02','registered'),
    (v_user_three,'Instagram Player Three','+447700901103','ci-instagram-three@openplay.invalid',date '1990-01-03','registered'),
    (v_user_four,'Instagram Player Four','+447700901104','ci-instagram-four@openplay.invalid',date '1990-01-04','registered');

  insert into public.locations(name,slug,town,region,is_active)
  values('CI Instagram Profiles','ci-instagram-profiles','Bideford','North Devon',false)
  returning id into v_location;

  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Instagram Profiles','ci-instagram-profiles',false)
  returning id into v_league;

  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Instagram Profiles',991,'registration_open',false)
  returning id into v_season;

  perform set_config('request.jwt.claim.sub',v_user_one::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user_one,'role','authenticated')::text,true);
  select * into v_team
  from public.register_team(v_season,'Instagram Team One',null,null,'@OpenPlay_Official','https://instagram.com/OpenPlay_Official');

  if v_team.instagram_handle is distinct from 'OpenPlay_Official'
     or v_team.instagram_url is distinct from 'https://www.instagram.com/OpenPlay_Official/' then
    raise exception 'Handle prefix removal or canonical Instagram URL normalisation failed';
  end if;
  if v_team.registration_status <> 'pending' then
    raise exception 'Instagram fields changed the team approval lifecycle';
  end if;
  if not exists(
    select 1 from public.team_memberships
    where season_team_id=v_team.id and user_id=v_user_one and status='pending' and is_captain=false
  ) then
    raise exception 'Instagram registration changed the pending captain approval lifecycle';
  end if;

  perform set_config('request.jwt.claim.sub',v_user_two::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user_two,'role','authenticated')::text,true);
  select * into v_team
  from public.register_team(v_season,'Instagram Handle Only',null,null,'@OpenPlay_Handle',null);
  if v_team.instagram_handle is distinct from 'OpenPlay_Handle' or v_team.instagram_url is not null then
    raise exception 'Handle-only registration should persist the handle without a public link';
  end if;

  perform set_config('request.jwt.claim.sub',v_user_three::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user_three,'role','authenticated')::text,true);
  select * into v_team
  from public.register_team(v_season,'Instagram Link Only',null,null,null,'HTTPS://INSTAGRAM.COM/OpenPlay_Link');
  if v_team.instagram_handle is not null
     or v_team.instagram_url is distinct from 'https://www.instagram.com/OpenPlay_Link/' then
    raise exception 'Link-only registration should persist a canonical URL without inventing a handle';
  end if;

  perform set_config('request.jwt.claim.sub',v_user_four::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_user_four,'role','authenticated')::text,true);
  select * into v_team
  from public.register_team(v_season,'Instagram Default Port',null,null,null,'https://instagram.com:443/OpenPlay_Port');
  if v_team.instagram_url is distinct from 'https://www.instagram.com/OpenPlay_Port/' then
    raise exception 'Explicit default HTTPS port was not canonicalised';
  end if;

  v_rejected := false;
  begin
    perform * from public.register_team(v_season,'Invalid Instagram Handle',null,null,'not a handle',null);
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then raise exception 'Invalid Instagram handle was accepted'; end if;

  v_rejected := false;
  begin
    perform * from public.register_team(v_season,'Invalid Instagram Domain',null,null,null,'https://instagram.com.evil.example/openplay');
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then raise exception 'Non-Instagram domain was accepted as a profile URL'; end if;

  v_rejected := false;
  begin
    perform * from public.register_team(v_season,'Invalid Instagram Query',null,null,null,'https://www.instagram.com/openplay/?next=https://evil.example');
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then raise exception 'Instagram URL with query parameters was accepted'; end if;

  if pg_catalog.to_regprocedure('public.register_team(uuid,text,text,text)') is not null then
    raise exception 'Legacy four-argument overload remains and could make PostgREST calls ambiguous';
  end if;
  if pg_catalog.has_function_privilege('anon','public.register_team(uuid,text,text,text,text,text)','EXECUTE') then
    raise exception 'Anonymous users must not submit team registrations';
  end if;
  if not pg_catalog.has_function_privilege('authenticated','public.register_team(uuid,text,text,text,text,text)','EXECUTE') then
    raise exception 'Authenticated users must be able to submit team registrations';
  end if;
  if position('instagram_handle' in pg_catalog.pg_get_functiondef('public.get_admin_dashboard_contextual(uuid,uuid,uuid)'::regprocedure))=0
     or position('instagram_url' in pg_catalog.pg_get_functiondef('public.get_admin_dashboard_contextual(uuid,uuid,uuid)'::regprocedure))=0 then
    raise exception 'Administrator team-application RPC must include the submitted Instagram profile fields';
  end if;

  raise notice 'Team Instagram profile validation, canonicalisation, approval visibility and registration lifecycle regressions passed';
end;
$team_instagram_profiles$;

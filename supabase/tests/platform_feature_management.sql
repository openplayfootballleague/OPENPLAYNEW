-- Platform feature-management permissions and enforcement boundaries.
begin;

do $test$
declare
  v_enabled boolean;
  v_count integer;
  v_user uuid:=gen_random_uuid();
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_team uuid;
  v_season_team uuid;
  v_support uuid;
  v_failed boolean;
begin
  if not exists (
    select 1 from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='platform_feature_flags' and c.relrowsecurity
  ) then raise exception 'Platform feature flags must have RLS enabled'; end if;

  select count(*) into v_count from public.platform_feature_flags
  where feature_key in ('team_recruitment','announcements') and enabled is true;
  if v_count<>2 then raise exception 'Both feature flags must default to enabled'; end if;

  if has_table_privilege('anon','public.platform_feature_flags','SELECT')
     or has_table_privilege('authenticated','public.platform_feature_flags','SELECT')
     or has_table_privilege('anon','public.platform_feature_flags','UPDATE')
     or has_table_privilege('authenticated','public.platform_feature_flags','UPDATE') then
    raise exception 'Feature flags must not grant table-wide direct access';
  end if;
  if not has_column_privilege('anon','public.platform_feature_flags','enabled','SELECT')
     or not has_column_privilege('authenticated','public.platform_feature_flags','feature_key','SELECT')
     or has_column_privilege('anon','public.platform_feature_flags','updated_by','SELECT')
     or has_column_privilege('authenticated','public.platform_feature_flags','updated_at','SELECT') then
    raise exception 'Public feature status must expose only the two non-sensitive columns';
  end if;

  if exists (
    select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in ('get_public_team_recruitment_status','get_public_announcement_status')
      and p.prosecdef
  ) then raise exception 'Public status functions must run with invoker privileges'; end if;

  if has_function_privilege('anon','public.admin_set_platform_feature_flag(text,boolean,text)','EXECUTE')
     or has_function_privilege('anon','public.get_admin_platform_feature_flags()','EXECUTE')
     or has_function_privilege('anon','public.is_platform_feature_enabled(text)','EXECUTE')
     or has_function_privilege('authenticated','public.is_platform_feature_enabled(text)','EXECUTE')
     or has_function_privilege('anon','public.enforce_team_recruitment_feature_flag()','EXECUTE')
     or has_function_privilege('authenticated','public.enforce_team_recruitment_feature_flag()','EXECUTE')
     or has_function_privilege('anon','public.enforce_announcement_feature_flag()','EXECUTE')
     or has_function_privilege('authenticated','public.enforce_announcement_feature_flag()','EXECUTE')
     or has_function_privilege('anon','public.enforce_announcement_message_feature_flag()','EXECUTE')
     or has_function_privilege('authenticated','public.enforce_announcement_message_feature_flag()','EXECUTE') then
    raise exception 'Admin and internal feature functions must not be anonymously or directly exposed';
  end if;
  if not has_function_privilege('authenticated','public.admin_set_platform_feature_flag(text,boolean,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_admin_platform_feature_flags()','EXECUTE')
     or not has_function_privilege('anon','public.get_public_team_recruitment_status()','EXECUTE')
     or not has_function_privilege('anon','public.get_public_announcement_status()','EXECUTE') then
    raise exception 'Feature-management RPC grants are incomplete';
  end if;

  if not exists (select 1 from pg_catalog.pg_trigger where tgname='enforce_team_recruitment_feature_flag' and not tgisinternal)
     or not exists (select 1 from pg_catalog.pg_trigger where tgname='enforce_announcement_feature_flag' and not tgisinternal)
     or not exists (select 1 from pg_catalog.pg_trigger where tgname='enforce_announcement_message_feature_flag' and not tgisinternal) then
    raise exception 'One or more feature enforcement triggers are missing';
  end if;

  select public.is_platform_feature_enabled('team_recruitment') into v_enabled;
  if not v_enabled then raise exception 'Recruitment must be enabled by default'; end if;
  select public.get_public_team_recruitment_status() into v_enabled;
  if not v_enabled then raise exception 'Public recruitment status must be enabled by default'; end if;
  select public.get_public_announcement_status() into v_enabled;
  if not v_enabled then raise exception 'Public announcement status must be enabled by default'; end if;

  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values(v_user,'authenticated','authenticated','ci-platform-feature@openplay.invalid','','{}'::jsonb,now(),now(),now());
  -- Auth signup may create the profile through the production auth trigger.
  -- Make the fixture deterministic whether that trigger has already run or not.
  insert into public.profiles(id,display_name,account_retention_status)
  values(v_user,'Platform Feature Test','active')
  on conflict (id) do update
  set display_name=excluded.display_name,
      account_retention_status=excluded.account_retention_status;
  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
  values(v_user,'Platform Feature Test','+447700929991','ci-platform-feature@openplay.invalid',date '1990-01-01','registered',false);

  perform set_config('request.jwt.claim.sub',v_user::text,true);
  v_failed:=false;
  begin
    perform public.admin_set_platform_feature_flag('team_recruitment',false,'Unauthorised test change');
  exception when sqlstate '42501' then
    v_failed:=true;
  end;
  if not v_failed then raise exception 'A non-admin user must not change platform feature flags'; end if;
  perform set_config('request.jwt.claim.sub','',true);

  -- The clean CI database is replayed without seed data, so this test must
  -- provision its own location instead of depending on an existing one.
  insert into public.locations(name,slug,town,region,is_active)
  values('Feature Flag Test Location','ci-feature-flag-test-location','Bideford','Devon',true)
  returning id into v_location;
  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location,'Feature Flag Test League','ci-feature-flag-test-league','six_a_side',false) returning id into v_league;
  insert into public.seasons(league_id,name,status,is_public)
  values(v_league,'Feature Flag Test Season','registration_open',false) returning id into v_season;
  insert into public.teams(created_by) values(v_user) returning id into v_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_team,v_season,'Feature Flag Test Team','ci-feature-flag-test-team','approved',v_user) returning id into v_season_team;
  insert into public.message_conversations(kind,title,created_by)
  values('support','Feature flag test support conversation',v_user) returning id into v_support;

  update public.platform_feature_flags set enabled=false where feature_key='team_recruitment';
  if public.get_public_team_recruitment_status() is distinct from false then
    raise exception 'Public recruitment status must reflect the platform switch';
  end if;
  v_failed:=false;
  begin
    insert into public.team_memberships(season_team_id,user_id,status,is_captain)
    values(v_season_team,v_user,'pending',false);
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then raise exception 'Paused team recruitment must reject new pending memberships'; end if;

  update public.platform_feature_flags set enabled=false where feature_key='announcements';
  if public.get_public_announcement_status() is distinct from false then
    raise exception 'Public announcement status must reflect the platform switch';
  end if;
  v_failed:=false;
  begin
    insert into public.message_conversations(kind,title,created_by,target_type)
    values('announcement','Feature flag test announcement',v_user,'everyone');
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then raise exception 'Paused announcements must reject new broadcast conversations'; end if;
  v_failed:=false;
  begin
    insert into public.messages(conversation_id,sender_id,body,message_type)
    values(v_support,v_user,'Feature flag test announcement message','announcement');
  exception when sqlstate '55000' then v_failed:=true;
  end;
  if not v_failed then raise exception 'Paused announcements must reject team announcement messages'; end if;
end;
$test$;

rollback;

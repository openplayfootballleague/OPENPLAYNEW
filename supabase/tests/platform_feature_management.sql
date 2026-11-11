-- Platform feature-management permissions and enforcement boundaries.
begin;

do $$
declare
  v_enabled boolean;
  v_count integer;
begin
  if not exists (
    select 1 from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='platform_feature_flags' and c.relrowsecurity
  ) then raise exception 'Platform feature flags must have RLS enabled'; end if;

  select count(*) into v_count
  from public.platform_feature_flags
  where feature_key in ('team_recruitment','announcements') and enabled is true;
  if v_count<>2 then raise exception 'Both feature flags must default to enabled'; end if;

  if has_table_privilege('anon','public.platform_feature_flags','SELECT')
     or has_table_privilege('authenticated','public.platform_feature_flags','SELECT')
     or has_table_privilege('anon','public.platform_feature_flags','UPDATE')
     or has_table_privilege('authenticated','public.platform_feature_flags','UPDATE') then
    raise exception 'Feature flags must be accessed only through authorised RPCs';
  end if;

  if not has_column_privilege('anon','public.platform_feature_flags','enabled','SELECT')
     or not has_column_privilege('authenticated','public.platform_feature_flags','feature_key','SELECT')
     or has_column_privilege('anon','public.platform_feature_flags','updated_by','SELECT')
     or has_column_privilege('authenticated','public.platform_feature_flags','updated_at','SELECT') then
    raise exception 'Public feature status must expose only the two non-sensitive columns';
  end if;

  if exists (
    select 1 from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in ('get_public_team_recruitment_status','get_public_announcement_status')
      and p.prosecdef
  ) then raise exception 'Public status functions must run with invoker privileges'; end if;

  if has_function_privilege('anon','public.admin_set_platform_feature_flag(text,boolean,text)','EXECUTE')
     or has_function_privilege('anon','public.get_admin_platform_feature_flags()','EXECUTE') then
    raise exception 'Anonymous users must not execute feature-management RPCs';
  end if;

  if not has_function_privilege('authenticated','public.admin_set_platform_feature_flag(text,boolean,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_admin_platform_feature_flags()','EXECUTE') then
    raise exception 'Authenticated role must be able to call the permission-checked feature RPCs';
  end if;

  if not exists (
    select 1 from pg_catalog.pg_trigger
    where tgname='enforce_team_recruitment_feature_flag' and not tgisinternal
  ) then raise exception 'Team recruitment enforcement trigger is missing'; end if;
  if not exists (
    select 1 from pg_catalog.pg_trigger
    where tgname='enforce_announcement_feature_flag' and not tgisinternal
  ) then raise exception 'Announcement enforcement trigger is missing'; end if;
  if not exists (
    select 1 from pg_catalog.pg_trigger
    where tgname='enforce_announcement_message_feature_flag' and not tgisinternal
  ) then raise exception 'Announcement message enforcement trigger is missing'; end if;

  select public.is_platform_feature_enabled('team_recruitment') into v_enabled;
  if not v_enabled then raise exception 'Recruitment must be enabled by default'; end if;
  select public.is_platform_feature_enabled('announcements') into v_enabled;
  if not v_enabled then raise exception 'Announcements must be enabled by default'; end if;

  if not has_function_privilege('anon','public.get_public_team_recruitment_status()','EXECUTE')
     or not has_function_privilege('anon','public.get_public_announcement_status()','EXECUTE') then
    raise exception 'Public status RPCs must be readable by anonymous visitors';
  end if;

  update public.platform_feature_flags set enabled=false where feature_key='team_recruitment';
  if public.get_public_team_recruitment_status() is distinct from false then
    raise exception 'Public recruitment status must reflect the platform switch';
  end if;
  update public.platform_feature_flags set enabled=true where feature_key='team_recruitment';

  insert into public.message_conversations(kind,title,created_by)
  values('support','Feature flag test support conversation',v_user)
  returning id into v_support;

  update public.platform_feature_flags set enabled=false where feature_key='announcements';
  if public.get_public_announcement_status() is distinct from false then
    raise exception 'Public announcement status must reflect the platform switch';
  end if;
  update public.platform_feature_flags set enabled=true where feature_key='announcements';

end;
$;

do $
declare
  v_user uuid:=gen_random_uuid();
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_team uuid;
  v_season_team uuid;
  v_support uuid;
  v_failed boolean;
begin
  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_user,'authenticated','authenticated','ci-platform-feature@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.profiles(id,display_name,account_retention_status)
  values(v_user,'Platform Feature Test','active');

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
  values(v_user,'Platform Feature Test','+447700929991','ci-platform-feature@openplay.invalid',date '1990-01-01','registered',false);

  select id into v_location from public.locations where is_active=true order by created_at limit 1;
  if v_location is null then raise exception 'Feature flag regression requires an active location'; end if;

  insert into public.leagues(location_id,name,slug,format,is_published)
  values(v_location,'Feature Flag Test League','ci-feature-flag-test-league','six_a_side',false)
  returning id into v_league;

  insert into public.seasons(league_id,name,status,is_public)
  values(v_league,'Feature Flag Test Season','registration_open',false)
  returning id into v_season;

  insert into public.teams(created_by) values(v_user) returning id into v_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_by)
  values(v_team,v_season,'Feature Flag Test Team','ci-feature-flag-test-team','approved',v_user)
  returning id into v_season_team;

  update public.platform_feature_flags set enabled=false where feature_key='team_recruitment';
  v_failed:=false;
  begin
    insert into public.team_memberships(season_team_id,user_id,status,is_captain)
    values(v_season_team,v_user,'pending',false);
  exception when sqlstate '55000' then
    v_failed:=true;
  end;
  if not v_failed then raise exception 'Paused team recruitment must reject new pending memberships'; end if;

  update public.platform_feature_flags set enabled=false where feature_key='announcements';
  v_failed:=false;
  begin
    insert into public.message_conversations(kind,title,created_by,target_type)
    values('announcement','Feature flag test announcement',v_user,'everyone');
  exception when sqlstate '55000' then
    v_failed:=true;
  end;
  if not v_failed then raise exception 'Paused announcements must reject new broadcast conversations'; end if;

  v_failed:=false;
  begin
    insert into public.messages(conversation_id,sender_id,body,message_type)
    values(v_support,v_user,'Feature flag test announcement message','announcement');
  exception when sqlstate '55000' then
    v_failed:=true;
  end;
  if not v_failed then raise exception 'Paused announcements must reject team announcement messages'; end if;
end;
$;

rollback;

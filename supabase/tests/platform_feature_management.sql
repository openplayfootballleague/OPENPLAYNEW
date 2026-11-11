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

  update public.platform_feature_flags set enabled=false where feature_key='announcements';
  if public.get_public_announcement_status() is distinct from false then
    raise exception 'Public announcement status must reflect the platform switch';
  end if;
  update public.platform_feature_flags set enabled=true where feature_key='announcements';
end;
$$;

rollback;

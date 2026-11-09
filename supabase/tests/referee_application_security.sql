-- Regression checks for referee membership and application security.
do $$
declare
  v_role_check text;
  v_platform_role text;
  v_submit text;
  v_review text;
begin
  if not (select relrowsecurity from pg_class where oid='public.referee_applications'::regclass) then
    raise exception 'referee_applications must have RLS enabled';
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='referee_applications'
  ) then
    raise exception 'referee_applications must remain RPC-only with no direct client policies';
  end if;

  if has_table_privilege('anon','public.referee_applications','SELECT')
     or has_table_privilege('authenticated','public.referee_applications','SELECT')
     or has_table_privilege('authenticated','public.referee_applications','INSERT')
     or has_table_privilege('authenticated','public.referee_applications','UPDATE')
     or has_table_privilege('authenticated','public.referee_applications','DELETE') then
    raise exception 'referee_applications must not be directly accessible to client roles';
  end if;

  select pg_get_constraintdef(oid) into v_role_check
  from pg_constraint
  where conrelid='public.user_roles'::regclass and conname='user_roles_role_check';
  if v_role_check is null or v_role_check not ilike '%referee%' then
    raise exception 'user_roles must allow the referee role';
  end if;

  select pg_get_functiondef('public.has_platform_role()'::regprocedure) into v_platform_role;
  if v_platform_role ilike '%referee%' then
    raise exception 'referee must not inherit platform administrator access';
  end if;

  if not has_function_privilege('authenticated','public.has_referee_role()','EXECUTE')
     or has_function_privilege('anon','public.has_referee_role()','EXECUTE') then
    raise exception 'has_referee_role must be authenticated-only';
  end if;

  if not has_function_privilege('authenticated','public.get_my_referee_application()','EXECUTE')
     or has_function_privilege('anon','public.get_my_referee_application()','EXECUTE')
     or not has_function_privilege('authenticated','public.submit_referee_application(text,text,text,text,text,text[],text)','EXECUTE')
     or has_function_privilege('anon','public.submit_referee_application(text,text,text,text,text,text[],text)','EXECUTE') then
    raise exception 'self-service referee application RPC grants are incorrect';
  end if;

  if not has_function_privilege('authenticated','public.admin_get_referee_applications(text)','EXECUTE')
     or has_function_privilege('anon','public.admin_get_referee_applications(text)','EXECUTE')
     or not has_function_privilege('authenticated','public.admin_resolve_referee_application(uuid,text,text)','EXECUTE')
     or has_function_privilege('anon','public.admin_resolve_referee_application(uuid,text,text)','EXECUTE') then
    raise exception 'referee administration RPC grants are incorrect';
  end if;

  select pg_get_functiondef('public.submit_referee_application(text,text,text,text,text,text[],text)'::regprocedure)
    into v_submit;
  if v_submit not ilike '%auth.uid()%' or v_submit not ilike '%email_confirmed_at%' then
    raise exception 'referee application submission must require a signed-in, email-confirmed user';
  end if;

  select pg_get_functiondef('public.admin_resolve_referee_application(uuid,text,text)'::regprocedure)
    into v_review;
  if v_review not ilike '%has_global_admin_role()%'
     or v_review not ilike '%user_roles%'
     or v_review not ilike '%referee%' then
    raise exception 'referee approval must be a global-admin-only role grant';
  end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname='public' and tablename='referee_applications'
      and indexname='referee_applications_status_submitted_idx'
  ) then
    raise exception 'referee application review queue index is missing';
  end if;
end;
$$;

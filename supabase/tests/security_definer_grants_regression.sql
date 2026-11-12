-- Security privilege-boundary regression checks for isolated Supabase replay.
-- These assertions do not prove the internal role checks of each RPC; those
-- require authenticated positive/negative role-matrix tests.
do $security_definer_grants$
declare
  v_anon_executable text;
begin
  select string_agg(p.oid::regprocedure::text, ', ' order by p.proname)
    into v_anon_executable
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.prosecdef
    and pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE')
    -- These public RPCs expose only approved teams or published competition
    -- records at active locations; no private table access is granted.
    and p.oid::regprocedure::text not in (
      'get_public_team_directory(uuid)',
      'get_public_team_profile(uuid)',
      'get_public_season_club_leaders(uuid)'
    );

  if v_anon_executable is not null then
    raise exception 'Anonymous role can execute SECURITY DEFINER functions: %',
      v_anon_executable;
  end if;

  if pg_catalog.has_table_privilege('anon', 'public.user_roles', 'SELECT')
     or pg_catalog.has_table_privilege('anon', 'public.user_roles', 'INSERT')
     or pg_catalog.has_table_privilege('anon', 'public.user_roles', 'UPDATE')
     or pg_catalog.has_table_privilege('anon', 'public.user_roles', 'DELETE') then
    raise exception 'Anonymous role has direct privileges on user_roles';
  end if;

  if pg_catalog.has_table_privilege('authenticated', 'public.user_roles', 'INSERT')
     or pg_catalog.has_table_privilege('authenticated', 'public.user_roles', 'UPDATE')
     or pg_catalog.has_table_privilege('authenticated', 'public.user_roles', 'DELETE') then
    raise exception 'Authenticated clients can directly mutate user_roles';
  end if;

  if not pg_catalog.has_table_privilege('authenticated', 'public.user_roles', 'SELECT') then
    raise exception 'Expected authenticated self/admin role-read privilege is missing';
  end if;

  raise notice 'SECURITY DEFINER and user_roles privilege boundary assertions passed';
end;
$security_definer_grants$;

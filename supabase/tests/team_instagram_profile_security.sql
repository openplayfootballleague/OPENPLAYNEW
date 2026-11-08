-- Run after applying 20261108015000_team_instagram_profile.sql.
-- Each row must return true. This guards against public team-profile reads
-- accidentally broadening access to public.teams columns.
select
  not has_table_privilege('anon','public.teams','SELECT')
    as anonymous_users_cannot_select_team_table,
  not exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename='teams'
      and policyname='teams_select_public_instagram_profile'
  ) as no_permissive_public_team_table_policy,
  exists (
    select 1 from pg_proc p
    where p.oid='public.get_public_team_directory(uuid)'::regprocedure
      and p.prosecdef
      and pg_get_function_result(p.oid) ilike '%instagram_profile_url%'
      and pg_get_function_result(p.oid) ilike '%season_team_id%'
      and pg_get_functiondef(p.oid) ilike '%st.registration_status=''approved''%'
      and pg_get_functiondef(p.oid) ilike '%s.is_public=true%'
      and pg_get_functiondef(p.oid) ilike '%l.is_published=true%'
  ) as public_directory_rpc_is_security_definer_and_public_scope_filtered,
  has_function_privilege('anon','public.get_public_team_directory(uuid)','EXECUTE')
    and has_function_privilege('authenticated','public.get_public_team_directory(uuid)','EXECUTE')
    as public_directory_rpc_is_available_to_both_client_roles,
  not has_function_privilege('anon','public.update_team_instagram_profile(uuid,text)','EXECUTE')
    and has_function_privilege('authenticated','public.update_team_instagram_profile(uuid,text)','EXECUTE')
    as instagram_profile_mutation_is_authenticated_only,
  not has_function_privilege('anon','public.admin_get_team_social_profiles()','EXECUTE')
    and has_function_privilege('authenticated','public.admin_get_team_social_profiles()','EXECUTE')
    as admin_social_profile_rpc_is_not_anonymous;

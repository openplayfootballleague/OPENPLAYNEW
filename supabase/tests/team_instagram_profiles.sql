-- Team Instagram schema, public read boundary and role-scoped update RPCs.
do $team_instagram$
declare
  v_directory text:=lower(pg_catalog.pg_get_functiondef('public.get_public_team_directory(uuid)'::regprocedure));
  v_profile text:=lower(pg_catalog.pg_get_functiondef('public.get_public_team_profile(uuid)'::regprocedure));
  v_update text:=lower(pg_catalog.pg_get_functiondef('public.update_team_instagram_profile(uuid,text)'::regprocedure));
  v_update_details text:=lower(pg_catalog.pg_get_functiondef('public.update_team_instagram_details(uuid,text,text)'::regprocedure));
  v_admin text:=lower(pg_catalog.pg_get_functiondef('public.admin_get_team_social_profiles()'::regprocedure));
  v_five pg_catalog.pg_proc;
  v_six pg_catalog.pg_proc;
  v_url_constraint text;
  v_handle_constraint text;
begin
  select * into v_five from pg_catalog.pg_proc
   where oid='public.register_team(uuid,text,text,text,text)'::regprocedure;
  select * into v_six from pg_catalog.pg_proc
   where oid='public.register_team(uuid,text,text,text,text,text)'::regprocedure;

  if v_five.proargdefaults is not null or v_six.proargdefaults is not null then
    raise exception 'Five- and six-argument registration overloads must not add defaults that shadow the legacy four-argument RPC';
  end if;
  if not v_five.prosecdef or not v_six.prosecdef
     or not (v_five.proconfig @> array['search_path=""'])
     or not (v_six.proconfig @> array['search_path=""']) then
    raise exception 'Instagram registration overloads must be SECURITY DEFINER with an empty search_path';
  end if;
  if position('public.register_team(p_season_id,p_team_name,p_primary_colour,p_secondary_colour)' in lower(pg_catalog.pg_get_functiondef(v_five.oid)))=0 then
    raise exception 'Instagram URL registration must delegate to the existing eligibility-checked registration RPC';
  end if;
  if position('public.register_team(' in lower(pg_catalog.pg_get_functiondef(v_six.oid)))=0
     or position('instagram_handle' in lower(pg_catalog.pg_get_functiondef(v_six.oid)))=0 then
    raise exception 'Six-argument registration must preserve the existing registration workflow and store the separate handle';
  end if;

  select lower(pg_catalog.pg_get_constraintdef(oid)) into v_url_constraint
    from pg_catalog.pg_constraint
   where conrelid='public.teams'::regclass and conname='teams_instagram_profile_url_valid';
  select lower(pg_catalog.pg_get_constraintdef(oid)) into v_handle_constraint
    from pg_catalog.pg_constraint
   where conrelid='public.teams'::regclass and conname='teams_instagram_handle_valid';
  if v_url_constraint is null or position('https://www[.]instagram[.]com' in v_url_constraint)=0
     or position('[.]{2}' in v_url_constraint)=0 then
    raise exception 'Instagram profile URL constraint is missing or too permissive';
  end if;
  if v_handle_constraint is null or position('[.]{2}' in v_handle_constraint)=0 then
    raise exception 'Instagram handle constraint is missing or too permissive';
  end if;

  if not pg_catalog.has_function_privilege('anon','public.get_public_team_directory(uuid)','EXECUTE')
     or not pg_catalog.has_function_privilege('anon','public.get_public_team_profile(uuid)','EXECUTE')
     or not pg_catalog.has_function_privilege('authenticated','public.get_public_team_directory(uuid)','EXECUTE') then
    raise exception 'Public team directory/profile RPCs must be explicitly readable by public clients';
  end if;
  if pg_catalog.has_table_privilege('anon','public.teams','SELECT') then
    raise exception 'Anonymous clients must not receive direct SELECT access to public.teams';
  end if;
  if exists(
    select 1 from pg_catalog.pg_proc p
    cross join lateral pg_catalog.aclexplode(coalesce(p.proacl,pg_catalog.acldefault('f',p.proowner))) acl
    where p.oid in (
      'public.get_public_team_directory(uuid)'::regprocedure,
      'public.get_public_team_profile(uuid)'::regprocedure
    ) and acl.grantee=0 and acl.privilege_type='EXECUTE'
  ) then
    raise exception 'Public team RPCs must not rely on PUBLIC execute grants';
  end if;

  if not (select prosecdef and proconfig @> array['search_path=""']
    from pg_catalog.pg_proc where oid='public.get_public_team_directory(uuid)'::regprocedure)
     or position('registration_status' in v_directory)=0
     or position('approved' in v_directory)=0
     or position('is_public' in v_directory)=0
     or position('is_published' in v_directory)=0
     or position('registration_open' in v_directory)=0 then
    raise exception 'Public directory must expose only approved teams in published public registration-open/active/completed seasons';
  end if;
  if position('created_by' in lower(pg_catalog.pg_get_function_result('public.get_public_team_directory(uuid)'::regprocedure)))>0 then
    raise exception 'Public team directory must not expose creator identity';
  end if;
  if position('registration_status' in v_profile)=0 or position('is_public' in v_profile)=0
     or position('is_published' in v_profile)=0 then
    raise exception 'Public team profile must enforce the same published-season boundary';
  end if;

  if position('can_administer_location' in v_update)=0
     or position('tm.status=''active''' in v_update)=0
     or position('tm.is_captain' in v_update)=0 then
    raise exception 'Team Instagram updates must be restricted to active captains or assigned location administrators';
  end if;
  if position('can_administer_location' in v_update_details)=0
     or position('tm.status=''active''' in v_update_details)=0
     or position('tm.is_captain' in v_update_details)=0
     or position('instagram_handle' in v_update_details)=0 then
    raise exception 'Combined Instagram details update must validate both fields and enforce captain/location-admin scope';
  end if;
  if position('can_administer_location' in v_admin)=0 then
    raise exception 'Admin social profile list must be location scoped';
  end if;

  if not pg_catalog.has_function_privilege('authenticated','public.update_team_instagram_profile(uuid,text)','EXECUTE')
     or pg_catalog.has_function_privilege('anon','public.update_team_instagram_profile(uuid,text)','EXECUTE')
     or not pg_catalog.has_function_privilege('authenticated','public.update_team_instagram_details(uuid,text,text)','EXECUTE')
     or pg_catalog.has_function_privilege('anon','public.update_team_instagram_details(uuid,text,text)','EXECUTE')
     or pg_catalog.has_function_privilege('anon','public.admin_get_team_social_profiles()','EXECUTE')
     or not pg_catalog.has_function_privilege('authenticated','public.admin_get_team_social_profiles()','EXECUTE')
     or not pg_catalog.has_function_privilege('authenticated','public.register_team(uuid,text,text,text,text)','EXECUTE')
     or not pg_catalog.has_function_privilege('authenticated','public.register_team(uuid,text,text,text,text,text)','EXECUTE')
     or pg_catalog.has_function_privilege('anon','public.register_team(uuid,text,text,text,text)','EXECUTE')
     or pg_catalog.has_function_privilege('anon','public.register_team(uuid,text,text,text,text,text)','EXECUTE') then
    raise exception 'Team profile mutation, registration and admin listing grants are not least-privilege';
  end if;
  if pg_catalog.has_table_privilege('authenticated','public.teams','INSERT')
     or pg_catalog.has_table_privilege('authenticated','public.teams','UPDATE')
     or pg_catalog.has_table_privilege('authenticated','public.teams','DELETE') then
    raise exception 'Authenticated users must use the scoped RPCs rather than directly mutating public.teams';
  end if;
end;
$team_instagram$;

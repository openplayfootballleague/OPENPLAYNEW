-- Run after the team Instagram profile and handle migrations.
-- Fail-closed catalog assertions. Full authenticated/public RPC behaviour must
-- still be exercised in the final isolated database before deployment.
do $$
declare
  v_public_definition text := lower(pg_catalog.pg_get_functiondef('public.get_public_team_directory(uuid)'::regprocedure));
  v_public_result text := lower(pg_catalog.pg_get_function_result('public.get_public_team_directory(uuid)'::regprocedure));
  v_update_definition text := lower(pg_catalog.pg_get_functiondef('public.update_team_instagram_profile(uuid,text)'::regprocedure));
  v_profile_constraint text;
  v_handle_constraint text;
  v_public_is_definer boolean;
begin
  select lower(pg_catalog.pg_get_constraintdef(oid))
    into v_profile_constraint
    from pg_catalog.pg_constraint
   where conrelid='public.teams'::regclass
     and conname='teams_instagram_profile_url_valid';
  if v_profile_constraint is null
     or position('instagram' in v_profile_constraint)=0
     or position('[.]{2}' in v_profile_constraint)=0 then
    raise exception 'Instagram profile URL constraint must enforce canonical Instagram URLs and reject repeated dots';
  end if;

  select lower(pg_catalog.pg_get_constraintdef(oid))
    into v_handle_constraint
    from pg_catalog.pg_constraint
   where conrelid='public.teams'::regclass
     and conname='teams_instagram_handle_valid';
  if v_handle_constraint is null
     or position('[.]{2}' in v_handle_constraint)=0 then
    raise exception 'Instagram handle constraint must reject consecutive dots';
  end if;

  select prosecdef into v_public_is_definer
    from pg_catalog.pg_proc
   where oid='public.get_public_team_directory(uuid)'::regprocedure;
  if not coalesce(v_public_is_definer,false)
     or position('set search_path = ''''' in v_public_definition)=0 then
    raise exception 'Public team directory must be SECURITY DEFINER with an empty search_path';
  end if;

  if position('registration_status' in v_public_definition)=0
     or position('approved' in v_public_definition)=0
     or position('is_public' in v_public_definition)=0
     or position('is_published' in v_public_definition)=0 then
    raise exception 'Public team directory must restrict output to approved teams in public published seasons';
  end if;

  if position('created_by' in v_public_result)>0 then
    raise exception 'Public team directory must not expose team creator identity';
  end if;

  if position('is_active_team_captain' in v_update_definition)=0
     or position('can_administer_location' in v_update_definition)=0 then
    raise exception 'Instagram profile updates must remain captain/location-admin scoped';
  end if;

  if has_table_privilege('anon','public.teams','select')
     or has_table_privilege('anon','public.teams','insert')
     or has_table_privilege('anon','public.teams','update')
     or has_table_privilege('anon','public.teams','delete')
     or has_table_privilege('authenticated','public.teams','insert')
     or has_table_privilege('authenticated','public.teams','update')
     or has_table_privilege('authenticated','public.teams','delete') then
    raise exception 'Teams table must not be directly writable or publicly readable';
  end if;
end;
$$;

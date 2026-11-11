create or replace function public.get_admin_context_preference()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_user uuid:=auth.uid();v_result jsonb;v_global boolean;
begin
 if v_user is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
 select exists(select 1 from public.user_roles where user_id=v_user and role in ('admin','super_admin')) into v_global;
 select jsonb_build_object('location_id',p.location_id,'league_id',p.league_id,'season_id',p.season_id,'is_global_admin',v_global)
 into v_result from public.admin_context_preferences p where p.user_id=v_user;
 return coalesce(v_result,jsonb_build_object('location_id',null,'league_id',null,'season_id',null,'is_global_admin',v_global));
end;
$$;

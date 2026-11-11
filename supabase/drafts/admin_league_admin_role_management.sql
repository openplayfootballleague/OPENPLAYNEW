-- Global-admin-only management of the location-administrator role.
-- A league_admin role grants no location access until an explicit location assignment exists.

create or replace function public.admin_search_league_admin_role_candidates(p_query text)
returns table(user_id uuid,email text,display_name text,has_league_admin boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text:=nullif(btrim(p_query),'');
begin
  if auth.uid() is null or not exists(
    select 1 from public.user_roles
    where user_id=auth.uid() and role in ('admin','super_admin')
  ) then
    raise exception 'Global administrator permission required';
  end if;
  if length(coalesce(v_query,''))<2 then
    raise exception 'Enter at least two characters to search';
  end if;

  return query
  select
    u.id,
    u.email,
    coalesce(nullif(u.raw_user_meta_data->>'full_name',''),
      nullif(u.raw_user_meta_data->>'name',''),u.email)::text,
    exists(select 1 from public.user_roles role_row
      where role_row.user_id=u.id and role_row.role='league_admin')
  from auth.users u
  where (u.email ilike '%'||v_query||'%'
      or coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name','') ilike '%'||v_query||'%')
    and not exists(select 1 from public.user_roles protected
      where protected.user_id=u.id and protected.role in ('admin','super_admin','finance_admin'))
  order by u.email
  limit 25;
end;
$$;
revoke all on function public.admin_search_league_admin_role_candidates(text) from public,anon;
grant execute on function public.admin_search_league_admin_role_candidates(text) to authenticated;

create or replace function public.admin_set_league_admin_role(
  p_user_id uuid,
  p_granted boolean,
  p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_role_id uuid;
  v_location_id uuid;
  v_user_exists boolean;
begin
  if v_actor is null or not exists(
    select 1 from public.user_roles
    where user_id=v_actor and role in ('admin','super_admin')
  ) then
    raise exception 'Global administrator permission required';
  end if;
  if p_user_id is null or p_granted is null then
    raise exception 'Choose a user and a role action';
  end if;
  if p_user_id=v_actor then
    raise exception 'Administrators cannot change their own role';
  end if;
  if length(btrim(coalesce(p_reason,''))) not between 5 and 500 then
    raise exception 'A reason of 5 to 500 characters is required';
  end if;

  select exists(select 1 from auth.users where id=p_user_id) into v_user_exists;
  if not v_user_exists then raise exception 'User account not found'; end if;

  if exists(select 1 from public.user_roles
    where user_id=p_user_id and role in ('admin','super_admin','finance_admin')) then
    raise exception 'Platform and finance roles cannot be changed through location administrator management';
  end if;

  if p_granted then
    insert into public.user_roles(user_id,role,granted_by)
    values(p_user_id,'league_admin',v_actor)
    on conflict(user_id,role) do nothing
    returning id into v_role_id;

    if v_role_id is null then return false; end if;

    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
    values(v_actor,'role.league_admin.granted','user_role',v_role_id::text,btrim(p_reason),null,
      jsonb_build_object('user_id',p_user_id,'role','league_admin','granted_by',v_actor,'granted_at',now()));
    return true;
  end if;

  select id into v_role_id
  from public.user_roles
  where user_id=p_user_id and role='league_admin'
  for update;
  if v_role_id is null then return false; end if;

  -- Revoke every location grant through the existing audited mutation before
  -- removing the role, so no stale assignment is left behind.
  for v_location_id in
    select location_id from public.location_admin_assignments
    where user_id=p_user_id order by location_id
  loop
    perform public.admin_set_location_assignment(p_user_id,v_location_id,false);
  end loop;

  delete from public.user_roles where id=v_role_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'role.league_admin.revoked','user_role',v_role_id::text,btrim(p_reason),
    jsonb_build_object('user_id',p_user_id,'role','league_admin'),
    jsonb_build_object('user_id',p_user_id,'role_removed',true,'location_assignments_revoked',true));
  return true;
end;
$$;
revoke all on function public.admin_set_league_admin_role(uuid,boolean,text) from public,anon;
grant execute on function public.admin_set_league_admin_role(uuid,boolean,text) to authenticated;

comment on function public.admin_set_league_admin_role(uuid,boolean,text) is
  'Global-admin-only grant/revoke of league_admin. Granting does not grant location access; revocation removes and audits all location assignments first.';

-- Secure, audited role provisioning. No client may write public.user_roles directly.
-- Initial bootstrap is a separate, one-time service-role-only operation.

create table public.role_bootstrap_state (
  singleton boolean primary key default true check (singleton = true),
  completed_at timestamptz not null default now(),
  bootstrapped_user_id uuid not null references auth.users(id) on delete restrict
);

alter table public.role_bootstrap_state enable row level security;
revoke all on public.role_bootstrap_state from public, anon, authenticated, service_role;

create or replace function public.bootstrap_initial_super_admin(
  p_target_user_id uuid,
  p_bootstrap_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_email_confirmed_at timestamptz;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required for initial bootstrap' using errcode = '42501';
  end if;
  if p_target_user_id is null or p_bootstrap_actor_user_id is null
     or p_target_user_id <> p_bootstrap_actor_user_id then
    raise exception 'Bootstrap actor must be the verified target account' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(731, 42);

  if exists (select 1 from public.role_bootstrap_state where singleton = true)
     or exists (select 1 from public.user_roles where role = 'super_admin') then
    raise exception 'Initial super-admin bootstrap has already been completed' using errcode = '55000';
  end if;

  select u.email_confirmed_at
    into v_email_confirmed_at
  from auth.users u
  where u.id = p_target_user_id;

  if not found then
    raise exception 'Bootstrap target account does not exist' using errcode = '22023';
  end if;
  if v_email_confirmed_at is null then
    raise exception 'Bootstrap target email must be verified' using errcode = '42501';
  end if;

  insert into public.user_roles (user_id, role, granted_by)
  values (p_target_user_id, 'super_admin', p_bootstrap_actor_user_id);

  insert into public.role_bootstrap_state (singleton, bootstrapped_user_id)
  values (true, p_target_user_id);

  insert into public.audit_log (
    actor_user_id, action, entity_type, entity_id, before_data, after_data, reason
  ) values (
    p_bootstrap_actor_user_id,
    'user_role.initial_super_admin_bootstrapped',
    'user_role',
    p_target_user_id::text,
    '{}'::jsonb,
    jsonb_build_object('user_id', p_target_user_id, 'role', 'super_admin'),
    'One-time owner-approved initial super-admin bootstrap'
  );

  return jsonb_build_object('ok', true, 'user_id', p_target_user_id, 'role', 'super_admin');
end;
$function$;

revoke all on function public.bootstrap_initial_super_admin(uuid,uuid) from public, anon, authenticated;
grant execute on function public.bootstrap_initial_super_admin(uuid,uuid) to service_role;

create or replace function public.manage_user_role(
  p_target_user_id uuid,
  p_role text,
  p_action text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_before jsonb;
  v_after jsonb;
  v_actor_is_admin boolean;
  v_actor_is_super_admin boolean;
  v_super_admin_count bigint;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_target_user_id is null or p_role not in ('admin','super_admin','finance_admin','league_admin')
     or p_action not in ('grant','revoke') then
    raise exception 'Invalid role provisioning request' using errcode = '22023';
  end if;
  if p_target_user_id = v_actor then
    raise exception 'Self-targeted role changes are not permitted' using errcode = '42501';
  end if;
  if p_reason is null or char_length(btrim(p_reason)) < 10 or char_length(btrim(p_reason)) > 500 then
    raise exception 'A reason between 10 and 500 characters is required' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(731, 42);

  if not exists (select 1 from auth.users u where u.id = p_target_user_id) then
    raise exception 'Target Auth user does not exist' using errcode = '22023';
  end if;

  select
    coalesce(bool_or(ur.role = 'admin'), false),
    coalesce(bool_or(ur.role = 'super_admin'), false)
  into v_actor_is_admin, v_actor_is_super_admin
  from public.user_roles ur
  where ur.user_id = v_actor;

  if p_role in ('admin','super_admin') then
    if not v_actor_is_super_admin then
      raise exception 'Only a super administrator may manage admin or super-admin roles' using errcode = '42501';
    end if;
  elsif not (v_actor_is_admin or v_actor_is_super_admin) then
    raise exception 'Only a platform administrator may manage finance or league administrator roles' using errcode = '42501';
  end if;

  select jsonb_build_object('user_id', ur.user_id, 'role', ur.role, 'granted_by', ur.granted_by, 'granted_at', ur.granted_at)
    into v_before
  from public.user_roles ur
  where ur.user_id = p_target_user_id and ur.role = p_role;

  if p_action = 'grant' then
    if v_before is not null then
      raise exception 'Target user already has this role' using errcode = '23505';
    end if;

    insert into public.user_roles (user_id, role, granted_by)
    values (p_target_user_id, p_role, v_actor);

    select jsonb_build_object('user_id', ur.user_id, 'role', ur.role, 'granted_by', ur.granted_by, 'granted_at', ur.granted_at)
      into v_after
    from public.user_roles ur
    where ur.user_id = p_target_user_id and ur.role = p_role;
  else
    if v_before is null then
      raise exception 'Target user does not hold this role' using errcode = 'P0002';
    end if;
    if p_role = 'super_admin' then
      select count(*) into v_super_admin_count
      from public.user_roles ur where ur.role = 'super_admin';
      if v_super_admin_count <= 1 then
        raise exception 'The final super administrator cannot be removed' using errcode = '42501';
      end if;
    end if;

    delete from public.user_roles ur
    where ur.user_id = p_target_user_id and ur.role = p_role;
    v_after := null;
  end if;

  insert into public.audit_log (
    actor_user_id, action, entity_type, entity_id, before_data, after_data, reason
  ) values (
    v_actor,
    'user_role.' || case when p_action = 'grant' then 'granted' else 'revoked' end,
    'user_role',
    p_target_user_id::text,
    coalesce(v_before, '{}'::jsonb),
    coalesce(v_after, '{}'::jsonb),
    btrim(p_reason)
  );

  return jsonb_build_object('ok', true, 'action', p_action, 'user_id', p_target_user_id, 'role', p_role);
end;
$function$;

revoke all on function public.manage_user_role(uuid,text,text,text) from public, anon;
grant execute on function public.manage_user_role(uuid,text,text,text) to authenticated;

-- The browser may read roles only through the existing self/admin RLS policy.
-- Direct role-table writes remain unavailable to every API role.
revoke insert, update, delete, truncate, references, trigger
  on table public.user_roles from public, anon, authenticated, service_role;

-- Role provisioning authority matrix and one-time bootstrap regression.
-- Runs only against the disposable local Supabase database created by CI.
begin;

insert into auth.users (id,aud,role,email,encrypted_password,email_confirmed_at,raw_user_meta_data,created_at,updated_at)
values
 ('00000000-0000-4000-8000-000000000301','authenticated','authenticated','ci-bootstrap-owner@openplay.invalid','','2026-11-08T00:00:00Z','{}'::jsonb,now(),now()),
 ('00000000-0000-4000-8000-000000000302','authenticated','authenticated','ci-role-admin@openplay.invalid','','2026-11-08T00:00:00Z','{}'::jsonb,now(),now()),
 ('00000000-0000-4000-8000-000000000303','authenticated','authenticated','ci-role-finance@openplay.invalid','','2026-11-08T00:00:00Z','{}'::jsonb,now(),now()),
 ('00000000-0000-4000-8000-000000000304','authenticated','authenticated','ci-role-league@openplay.invalid','','2026-11-08T00:00:00Z','{}'::jsonb,now(),now()),
 ('00000000-0000-4000-8000-000000000305','authenticated','authenticated','ci-role-player@openplay.invalid','','2026-11-08T00:00:00Z','{}'::jsonb,now(),now()),
 ('00000000-0000-4000-8000-000000000306','authenticated','authenticated','ci-role-target@openplay.invalid','','2026-11-08T00:00:00Z','{}'::jsonb,now(),now()),
 ('00000000-0000-4000-8000-000000000307','authenticated','authenticated','ci-role-target2@openplay.invalid','','2026-11-08T00:00:00Z','{}'::jsonb,now(),now());

-- Bootstrap is available to service_role only and requires a verified target.
do $bootstrap_privileges$
begin
  if has_function_privilege('anon','public.bootstrap_initial_super_admin(uuid,uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.bootstrap_initial_super_admin(uuid,uuid)','EXECUTE')
     or not has_function_privilege('service_role','public.bootstrap_initial_super_admin(uuid,uuid)','EXECUTE') then
    raise exception 'Initial bootstrap RPC is not restricted to service_role';
  end if;
  if has_table_privilege('anon','public.role_bootstrap_state','SELECT')
     or has_table_privilege('authenticated','public.role_bootstrap_state','SELECT')
     or has_table_privilege('service_role','public.role_bootstrap_state','INSERT') then
    raise exception 'Bootstrap state table is directly accessible to an API role';
  end if;
end;
$bootstrap_privileges$;

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select public.bootstrap_initial_super_admin(
 '00000000-0000-4000-8000-000000000301',
 '00000000-0000-4000-8000-000000000301'
);
reset role;

do $bootstrap_repeat$
begin
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  begin
    perform public.bootstrap_initial_super_admin(
      '00000000-0000-4000-8000-000000000301',
      '00000000-0000-4000-8000-000000000301'
    );
    raise exception 'Repeated initial bootstrap unexpectedly succeeded';
  exception when sqlstate '55000' then
    null;
  end;
  execute 'reset role';
end;
$bootstrap_repeat$;

-- Seed remaining roles as the trusted test database owner.
insert into public.user_roles (user_id,role,granted_by)
values
 ('00000000-0000-4000-8000-000000000302','admin','00000000-0000-4000-8000-000000000301'),
 ('00000000-0000-4000-8000-000000000303','finance_admin','00000000-0000-4000-8000-000000000301'),
 ('00000000-0000-4000-8000-000000000304','league_admin','00000000-0000-4000-8000-000000000301');

do $role_privileges$
begin
  if has_table_privilege('anon','public.user_roles','INSERT')
     or has_table_privilege('anon','public.user_roles','UPDATE')
     or has_table_privilege('anon','public.user_roles','DELETE')
     or has_table_privilege('authenticated','public.user_roles','INSERT')
     or has_table_privilege('authenticated','public.user_roles','UPDATE')
     or has_table_privilege('authenticated','public.user_roles','DELETE')
     or has_table_privilege('service_role','public.user_roles','INSERT')
     or has_table_privilege('service_role','public.user_roles','UPDATE')
     or has_table_privilege('service_role','public.user_roles','DELETE') then
    raise exception 'Direct user_roles mutation privileges must remain revoked';
  end if;
  if not has_function_privilege('authenticated','public.manage_user_role(uuid,text,text,text)','EXECUTE')
     or has_function_privilege('anon','public.manage_user_role(uuid,text,text,text)','EXECUTE') then
    raise exception 'Role management RPC execute grants are incorrect';
  end if;
end;
$role_privileges$;

-- Super admin may grant/revoke every role, but cannot target itself.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000301',true);
select public.manage_user_role('00000000-0000-4000-8000-000000000306','super_admin','grant','Approved deputy super administrator');
select public.manage_user_role('00000000-0000-4000-8000-000000000307','admin','grant','Approved platform administrator');
select public.manage_user_role('00000000-0000-4000-8000-000000000306','super_admin','revoke','Deputy administrator access ended');
reset role;

-- Admin may manage finance_admin and league_admin but not admin/super_admin.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000302',true);
select public.manage_user_role('00000000-0000-4000-8000-000000000306','finance_admin','grant','Finance operations responsibility');
select public.manage_user_role('00000000-0000-4000-8000-000000000306','league_admin','grant','Location league operations responsibility');
do $admin_denials$
begin
  begin
    perform public.manage_user_role('00000000-0000-4000-8000-000000000306','super_admin','grant','Attempted privilege escalation');
    raise exception 'Admin unexpectedly granted super_admin';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.manage_user_role('00000000-0000-4000-8000-000000000306','admin','grant','Attempted platform escalation');
    raise exception 'Admin unexpectedly granted admin';
  exception when insufficient_privilege then null;
  end;
end;
$admin_denials$;
reset role;

-- Finance admin, league admin and ordinary players cannot provision roles.
do $non_admin_denials$
declare
  actor_id uuid;
begin
  foreach actor_id in array array[
    '00000000-0000-4000-8000-000000000303'::uuid,
    '00000000-0000-4000-8000-000000000304'::uuid,
    '00000000-0000-4000-8000-000000000305'::uuid
  ] loop
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.sub',actor_id::text,true);
    begin
      perform public.manage_user_role('00000000-0000-4000-8000-000000000306','league_admin','grant','Attempted unauthorized role change');
      raise exception 'Non-platform role unexpectedly provisioned a role';
    exception when insufficient_privilege then
      null;
    end;
    execute 'reset role';
  end loop;
end;
$non_admin_denials$;

-- Self-targeting and unaudited/invalid requests are denied.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000301',true);
do $self_target$
begin
  begin
    perform public.manage_user_role('00000000-0000-4000-8000-000000000301','admin','grant','Attempted self promotion');
    raise exception 'Self-targeted role grant unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
end;
$self_target$;
reset role;

do $audit_assertions$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.audit_log
  where entity_type='user_role'
    and action in ('user_role.initial_super_admin_bootstrapped','user_role.granted','user_role.revoked');
  if v_count <> 7 then
    raise exception 'Expected seven audited role changes, found %', v_count;
  end if;
  if not exists (
    select 1 from public.audit_log
    where action='user_role.initial_super_admin_bootstrapped'
      and actor_user_id='00000000-0000-4000-8000-000000000301'
      and entity_id='00000000-0000-4000-8000-000000000301'
      and after_data->>'role'='super_admin'
  ) then
    raise exception 'Initial super-admin bootstrap audit event is missing';
  end if;
end;
$audit_assertions$;

rollback;

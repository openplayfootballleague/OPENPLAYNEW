-- Owner decision D6: online card payments are frozen behind an audited, owner-controlled flag.
begin;

do $test$
declare
  v_admin uuid:=gen_random_uuid();
  v_user uuid:=gen_random_uuid();
  v_enabled boolean;
  v_failed boolean;
  v_audit integer;
begin
  select enabled into v_enabled from public.platform_feature_flags where feature_key='online_card_payments';
  if v_enabled is distinct from false then raise exception 'online_card_payments must exist and default to off'; end if;

  -- Visitors and signed-in users can read the status (the UI hides Pay actions from it).
  execute 'set local role anon';
  select enabled into v_enabled from public.platform_feature_flags where feature_key='online_card_payments';
  execute 'reset role';
  if v_enabled is distinct from false then raise exception 'Anonymous clients must be able to read the payments flag'; end if;

  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values(v_user,'authenticated','authenticated','ci-payments-flag-user@openplay.invalid','','{}'::jsonb,now(),now(),now()),
        (v_admin,'authenticated','authenticated','ci-payments-flag-admin@openplay.invalid','','{}'::jsonb,now(),now(),now());
  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'super_admin',v_admin);

  -- Negative: a signed-in non-admin cannot enable payments.
  perform set_config('request.jwt.claim.sub',v_user::text,true);
  v_failed:=false;
  begin
    perform public.admin_set_platform_feature_flag('online_card_payments',true,'Unauthorised enable attempt');
  exception when sqlstate '42501' then v_failed:=true;
  end;
  if not v_failed then raise exception 'A non-admin must not enable online card payments'; end if;

  -- Negative: direct writes are not granted to client roles.
  if has_table_privilege('authenticated','public.platform_feature_flags','UPDATE')
     or has_table_privilege('anon','public.platform_feature_flags','UPDATE') then
    raise exception 'Client roles must not update feature flags directly';
  end if;

  -- Negative: unknown keys are still rejected for administrators.
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_failed:=false;
  begin
    perform public.admin_set_platform_feature_flag('instant_payouts',true,'Unknown flag attempt');
  exception when sqlstate '22023' then v_failed:=true;
  end;
  if not v_failed then raise exception 'Unknown feature keys must be rejected'; end if;

  -- Positive: a global administrator can change it with a reason, and the change is audited.
  perform public.admin_set_platform_feature_flag('online_card_payments',true,'Owner approved test-mode payments');
  select enabled into v_enabled from public.platform_feature_flags where feature_key='online_card_payments';
  if v_enabled is not true then raise exception 'A global administrator must be able to enable the flag'; end if;
  select count(*) into v_audit from public.audit_log
  where action='platform.feature_flag.updated' and entity_id='online_card_payments' and actor_user_id=v_admin;
  if v_audit<>1 then raise exception 'Enabling online card payments must be audited exactly once'; end if;
  perform set_config('request.jwt.claim.sub','',true);
end;
$test$;

rollback;

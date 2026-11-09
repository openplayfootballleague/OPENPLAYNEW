-- Global-admin retention-hold workflow regression tests.
-- Runs only in the disposable local Supabase database created by CI.

do $player_retention_holds$
declare
  v_admin constant uuid := '93000000-0000-4000-8000-000000000001';
  v_player constant uuid := '93000000-0000-4000-8000-000000000002';
  v_too_late constant uuid := '93000000-0000-4000-8000-000000000003';
  v_count integer;
  v_result boolean;
  v_rejected boolean;
begin
  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at,last_sign_in_at)
  values
    (v_admin,'authenticated','authenticated','ci-retention-hold-admin@openplay.invalid','','{}'::jsonb,now(),now()-interval '2 years',now(),now()-interval '13 months'),
    (v_player,'authenticated','authenticated','ci-retention-hold-player@openplay.invalid','','{}'::jsonb,now(),now()-interval '2 years',now(),now()-interval '13 months'),
    (v_too_late,'authenticated','authenticated','ci-retention-hold-late@openplay.invalid','','{}'::jsonb,now(),now()-interval '2 years',now(),now()-interval '13 months');

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status)
  values
    (v_player,'Retention Hold Player','07700900501','ci-retention-hold-player@openplay.invalid',date '1990-01-01','registered'),
    (v_too_late,'Retention Hold Late','07700900502','ci-retention-hold-late@openplay.invalid',date '1990-01-02','registered');

  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'admin',v_admin);

  update public.profiles
  set last_sign_in_at=now()-interval '13 months'
  where id in (v_player,v_too_late);

  update public.profiles
  set account_retention_status='erasure_due',
      account_closed_at=now()-interval '13 months',
      archive_expires_at=now()-interval '1 day'
  where id=v_too_late;

  if has_function_privilege('anon','public.admin_list_player_retention_accounts(text)','EXECUTE')
     or has_function_privilege('anon','public.admin_set_player_retention_hold(uuid,boolean,text)','EXECUTE') then
    raise exception 'Anonymous users can execute retention-hold administration functions';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  v_rejected := false;
  begin
    perform public.admin_list_player_retention_accounts(null);
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then raise exception 'A non-admin player could list retention accounts'; end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  select count(*) into v_count from public.admin_list_player_retention_accounts('Retention Hold Player');
  if v_count <> 1 then raise exception 'Global administrator could not find the retention test player'; end if;

  select public.admin_set_player_retention_hold(v_player,true,'Safeguarding review pending') into v_result;
  if not v_result then raise exception 'Global administrator could not set a retention hold'; end if;
  if not exists(select 1 from public.profiles where id=v_player and retention_hold and retention_hold_reason='Safeguarding review pending') then
    raise exception 'Retention hold and reason were not saved'; end if;

  execute 'reset role';
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  select count(*) into v_count from public.admin_list_inactive_player_accounts();
  if v_count <> 0 then raise exception 'A player with an active retention hold remained eligible for closure'; end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  select public.admin_set_player_retention_hold(v_player,false,'Safeguarding review concluded') into v_result;
  if not v_result then raise exception 'Global administrator could not clear a retention hold'; end if;
  if exists(select 1 from public.profiles where id=v_player and (retention_hold or retention_hold_reason is not null)) then
    raise exception 'Clearing a retention hold did not clear its reason'; end if;

  v_rejected := false;
  begin
    perform public.admin_set_player_retention_hold(v_too_late,true,'Late retention hold attempt');
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then raise exception 'A retention hold was accepted after final erasure had begun'; end if;

  select count(*) into v_count from public.audit_log
  where actor_user_id=v_admin and entity_id=v_player::text
    and action in ('player.retention_hold.set','player.retention_hold.cleared');
  if v_count <> 2 then raise exception 'Retention hold set/clear actions were not both audited'; end if;
  execute 'reset role';
end;
$player_retention_holds$;

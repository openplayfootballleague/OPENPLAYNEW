-- Support case assignment, status, priority, resolution and audit boundaries.
do $support_case_workflow$
declare
  v_admin uuid:=gen_random_uuid();
  v_player uuid:=gen_random_uuid();
  v_location_admin uuid:=gen_random_uuid();
  v_conversation uuid;
  v_case public.message_conversations;
  v_count integer;
  v_failed boolean;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-support-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player,'authenticated','authenticated','ci-support-player@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_location_admin,'authenticated','authenticated','ci-support-location-admin@openplay.invalid','','{}'::jsonb,now(),now(),now());
  insert into public.profiles(id,display_name,account_retention_status)
  values
    (v_admin,'Support Admin','active'),
    (v_player,'Support Player','active'),
    (v_location_admin,'Support Location Admin','active')
  on conflict(id) do update set display_name=excluded.display_name,account_retention_status='active';
  insert into public.user_roles(user_id,role,granted_by)
  values(v_admin,'admin',v_admin),(v_location_admin,'league_admin',v_admin);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player::text,'role','authenticated')::text,true);
  v_conversation:=public.create_support_message_conversation('Help with registration','Please help me with my account registration.');
  execute 'reset role';

  select * into v_case from public.message_conversations where id=v_conversation;
  if v_case.support_status<>'open' or v_case.support_priority<>'normal'
     or v_case.assigned_to is not null or v_case.resolved_by is not null then
    raise exception 'New support conversations must become open, normal-priority support cases';
  end if;
  if exists(select 1 from public.message_conversation_participants
    where conversation_id=v_conversation and user_id=v_location_admin and left_at is null) then
    raise exception 'Location administrators must not be enrolled in the global support desk';
  end if;
  if has_table_privilege('authenticated','public.message_conversations','UPDATE') then
    raise exception 'Authenticated users must not directly update support case state';
  end if;
  if not has_function_privilege('authenticated','public.admin_get_support_cases(text,integer)','EXECUTE')
     or has_function_privilege('anon','public.admin_get_support_cases(text,integer)','EXECUTE') then
    raise exception 'Support case list grants are incorrect';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player::text,'role','authenticated')::text,true);
  v_failed:=false;
  begin
    perform * from public.admin_get_support_cases('all',50);
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Ordinary players must not list administrator support cases'; end if;
  v_failed:=false;
  begin
    perform public.admin_update_support_case(v_conversation,'in_progress','high',v_admin,null);
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Ordinary players must not change support case state'; end if;
  execute 'reset role';

  -- Location administrators may use other admin tools, but support cases are
  -- a global account-support queue visible only to global administrators.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_location_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_location_admin::text,'role','authenticated')::text,true);
  select count(*) into v_count from public.admin_get_support_cases('all',50);
  if v_count<>0 then raise exception 'Location administrators must not list global support cases'; end if;
  select count(*) into v_count from public.admin_get_support_assignees();
  if v_count<>0 then raise exception 'Location administrators must not see global support assignees'; end if;
  v_failed:=false;
  begin
    perform public.admin_update_support_case(v_conversation,'in_progress','high',v_admin,null);
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Location administrators must not update global support cases'; end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_admin::text,'role','authenticated')::text,true);
  select count(*) into v_count from public.admin_get_support_assignees() where user_id=v_admin;
  if v_count<>1 then raise exception 'Active administrator was not available as a support assignee'; end if;
  select * into v_case from public.admin_update_support_case(v_conversation,'in_progress','high',v_admin,null);
  if v_case.support_status<>'in_progress' or v_case.support_priority<>'high' or v_case.assigned_to<>v_admin then
    raise exception 'Support case assignment/status/priority update failed';
  end if;
  v_failed:=false;
  begin
    perform public.admin_update_support_case(v_conversation,'resolved','urgent',v_player,'Invalid assignee');
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Support cases must not be assigned to ordinary players'; end if;
  v_failed:=false;
  begin
    perform public.admin_update_support_case(v_conversation,'resolved','urgent',v_admin,'');
  exception when others then v_failed:=true;
  end;
  if not v_failed then raise exception 'Resolved support cases must require a resolution note'; end if;
  select * into v_case from public.admin_update_support_case(
    v_conversation,'resolved','urgent',v_admin,'Resolved after account review'
  );
  if v_case.support_status<>'resolved' or v_case.resolved_by<>v_admin
     or v_case.resolved_at is null or v_case.resolution_note<>'Resolved after account review' then
    raise exception 'Support case resolution metadata was not persisted';
  end if;
  if not exists(select 1 from public.admin_get_support_cases('resolved',50) where conversation_id=v_conversation) then
    raise exception 'Resolved support case was not available in the resolved queue';
  end if;
  select * into v_case from public.admin_update_support_case(v_conversation,'open','normal',null,null);
  if v_case.support_status<>'open' or v_case.resolved_by is not null
     or v_case.resolved_at is not null or v_case.resolution_note is not null then
    raise exception 'Reopening a support case must clear prior resolution state';
  end if;
  execute 'reset role';

  if not exists(
    select 1 from public.audit_log
    where actor_user_id=v_admin and action='support.case_updated'
      and entity_type='support_case' and entity_id=v_conversation::text
  ) then raise exception 'Support case changes must be written to the audit log'; end if;
  raise notice 'Support case assignment, resolution, reopening and authorization regressions passed';
end;
$support_case_workflow$;

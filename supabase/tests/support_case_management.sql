-- Support case assignment, lifecycle, authorization and audit regression tests.
-- Runs against the disposable local Supabase database created by CI.

do $support_case_management$
declare
  v_admin uuid:=gen_random_uuid();
  v_assignee uuid:=gen_random_uuid();
  v_player uuid:=gen_random_uuid();
  v_conversation uuid;
  v_case_id uuid;
  v_count integer;
  v_status text;
  v_priority text;
  v_assigned uuid;
  v_closed_at timestamptz;
  v_failed boolean;
begin
  if has_table_privilege('anon','public.support_cases','SELECT')
     or has_table_privilege('authenticated','public.support_cases','SELECT')
     or has_table_privilege('authenticated','public.support_cases','INSERT')
     or has_table_privilege('authenticated','public.support_cases','UPDATE')
     or has_table_privilege('authenticated','public.support_cases','DELETE')
     or has_function_privilege('anon','public.admin_get_support_cases(text,integer,integer)','EXECUTE')
     or has_function_privilege('anon','public.admin_update_support_case(uuid,uuid,text,text,text,text)','EXECUTE') then
    raise exception 'Support case data or RPCs expose unauthorised direct access';
  end if;

  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-support-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_assignee,'authenticated','authenticated','ci-support-assignee@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_player,'authenticated','authenticated','ci-support-player@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.profiles(id,display_name,account_retention_status)
  values
    (v_admin,'Support Admin','active'),
    (v_assignee,'Support Assignee','active'),
    (v_player,'Support Requester','active')
  on conflict(id) do update set display_name=excluded.display_name,account_retention_status='active';

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
  values(v_player,'Support Requester','+447700930001','ci-support-player@openplay.invalid',date '1990-01-01','registered',false);

  insert into public.user_roles(user_id,role,granted_by)
  values(v_admin,'admin',v_admin),(v_assignee,'super_admin',v_admin);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player::text,'role','authenticated')::text,true);
  v_conversation:=public.create_support_message_conversation('Cannot access my player account','I cannot sign in to the player area. Please help me recover access.');

  execute 'reset role';
  select id into v_case_id from public.support_cases where conversation_id=v_conversation;
  if v_case_id is null then raise exception 'New support conversation did not create a support case'; end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_admin::text,'role','authenticated')::text,true);

  select count(*) into v_count from public.admin_get_support_cases('open',50,0)
  where case_id=v_case_id and subject='Cannot access my player account' and requester_name='Support Requester';
  if v_count<>1 then raise exception 'Global administrator could not retrieve the open support case'; end if;

  perform public.admin_update_support_case(
    v_case_id,v_assignee,'in_progress','high',null,'Assigned to support specialist'
  );
  select status,priority,assigned_to into v_status,v_priority,v_assigned
  from public.support_cases where id=v_case_id;
  if v_status<>'in_progress' or v_priority<>'high' or v_assigned<>v_assignee then
    raise exception 'Support case assignment, status or priority did not persist';
  end if;

  v_failed:=false;
  begin
    perform public.admin_update_support_case(
      v_case_id,v_player,'in_progress','high',null,'Invalid assignee attempt'
    );
  exception when others then
    v_failed:=true;
  end;
  if not v_failed then raise exception 'Support case accepted an ineligible non-admin assignee'; end if;

  perform public.admin_update_support_case(
    v_case_id,v_assignee,'resolved','high','Account access restored after identity checks','Resolved with member confirmation'
  );
  select status,resolved_at,resolved_by into v_status,v_closed_at,v_assigned
  from public.support_cases where id=v_case_id;
  if v_status<>'resolved' or v_closed_at is null or v_assigned<>v_admin then
    raise exception 'Resolved support case did not record its resolution actor and timestamp';
  end if;

  if not exists(
    select 1 from public.audit_log
    where actor_user_id=v_admin and action='support.case.updated'
      and entity_type='support_case' and entity_id=v_case_id::text
  ) then raise exception 'Support case update was not written to the audit log'; end if;

  perform public.admin_update_support_case(
    v_case_id,v_assignee,'closed','normal','Member confirmed access is restored','Closed after member confirmation'
  );
  select closed_at into v_closed_at from public.message_conversations where id=v_conversation;
  if v_closed_at is not null then raise exception 'Closing a support case incorrectly hid the member conversation history'; end if;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player::text,'role','authenticated')::text,true);
  perform public.send_message(v_conversation,'I still need help after the case was closed','message');
  execute 'reset role';

  select status,resolved_at,resolved_by into v_status,v_closed_at,v_assigned
  from public.support_cases where id=v_case_id;
  if v_status<>'open' or v_closed_at is not null or v_assigned is not null then
    raise exception 'A member follow-up did not reopen the closed support case';
  end if;
  select closed_at into v_closed_at from public.message_conversations where id=v_conversation;
  if v_closed_at is not null then raise exception 'Support conversation history became inaccessible after a follow-up'; end if;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_player::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_player::text,'role','authenticated')::text,true);
  v_failed:=false;
  begin
    perform * from public.admin_get_support_cases('all',50,0);
  exception when others then
    v_failed:=true;
  end;
  if not v_failed then raise exception 'A player could access the administrator support case register'; end if;

  execute 'reset role';
  delete from auth.users where id in (v_admin,v_assignee,v_player);
end;
$support_case_management$;

-- Structured support-case workflow on top of private support conversations.
alter table public.message_conversations
  add column if not exists support_status text,
  add column if not exists support_priority text,
  add column if not exists assigned_to uuid references auth.users(id) on delete set null,
  add column if not exists resolution_note text,
  add column if not exists resolved_by uuid references auth.users(id) on delete set null,
  add column if not exists resolved_at timestamptz;

update public.message_conversations
set support_status='open',support_priority='normal'
where kind='support' and support_status is null;

-- Support cases are a global account-support queue. Remove legacy location/finance
-- administrators from private support threads; only global administrators retain access.
delete from public.message_conversation_participants cp
using public.message_conversations c,public.user_roles ur
where cp.conversation_id=c.id and c.kind='support'
  and ur.user_id=cp.user_id and ur.role in ('league_admin','finance_admin')
  and not exists(
    select 1 from public.user_roles global_role
    where global_role.user_id=cp.user_id and global_role.role in ('admin','super_admin')
  );

alter table public.message_conversations
  drop constraint if exists message_conversations_support_case_state_check;
alter table public.message_conversations
  add constraint message_conversations_support_case_state_check
  check (
    (
      kind='support'
      and support_status in ('open','in_progress','resolved','closed')
      and support_priority in ('low','normal','high','urgent')
      and (
        (support_status in ('open','in_progress') and resolved_by is null and resolved_at is null and resolution_note is null)
        or
        (support_status in ('resolved','closed') and resolved_at is not null
          and length(btrim(coalesce(resolution_note,'')))>=5)
      )
    )
    or
    (
      kind<>'support'
      and support_status is null and support_priority is null and assigned_to is null
      and resolution_note is null and resolved_by is null and resolved_at is null
    )
  );

create or replace function public.set_support_case_defaults()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  if new.kind='support' then
    new.support_status:=coalesce(new.support_status,'open');
    new.support_priority:=coalesce(new.support_priority,'normal');
  end if;
  return new;
end;
$$;
drop trigger if exists set_support_case_defaults_trigger on public.message_conversations;
create trigger set_support_case_defaults_trigger
before insert on public.message_conversations
for each row execute function public.set_support_case_defaults();
revoke all on function public.set_support_case_defaults() from public,anon,authenticated;

create index if not exists message_conversations_support_queue_idx
  on public.message_conversations(support_status,support_priority,updated_at desc)
  where kind='support' and closed_at is null;

create or replace function public.create_support_message_conversation(
  p_subject text,
  p_initial_message text
)
returns uuid
language plpgsql
security definer
set search_path=''
as $support_create$
declare
  v_user uuid:=auth.uid();
  v_conversation_id uuid;
  v_count integer;
  v_admin_count integer;
begin
  if v_user is null or not public.message_actor_is_active(v_user) then
    raise exception 'Active Open Play account required';
  end if;
  if length(btrim(coalesce(p_subject,''))) not between 3 and 120
     or length(btrim(coalesce(p_initial_message,''))) not between 1 and 2000 then
    raise exception 'Enter a subject and a message';
  end if;
  select count(*) into v_count from public.message_conversations
  where kind='support' and created_by=v_user and created_at>now()-interval '1 day';
  if v_count>=5 then raise exception 'Support request limit reached. Please wait before opening another conversation'; end if;
  insert into public.message_conversations(kind,title,created_by)
  values('support',btrim(p_subject),v_user)
  returning id into v_conversation_id;
  insert into public.message_conversation_participants(conversation_id,user_id)
  values(v_conversation_id,v_user)
  on conflict do nothing;
  insert into public.message_conversation_participants(conversation_id,user_id,last_read_at)
  select v_conversation_id,ur.user_id,now()-interval '1 microsecond'
  from public.user_roles ur
  where ur.role in ('admin','super_admin')
    and public.message_actor_is_active(ur.user_id)
  on conflict do nothing;
  select count(*) into v_admin_count
  from public.message_conversation_participants cp
  join public.user_roles ur on ur.user_id=cp.user_id
  where cp.conversation_id=v_conversation_id
    and ur.role in ('admin','super_admin')
    and cp.left_at is null;
  if v_admin_count=0 then raise exception 'Administrator support is not available right now'; end if;
  perform public.send_message(v_conversation_id,p_initial_message,'message');
  return v_conversation_id;
end;
$support_create$;
revoke all on function public.create_support_message_conversation(text,text) from public,anon;
grant execute on function public.create_support_message_conversation(text,text) to authenticated;

create or replace function public.admin_get_support_cases(
  p_status text default 'open',
  p_limit integer default 50
)
returns table(
  conversation_id uuid,
  title text,
  created_by uuid,
  requester_name text,
  assigned_to uuid,
  assigned_name text,
  support_status text,
  support_priority text,
  resolution_note text,
  resolved_by uuid,
  resolved_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  last_message_at timestamptz,
  last_message_preview text
)
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
begin
  if v_user is null or not public.message_actor_is_active(v_user) then
    raise exception 'Active Open Play account required';
  end if;
  if not exists(select 1 from public.user_roles ur where ur.user_id=v_user and ur.role in ('admin','super_admin')) then
    return;
  end if;
  if p_status is null or p_status not in ('all','open','in_progress','resolved','closed') then
    raise exception 'Unsupported support-case status filter';
  end if;
  return query
  select c.id,c.title,c.created_by,
    coalesce(requester.display_name,'Open Play member'),
    c.assigned_to,assignee.display_name,
    c.support_status,c.support_priority,c.resolution_note,c.resolved_by,c.resolved_at,
    c.created_at,c.updated_at,last_message.created_at,
    case when last_message.is_hidden then '[Message hidden by moderation]'
      else left(coalesce(last_message.body,''),180) end
  from public.message_conversations c
  left join public.profiles requester on requester.id=c.created_by
  left join public.profiles assignee on assignee.id=c.assigned_to
  left join lateral (
    select m.created_at,m.body,m.is_hidden
    from public.messages m
    where m.conversation_id=c.id
    order by m.created_at desc,m.id desc
    limit 1
  ) last_message on true
  where c.kind='support' and c.closed_at is null
    and (p_status='all' or c.support_status=p_status)
  order by
    case c.support_priority when 'urgent' then 1 when 'high' then 2 when 'normal' then 3 else 4 end,
    c.updated_at desc
  limit least(greatest(coalesce(p_limit,50),1),100);
end;
$$;
revoke all on function public.admin_get_support_cases(text,integer) from public,anon;
grant execute on function public.admin_get_support_cases(text,integer) to authenticated;

create or replace function public.admin_get_support_assignees()
returns table(user_id uuid,full_name text)
language plpgsql
security definer
set search_path=''
as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null or not public.message_actor_is_active(v_user) then
    raise exception 'Active Open Play account required';
  end if;
  if not exists(select 1 from public.user_roles ur where ur.user_id=v_user and ur.role in ('admin','super_admin')) then
    return;
  end if;
  return query
  select distinct ur.user_id,coalesce(p.display_name,'Open Play administrator')
  from public.user_roles ur
  join public.profiles p on p.id=ur.user_id
  where ur.role in ('admin','super_admin')
    and public.message_actor_is_active(ur.user_id)
  order by 2;
end;
$$;
revoke all on function public.admin_get_support_assignees() from public,anon;
grant execute on function public.admin_get_support_assignees() to authenticated;

create or replace function public.admin_update_support_case(
  p_conversation_id uuid,
  p_status text,
  p_priority text,
  p_assigned_to uuid default null,
  p_resolution_note text default null
)
returns public.message_conversations
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_case public.message_conversations;
  v_before jsonb;
  v_resolution_note text;
  v_resolved_by uuid;
  v_resolved_at timestamptz;
begin
  if v_user is null or not public.message_actor_is_active(v_user)
     or not exists(select 1 from public.user_roles ur where ur.user_id=v_user and ur.role in ('admin','super_admin')) then
    raise exception 'Global administrator permission required';
  end if;
  if p_status is null or p_status not in ('open','in_progress','resolved','closed') then
    raise exception 'Unsupported support-case status';
  end if;
  if p_priority is null or p_priority not in ('low','normal','high','urgent') then
    raise exception 'Unsupported support-case priority';
  end if;
  if p_assigned_to is not null and not exists (
    select 1 from public.user_roles ur
    where ur.user_id=p_assigned_to
      and ur.role in ('admin','super_admin')
      and public.message_actor_is_active(ur.user_id)
  ) then
    raise exception 'Support cases can only be assigned to an active administrator';
  end if;

  select * into v_case
  from public.message_conversations
  where id=p_conversation_id and kind='support' and closed_at is null
  for update;
  if not found then raise exception 'Support case not found'; end if;

  if p_status in ('resolved','closed') then
    v_resolution_note:=coalesce(nullif(btrim(p_resolution_note),''),v_case.resolution_note);
    if length(btrim(coalesce(v_resolution_note,'')))<5 then
      raise exception 'Enter a resolution note of at least five characters';
    end if;
    v_resolved_by:=case when v_case.support_status in ('resolved','closed') then v_case.resolved_by else v_user end;
    v_resolved_at:=coalesce(v_case.resolved_at,now());
  else
    v_resolution_note:=null;
    v_resolved_by:=null;
    v_resolved_at:=null;
  end if;

  v_before:=jsonb_build_object(
    'status',v_case.support_status,
    'priority',v_case.support_priority,
    'assigned_to',v_case.assigned_to,
    'resolution_note',v_case.resolution_note
  );

  update public.message_conversations
  set support_status=p_status,
      support_priority=p_priority,
      assigned_to=p_assigned_to,
      resolution_note=v_resolution_note,
      resolved_by=v_resolved_by,
      resolved_at=v_resolved_at,
      updated_at=now()
  where id=p_conversation_id
  returning * into v_case;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data)
  values(v_user,'support.case_updated','support_case',p_conversation_id::text,v_before,
    jsonb_build_object(
      'status',v_case.support_status,
      'priority',v_case.support_priority,
      'assigned_to',v_case.assigned_to,
      'resolution_note',v_case.resolution_note,
      'resolved_by',v_case.resolved_by,
      'resolved_at',v_case.resolved_at
    ));
  return v_case;
end;
$$;
revoke all on function public.admin_update_support_case(uuid,text,text,uuid,text) from public,anon;
grant execute on function public.admin_update_support_case(uuid,text,text,uuid,text) to authenticated;

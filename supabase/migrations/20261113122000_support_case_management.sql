-- Audited administrator case management for member support conversations.

create table public.support_cases (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null unique references public.message_conversations(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  status text not null default 'open'
    check (status in ('open','in_progress','waiting_for_member','resolved','closed')),
  priority text not null default 'normal'
    check (priority in ('low','normal','high','urgent')),
  assigned_to uuid references auth.users(id) on delete set null,
  resolution_summary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null,
  constraint support_case_resolution_state_check check (
    (status in ('resolved','closed') and resolved_at is not null and resolved_by is not null
      and length(btrim(coalesce(resolution_summary,'')))>=10)
    or (status not in ('resolved','closed') and resolved_at is null and resolved_by is null)
  )
);
create index support_cases_status_priority_updated_idx
  on public.support_cases(status,priority,updated_at desc);
create index support_cases_assigned_updated_idx
  on public.support_cases(assigned_to,status,updated_at desc);

alter table public.support_cases enable row level security;
revoke all on public.support_cases from public,anon,authenticated;

create or replace function public.create_support_case_for_conversation()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if new.kind='support' and new.created_by is not null then
    insert into public.support_cases(conversation_id,created_by)
    values(new.id,new.created_by)
    on conflict(conversation_id) do nothing;
  end if;
  return new;
end;
$$;
revoke all on function public.create_support_case_for_conversation() from public,anon,authenticated;

insert into public.support_cases(conversation_id,created_by,status,created_at,updated_at)
select c.id,c.created_by,case when c.closed_at is null then 'open' else 'closed' end,c.created_at,c.updated_at
from public.message_conversations c
where c.kind='support' and c.created_by is not null
on conflict(conversation_id) do nothing;

drop trigger if exists create_support_case_for_conversation_trigger on public.message_conversations;
create trigger create_support_case_for_conversation_trigger
after insert on public.message_conversations
for each row execute function public.create_support_case_for_conversation();

create or replace function public.admin_get_support_case_options()
returns table(user_id uuid,display_name text)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null or not public.has_global_admin_role()
    or not public.message_actor_is_active(auth.uid()) then
    raise exception 'Global administrator permission required';
  end if;

  return query
  select ur.user_id,coalesce(nullif(p.display_name,''),pl.full_name,'Open Play administrator')
  from public.user_roles ur
  join public.profiles p on p.id=ur.user_id
  left join public.players pl on pl.user_id=ur.user_id
  where ur.role in ('admin','super_admin')
    and p.account_retention_status='active'
    and public.message_actor_is_active(ur.user_id)
  order by coalesce(nullif(p.display_name,''),pl.full_name,'Open Play administrator');
end;
$$;
revoke all on function public.admin_get_support_case_options() from public,anon;
grant execute on function public.admin_get_support_case_options() to authenticated;

create or replace function public.admin_get_support_cases(
  p_status text default 'all',
  p_limit integer default 50,
  p_offset integer default 0
)
returns table(
  case_id uuid,
  conversation_id uuid,
  subject text,
  requester_user_id uuid,
  requester_name text,
  assigned_to uuid,
  assigned_admin_name text,
  status text,
  priority text,
  resolution_summary text,
  created_at timestamptz,
  updated_at timestamptz,
  last_message_at timestamptz,
  last_message_preview text
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null or not public.has_global_admin_role()
    or not public.message_actor_is_active(auth.uid()) then
    raise exception 'Global administrator permission required';
  end if;
  if p_status is null or p_status not in ('all','open','in_progress','waiting_for_member','resolved','closed') then
    raise exception 'Invalid support case status filter';
  end if;

  return query
  select sc.id,c.id,c.title,sc.created_by,
    case when coalesce(rp.account_retention_status,'closed')<>'active' then 'Former member'
      else coalesce(nullif(rp.display_name,''),rpl.full_name,'Open Play member') end,
    sc.assigned_to,
    case when sc.assigned_to is null then null
      when coalesce(ap.account_retention_status,'closed')<>'active' then 'Former administrator'
      else coalesce(nullif(ap.display_name,''),apl.full_name,'Open Play administrator') end,
    sc.status,sc.priority,sc.resolution_summary,sc.created_at,sc.updated_at,
    lm.created_at,left(lm.body,300)
  from public.support_cases sc
  join public.message_conversations c on c.id=sc.conversation_id
  left join public.profiles rp on rp.id=sc.created_by
  left join public.players rpl on rpl.user_id=sc.created_by
  left join public.profiles ap on ap.id=sc.assigned_to
  left join public.players apl on apl.user_id=sc.assigned_to
  left join lateral (
    select m.created_at,m.body
    from public.messages m
    where m.conversation_id=sc.conversation_id
    order by m.created_at desc,m.id desc
    limit 1
  ) lm on true
  where p_status='all' or sc.status=p_status
  order by
    case sc.priority when 'urgent' then 1 when 'high' then 2 when 'normal' then 3 else 4 end,
    sc.updated_at desc
  limit least(greatest(coalesce(p_limit,50),1),100)
  offset greatest(coalesce(p_offset,0),0);
end;
$$;
revoke all on function public.admin_get_support_cases(text,integer,integer) from public,anon;
grant execute on function public.admin_get_support_cases(text,integer,integer) to authenticated;

create or replace function public.admin_update_support_case(
  p_case_id uuid,
  p_assigned_to uuid,
  p_status text,
  p_priority text,
  p_resolution_summary text,
  p_reason text
)
returns public.support_cases
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_case public.support_cases;
  v_before jsonb;
  v_after jsonb;
begin
  if v_actor is null or not public.has_global_admin_role()
    or not public.message_actor_is_active(v_actor) then
    raise exception 'Global administrator permission required';
  end if;
  if p_status is null or p_status not in ('open','in_progress','waiting_for_member','resolved','closed') then
    raise exception 'Choose a valid support case status';
  end if;
  if p_priority is null or p_priority not in ('low','normal','high','urgent') then
    raise exception 'Choose a valid support case priority';
  end if;
  if p_reason is null or length(btrim(p_reason))<5 then
    raise exception 'Enter a reason of at least five characters';
  end if;
  if p_status in ('resolved','closed') and length(btrim(coalesce(p_resolution_summary,'')))<10 then
    raise exception 'Enter a resolution summary of at least ten characters';
  end if;
  if p_assigned_to is not null and not exists(
    select 1 from public.user_roles ur
    join public.profiles p on p.id=ur.user_id
    where ur.user_id=p_assigned_to and ur.role in ('admin','super_admin')
      and p.account_retention_status='active'
      and public.message_actor_is_active(ur.user_id)
  ) then
    raise exception 'Assign the case to an active global administrator';
  end if;

  select * into v_case from public.support_cases where id=p_case_id for update;
  if not found then raise exception 'Support case not found'; end if;
  v_before:=jsonb_build_object(
    'assigned_to',v_case.assigned_to,'status',v_case.status,'priority',v_case.priority,
    'resolution_summary',v_case.resolution_summary
  );

  update public.support_cases
  set assigned_to=p_assigned_to,
      status=p_status,
      priority=p_priority,
      resolution_summary=case when p_status in ('resolved','closed') then btrim(p_resolution_summary) else null end,
      resolved_at=case when p_status in ('resolved','closed') then coalesce(resolved_at,now()) else null end,
      resolved_by=case when p_status in ('resolved','closed') then v_actor else null end,
      updated_at=now()
  where id=p_case_id returning * into v_case;

  update public.message_conversations
  set closed_at=case when p_status='closed' then coalesce(closed_at,now()) else null end,
      updated_at=now()
  where id=v_case.conversation_id;

  v_after:=jsonb_build_object(
    'assigned_to',v_case.assigned_to,'status',v_case.status,'priority',v_case.priority,
    'resolution_summary',v_case.resolution_summary
  );
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'support.case.updated','support_case',p_case_id::text,btrim(p_reason),v_before,v_after);

  return v_case;
end;
$$;
revoke all on function public.admin_update_support_case(uuid,uuid,text,text,text,text) from public,anon;
grant execute on function public.admin_update_support_case(uuid,uuid,text,text,text,text) to authenticated;

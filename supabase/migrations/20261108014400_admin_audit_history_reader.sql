drop policy if exists audit_log_admin_read on public.audit_log;
revoke select on public.audit_log from anon,authenticated;

create index if not exists audit_log_created_id_idx on public.audit_log(created_at desc,id desc);

create or replace function public.get_admin_audit_history(
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table(
  id bigint,
  actor_user_id uuid,
  action text,
  entity_type text,
  entity_id text,
  reason text,
  created_at timestamptz
)
language plpgsql stable security definer set search_path=''
as $$
declare v_limit integer:=greatest(1,least(coalesce(p_limit,50),100)); v_offset integer:=greatest(coalesce(p_offset,0),0); v_search text:=nullif(btrim(p_search),'');
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  return query
  select a.id,a.actor_user_id,a.action,a.entity_type,a.entity_id,a.reason,a.created_at
  from public.audit_log a
  where v_search is null
    or a.action ilike '%'||v_search||'%'
    or a.entity_type ilike '%'||v_search||'%'
    or coalesce(a.entity_id,'') ilike '%'||v_search||'%'
    or coalesce(a.reason,'') ilike '%'||v_search||'%'
  order by a.created_at desc,a.id desc
  limit v_limit offset v_offset;
end; $$;
revoke all on function public.get_admin_audit_history(text,integer,integer) from public,anon;
grant execute on function public.get_admin_audit_history(text,integer,integer) to authenticated;
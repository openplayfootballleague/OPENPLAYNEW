-- Audited global feature controls. The recruitment switch blocks new pending
-- team/player membership requests; the announcement switch blocks new broadcasts.
create table public.platform_feature_flags (
  feature_key text primary key
    check (feature_key in ('team_recruitment','announcements')),
  enabled boolean not null,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into public.platform_feature_flags(feature_key,enabled)
values ('team_recruitment',true),('announcements',true)
on conflict (feature_key) do nothing;

alter table public.platform_feature_flags enable row level security;
revoke all on public.platform_feature_flags from public,anon,authenticated;

create policy public_read_platform_feature_switches
on public.platform_feature_flags
for select to anon,authenticated
using (feature_key in ('team_recruitment','announcements'));

grant select(feature_key,enabled)
on public.platform_feature_flags to anon,authenticated;


create or replace function public.is_platform_feature_enabled(p_feature_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select f.enabled
    from public.platform_feature_flags f
    where f.feature_key=p_feature_key
  ),true);
$$;
revoke all on function public.is_platform_feature_enabled(text) from public,anon,authenticated;

create or replace function public.get_admin_platform_feature_flags()
returns table(feature_key text,enabled boolean,updated_at timestamptz,updated_by uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_global_admin_role() then
    raise exception 'Global administrator permission required' using errcode='42501';
  end if;
  return query
    select f.feature_key,f.enabled,f.updated_at,f.updated_by
    from public.platform_feature_flags f
    order by f.feature_key;
end;
$$;
revoke all on function public.get_admin_platform_feature_flags() from public,anon;
grant execute on function public.get_admin_platform_feature_flags() to authenticated;

create or replace function public.admin_set_platform_feature_flag(
  p_feature_key text,
  p_enabled boolean,
  p_reason text
)
returns public.platform_feature_flags
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_before public.platform_feature_flags;
  v_after public.platform_feature_flags;
begin
  if v_actor is null or not public.has_global_admin_role() then
    raise exception 'Global administrator permission required' using errcode='42501';
  end if;
  if p_feature_key not in ('team_recruitment','announcements') then
    raise exception 'Unknown feature flag' using errcode='22023';
  end if;
  if p_enabled is null then
    raise exception 'A feature state is required' using errcode='22023';
  end if;
  if p_reason is null or length(btrim(p_reason))<5 or length(btrim(p_reason))>500 then
    raise exception 'Enter a reason between 5 and 500 characters' using errcode='22023';
  end if;

  select * into v_before
  from public.platform_feature_flags
  where feature_key=p_feature_key
  for update;
  if not found then raise exception 'Feature flag is not configured' using errcode='P0002'; end if;
  if v_before.enabled is not distinct from p_enabled then
    raise exception 'Feature already has the requested state' using errcode='22023';
  end if;

  update public.platform_feature_flags
  set enabled=p_enabled,updated_by=v_actor,updated_at=now()
  where feature_key=p_feature_key
  returning * into v_after;

  insert into public.audit_log(
    actor_user_id,action,entity_type,entity_id,reason,before_data,after_data
  ) values (
    v_actor,'platform.feature_flag.updated','platform_feature_flag',p_feature_key,btrim(p_reason),
    jsonb_build_object('enabled',v_before.enabled),
    jsonb_build_object('enabled',v_after.enabled)
  );
  return v_after;
end;
$$;
revoke all on function public.admin_set_platform_feature_flag(text,boolean,text) from public,anon;
grant execute on function public.admin_set_platform_feature_flag(text,boolean,text) to authenticated;


create or replace function public.get_public_team_recruitment_status()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $function$
  select coalesce((select enabled from public.platform_feature_flags where feature_key='team_recruitment'),true);
$function$;
revoke all on function public.get_public_team_recruitment_status() from public;
grant execute on function public.get_public_team_recruitment_status() to anon,authenticated;

create or replace function public.enforce_team_recruitment_feature_flag()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status::text='pending'
     and not public.is_platform_feature_enabled('team_recruitment') then
    raise exception 'Open Play team recruitment is temporarily paused' using errcode='55000';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_team_recruitment_feature_flag() from public,anon,authenticated;
drop trigger if exists enforce_team_recruitment_feature_flag on public.team_memberships;
create trigger enforce_team_recruitment_feature_flag
before insert or update of status on public.team_memberships
for each row execute function public.enforce_team_recruitment_feature_flag();


create or replace function public.get_public_announcement_status()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $function$
  select coalesce((select enabled from public.platform_feature_flags where feature_key='announcements'),true);
$function$;
revoke all on function public.get_public_announcement_status() from public;
grant execute on function public.get_public_announcement_status() to anon,authenticated;


create or replace function public.enforce_announcement_message_feature_flag()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.message_type='announcement'
     and not public.is_platform_feature_enabled('announcements') then
    raise exception 'Open Play announcements are temporarily paused' using errcode='55000';
  end if;
  return new;
end;
$function$;
revoke all on function public.enforce_announcement_message_feature_flag() from public,anon,authenticated;
drop trigger if exists enforce_announcement_message_feature_flag on public.messages;
create trigger enforce_announcement_message_feature_flag
before insert or update of message_type on public.messages
for each row execute function public.enforce_announcement_message_feature_flag();

create or replace function public.enforce_announcement_feature_flag()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.kind='announcement'
     and not public.is_platform_feature_enabled('announcements') then
    raise exception 'Open Play announcements are temporarily paused' using errcode='55000';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_announcement_feature_flag() from public,anon,authenticated;
drop trigger if exists enforce_announcement_feature_flag on public.message_conversations;
create trigger enforce_announcement_feature_flag
before insert or update of kind on public.message_conversations
for each row execute function public.enforce_announcement_feature_flag();

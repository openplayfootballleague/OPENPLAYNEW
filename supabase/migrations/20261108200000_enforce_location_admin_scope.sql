create table if not exists public.location_admin_assignments (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 location_id uuid not null references public.locations(id) on delete cascade,assigned_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),unique(user_id,location_id)
);
alter table public.location_admin_assignments enable row level security;
revoke all on public.location_admin_assignments from anon,authenticated;
create or replace function public.can_administer_location(p_location_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(select 1 from public.user_roles ur where ur.user_id=auth.uid() and ur.role in ('admin','super_admin'))
 or exists(select 1 from public.user_roles ur join public.location_admin_assignments la on la.user_id=ur.user_id where ur.user_id=auth.uid() and ur.role='league_admin' and la.location_id=p_location_id);
$$;
revoke all on function public.can_administer_location(uuid) from public,anon;
grant execute on function public.can_administer_location(uuid) to authenticated;
create or replace function public.assert_admin_location_context(p_location_id uuid)
returns void language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
 if p_location_id is null then
  if exists(select 1 from public.user_roles where user_id=auth.uid() and role='league_admin') then raise exception 'Location administrators must select an assigned location'; end if;
 elsif not public.can_administer_location(p_location_id) then raise exception 'You are not assigned to this location'; end if;
end;
$$;
revoke all on function public.assert_admin_location_context(uuid) from public,anon;
grant execute on function public.assert_admin_location_context(uuid) to authenticated;
create or replace function public.admin_list_location_assignments(p_location_id uuid default null)
returns table(assignment_id uuid,user_id uuid,location_id uuid,location_name text,assigned_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not exists(select 1 from public.user_roles where user_id=auth.uid() and role in ('admin','super_admin')) then raise exception 'Global administrator permission required'; end if;
 return query select a.id,a.user_id,a.location_id,l.name,a.created_at from public.location_admin_assignments a join public.locations l on l.id=a.location_id where p_location_id is null or a.location_id=p_location_id order by l.name,a.created_at desc;
end;
$$;
create or replace function public.admin_set_location_assignment(p_user_id uuid,p_location_id uuid,p_assigned boolean)
returns void language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null or not exists(select 1 from public.user_roles where user_id=auth.uid() and role in ('admin','super_admin')) then raise exception 'Global administrator permission required'; end if;
 if not exists(select 1 from public.user_roles where user_id=p_user_id and role='league_admin') then raise exception 'The selected user must have the league_admin role'; end if;
 if not exists(select 1 from public.locations where id=p_location_id) then raise exception 'Location not found'; end if;
 if p_assigned then insert into public.location_admin_assignments(user_id,location_id,assigned_by) values(p_user_id,p_location_id,auth.uid()) on conflict(user_id,location_id) do nothing;
 else delete from public.location_admin_assignments where user_id=p_user_id and location_id=p_location_id; end if;
end;
$$;
revoke all on function public.admin_list_location_assignments(uuid) from public,anon;
revoke all on function public.admin_set_location_assignment(uuid,uuid,boolean) from public,anon;
grant execute on function public.admin_list_location_assignments(uuid) to authenticated;
grant execute on function public.admin_set_location_assignment(uuid,uuid,boolean) to authenticated;
do $$
declare v_name text;v_def text;v_sig regprocedure;v_start integer;v_end integer;
begin
 foreach v_name in array array['get_admin_dashboard_contextual(uuid,uuid,uuid)','get_admin_player_register_contextual(text,text,integer,integer,uuid,uuid,uuid)','get_admin_team_sheets_contextual(uuid,uuid,uuid)','admin_get_transfer_requests_contextual(text,uuid,uuid,uuid)','get_admin_contextual_fixtures(uuid,uuid,uuid)'] loop
  v_sig:=v_name::regprocedure;v_def:=pg_get_functiondef(v_sig);
  if position('perform public.assert_admin_location_context(v_location);' in v_def)=0 then
   v_start:=position('if v_location is not null and not exists(' in v_def);
   if v_start=0 then raise exception 'Location validation block not found in %',v_name; end if;
   v_end:=position('end if;' in substring(v_def from v_start));
   if v_end=0 then raise exception 'Location validation terminator not found in %',v_name; end if;
   v_def:=overlay(v_def placing 'perform public.assert_admin_location_context(v_location);' from v_start for v_end+6);
   execute v_def;
  end if;
 end loop;
end;
$$;

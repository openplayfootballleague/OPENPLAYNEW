create table if not exists public.location_admin_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete cascade,
  assigned_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique(user_id,location_id)
);
alter table public.location_admin_assignments enable row level security;
revoke all on public.location_admin_assignments from anon,authenticated;

create or replace function public.can_administer_location(p_location_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
  select exists(select 1 from public.user_roles ur where ur.user_id=auth.uid() and ur.role in ('admin','super_admin'))
    or exists(select 1 from public.user_roles ur join public.location_admin_assignments la on la.user_id=ur.user_id
      where ur.user_id=auth.uid() and ur.role='league_admin' and la.location_id=p_location_id);
$$;
revoke all on function public.can_administer_location(uuid) from public,anon;
grant execute on function public.can_administer_location(uuid) to authenticated;

create or replace function public.admin_list_location_assignments(p_location_id uuid default null)
returns table(assignment_id uuid,user_id uuid,location_id uuid,location_name text,assigned_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
begin
  if auth.uid() is null or not exists(select 1 from public.user_roles where user_id=auth.uid() and role in ('admin','super_admin')) then
    raise exception 'Global administrator permission required';
  end if;
  return query select a.id,a.user_id,a.location_id,l.name,a.created_at from public.location_admin_assignments a join public.locations l on l.id=a.location_id
  where p_location_id is null or a.location_id=p_location_id order by l.name,a.created_at desc;
end;
$$;

create or replace function public.admin_set_location_assignment(p_user_id uuid,p_location_id uuid,p_assigned boolean)
returns void language plpgsql security definer set search_path=''
as $$
begin
  if auth.uid() is null or not exists(select 1 from public.user_roles where user_id=auth.uid() and role in ('admin','super_admin')) then
    raise exception 'Global administrator permission required';
  end if;
  if not exists(select 1 from public.user_roles where user_id=p_user_id and role='league_admin') then
    raise exception 'The selected user must have the league_admin role';
  end if;
  if not exists(select 1 from public.locations where id=p_location_id) then raise exception 'Location not found'; end if;
  if p_assigned then
    insert into public.location_admin_assignments(user_id,location_id,assigned_by) values(p_user_id,p_location_id,auth.uid()) on conflict(user_id,location_id) do nothing;
  else
    delete from public.location_admin_assignments where user_id=p_user_id and location_id=p_location_id;
  end if;
end;
$$;
revoke all on function public.admin_list_location_assignments(uuid) from public,anon;
revoke all on function public.admin_set_location_assignment(uuid,uuid,boolean) from public,anon;
grant execute on function public.admin_list_location_assignments(uuid) to authenticated;
grant execute on function public.admin_set_location_assignment(uuid,uuid,boolean) to authenticated;

create or replace function public.get_admin_context_preference()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_result jsonb;
begin
  if v_user is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select jsonb_build_object('location_id',p.location_id,'league_id',p.league_id,'season_id',p.season_id)
  into v_result from public.admin_context_preferences p where p.user_id=v_user;
  return coalesce(v_result,jsonb_build_object('location_id',null,'league_id',null,'season_id',null));
end;
$$;
create or replace function public.save_admin_context_preference(p_location_id uuid default null,p_league_id uuid default null,p_season_id uuid default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_league_location uuid; v_season_league uuid;
begin
  if v_user is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_season_id is not null then
    select s.league_id into v_season_league from public.seasons s where s.id=p_season_id;
    if v_season_league is null then raise exception 'Selected season was not found'; end if;
    if p_league_id is null then p_league_id:=v_season_league; end if;
    if p_league_id<>v_season_league then raise exception 'Selected season does not belong to selected league'; end if;
  end if;
  if p_league_id is not null then
    select l.location_id into v_league_location from public.leagues l where l.id=p_league_id;
    if v_league_location is null then raise exception 'Selected league was not found'; end if;
    if p_location_id is null then p_location_id:=v_league_location; end if;
    if p_location_id<>v_league_location then raise exception 'Selected league does not belong to selected location'; end if;
  end if;
  if p_location_id is not null and not public.can_administer_location(p_location_id) then raise exception 'You are not assigned to this location'; end if;
  if p_location_id is null and exists(select 1 from public.user_roles where user_id=v_user and role='league_admin') then raise exception 'Location administrators must select an assigned location'; end if;
  insert into public.admin_context_preferences(user_id,location_id,league_id,season_id,updated_at)
  values(v_user,p_location_id,p_league_id,p_season_id,now())
  on conflict(user_id) do update set location_id=excluded.location_id,league_id=excluded.league_id,season_id=excluded.season_id,updated_at=now();
  return jsonb_build_object('location_id',p_location_id,'league_id',p_league_id,'season_id',p_season_id);
end;
$$;

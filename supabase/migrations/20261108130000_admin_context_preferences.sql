create table if not exists public.admin_context_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  location_id uuid references public.locations(id) on delete set null,
  league_id uuid references public.leagues(id) on delete set null,
  season_id uuid references public.seasons(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint admin_context_preference_hierarchy check (
    (season_id is null or league_id is not null) and
    (league_id is null or location_id is not null)
  )
);
alter table public.admin_context_preferences enable row level security;
revoke all on public.admin_context_preferences from anon, authenticated;

create or replace function public.get_admin_context_preference()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_result jsonb;
begin
  if v_user is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  select jsonb_build_object('location_id',p.location_id,'league_id',p.league_id,'season_id',p.season_id)
  into v_result from public.admin_context_preferences p where p.user_id=v_user;
  return coalesce(v_result,jsonb_build_object('location_id',null,'league_id',null,'season_id',null));
end;
$$;

create or replace function public.save_admin_context_preference(
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_league_location uuid; v_season_league uuid;
begin
  if v_user is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_season_id is not null then
    select s.league_id into v_season_league from public.seasons s where s.id=p_season_id;
    if v_season_league is null then raise exception 'Selected season was not found'; end if;
    if p_league_id is null then p_league_id:=v_season_league; end if;
    if p_league_id<>v_season_league then raise exception 'Selected season does not belong to the selected league'; end if;
  end if;
  if p_league_id is not null then
    select l.location_id into v_league_location from public.leagues l where l.id=p_league_id;
    if v_league_location is null then raise exception 'Selected league was not found'; end if;
    if p_location_id is null then p_location_id:=v_league_location; end if;
    if p_location_id<>v_league_location then raise exception 'Selected league does not belong to the selected location'; end if;
  end if;
  if p_location_id is not null and not exists(select 1 from public.locations l where l.id=p_location_id) then
    raise exception 'Selected location was not found';
  end if;
  insert into public.admin_context_preferences(user_id,location_id,league_id,season_id,updated_at)
  values(v_user,p_location_id,p_league_id,p_season_id,now())
  on conflict(user_id) do update set location_id=excluded.location_id,league_id=excluded.league_id,season_id=excluded.season_id,updated_at=now();
  return jsonb_build_object('location_id',p_location_id,'league_id',p_league_id,'season_id',p_season_id);
end;
$$;

revoke all on function public.get_admin_context_preference() from public,anon;
revoke all on function public.save_admin_context_preference(uuid,uuid,uuid) from public,anon;
grant execute on function public.get_admin_context_preference() to authenticated;
grant execute on function public.save_admin_context_preference(uuid,uuid,uuid) to authenticated;

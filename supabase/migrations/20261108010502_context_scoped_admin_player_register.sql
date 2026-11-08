create or replace function public.get_admin_player_register_contextual(
  p_search text default null,
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0,
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null
) returns table(
  user_id uuid,full_name text,email text,phone text,registration_status text,
  is_banned boolean,is_genuine boolean,created_at timestamptz,
  preferred_position text,team_names text[]
)
language plpgsql stable security definer set search_path=''
as $$
declare v_search text:=nullif(btrim(p_search),'');v_location uuid:=p_location_id;v_league uuid:=p_league_id;v_season uuid:=p_season_id;v_league_location uuid;v_season_league uuid;
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_status is not null and p_status not in ('all','pending_review','registered','rejected') then raise exception 'Invalid player registration filter'; end if;
  if v_season is not null then
    select s.league_id into v_season_league from public.seasons s where s.id=v_season;
    if v_season_league is null then raise exception 'Selected season was not found'; end if;
    if v_league is not null and v_league<>v_season_league then raise exception 'Season does not belong to selected league'; end if;
    v_league:=v_season_league;
  end if;
  if v_league is not null then
    select l.location_id into v_league_location from public.leagues l where l.id=v_league;
    if v_league_location is null then raise exception 'Selected league was not found'; end if;
    if v_location is not null and v_location<>v_league_location then raise exception 'League does not belong to selected location'; end if;
    v_location:=v_league_location;
  end if;
  if v_location is not null and not exists(select 1 from public.locations where id=v_location) then raise exception 'Selected location was not found'; end if;
  return query
  select p.user_id,p.full_name,p.email,p.phone,p.registration_status::text,p.is_banned,p.is_genuine,p.created_at,pr.preferred_position,
    coalesce(array_agg(distinct st.name) filter(where tm.status='active' and st.id is not null),'{}'::text[])
  from public.players p
  left join public.profiles pr on pr.id=p.user_id
  left join public.team_memberships tm on tm.user_id=p.user_id and tm.status='active'
  left join public.season_teams st on st.id=tm.season_team_id
  left join public.seasons se on se.id=st.season_id
  left join public.leagues l on l.id=se.league_id
  where (v_search is null or p.full_name ilike '%'||v_search||'%' or p.email ilike '%'||v_search||'%' or p.phone ilike '%'||v_search||'%')
    and (p_status is null or p_status='all' or p.registration_status::text=p_status)
    and (v_location is null or l.location_id=v_location)
    and (v_league is null or l.id=v_league)
    and (v_season is null or se.id=v_season)
  group by p.user_id,p.full_name,p.email,p.phone,p.registration_status,p.is_banned,p.is_genuine,p.created_at,pr.preferred_position
  order by p.full_name
  limit least(greatest(coalesce(p_limit,50),1),100) offset greatest(coalesce(p_offset,0),0);
end;
$$;
revoke all on function public.get_admin_player_register_contextual(text,text,integer,integer,uuid,uuid,uuid) from public,anon;
grant execute on function public.get_admin_player_register_contextual(text,text,integer,integer,uuid,uuid,uuid) to authenticated;
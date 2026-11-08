create or replace function public.admin_get_transfer_requests_contextual(
  p_status text default 'pending',p_location_id uuid default null,p_league_id uuid default null,p_season_id uuid default null
) returns table(id uuid,user_id uuid,player_name text,source_membership_id uuid,source_team_name text,destination_team_id uuid,destination_team_name text,season_name text,league_name text,reason text,status text,requested_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
declare v_location uuid:=p_location_id;v_league uuid:=p_league_id;v_season uuid:=p_season_id;v_league_location uuid;v_season_league uuid;
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_status is not null and p_status not in ('all','pending','approved','rejected','cancelled') then raise exception 'Invalid transfer status filter'; end if;
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
  select r.id,r.user_id,p.full_name,r.source_membership_id,src.name,dst.id,dst.name,se.name,l.name,r.reason,r.status,r.requested_at
  from public.player_transfer_requests r join public.players p on p.user_id=r.user_id
  join public.season_teams src on src.id=r.source_season_team_id join public.season_teams dst on dst.id=r.destination_season_team_id
  join public.seasons se on se.id=src.season_id join public.leagues l on l.id=se.league_id
  where (p_status is null or p_status='all' or r.status=p_status)
    and (v_location is null or l.location_id=v_location) and (v_league is null or l.id=v_league) and (v_season is null or se.id=v_season)
  order by case when r.status='pending' then 0 else 1 end,r.requested_at desc;
end;
$$;
revoke all on function public.admin_get_transfer_requests_contextual(text,uuid,uuid,uuid) from public,anon;
grant execute on function public.admin_get_transfer_requests_contextual(text,uuid,uuid,uuid) to authenticated;

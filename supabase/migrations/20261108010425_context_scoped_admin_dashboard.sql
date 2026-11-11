create or replace function public.get_admin_dashboard_contextual(
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null
) returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare v_result jsonb; v_location uuid:=p_location_id; v_league uuid:=p_league_id; v_season uuid:=p_season_id;
begin
  if auth.uid() is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if v_season is not null then
    select s.league_id into v_league from public.seasons s where s.id=v_season;
    if v_league is null then raise exception 'Selected season was not found'; end if;
    if p_league_id is not null and p_league_id<>v_league then raise exception 'Season does not belong to selected league'; end if;
  end if;
  if v_league is not null then
    select l.location_id into v_location from public.leagues l where l.id=v_league;
    if v_location is null then raise exception 'Selected league was not found'; end if;
    if p_location_id is not null and p_location_id<>v_location then raise exception 'League does not belong to selected location'; end if;
  end if;
  if v_location is not null and not exists(select 1 from public.locations l where l.id=v_location) then
    raise exception 'Selected location was not found';
  end if;
  select jsonb_build_object(
    'counts',jsonb_build_object(
      'pending_player_reviews',(select count(*) from public.player_registration_reviews r where r.status='pending'),
      'pending_team_applications',(select count(*) from public.season_teams st join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where st.registration_status='pending' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location)),
      'pending_membership_requests',(select count(*) from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.status='pending' and st.registration_status='approved' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location)),
      'open_seasons',(select count(*) from public.seasons s join public.leagues l on l.id=s.league_id where s.status='registration_open' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location))
    ),
    'player_reviews',coalesce((select jsonb_agg(jsonb_build_object('player_id',p.id,'full_name',p.full_name,'email',p.email,'phone',p.phone,'created_at',r.created_at,'name_matched',r.name_matched,'phone_matched',r.phone_matched,'email_matched',r.email_matched) order by r.created_at) from public.player_registration_reviews r join public.players p on p.id=r.player_id where r.status='pending'),'[]'::jsonb),
    'team_applications',coalesce((select jsonb_agg(jsonb_build_object('season_team_id',st.id,'team_name',st.name,'season_name',s.name,'created_at',st.created_at) order by st.created_at) from public.season_teams st join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where st.registration_status='pending' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location)),'[]'::jsonb),
    'membership_requests',coalesce((select jsonb_agg(jsonb_build_object('membership_id',tm.id,'team_name',st.name,'player_name',p.full_name,'created_at',tm.created_at) order by tm.created_at) from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id join public.players p on p.user_id=tm.user_id where tm.status='pending' and st.registration_status='approved' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location)),'[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function public.get_admin_dashboard_contextual(uuid,uuid,uuid) from public,anon;
grant execute on function public.get_admin_dashboard_contextual(uuid,uuid,uuid) to authenticated;

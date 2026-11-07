-- Keep admin queue counts consistent with the visible actionable requests.
create or replace function public.get_admin_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select jsonb_build_object(
    'counts',jsonb_build_object(
      'pending_player_reviews',(select count(*) from public.player_registration_reviews r where r.status='pending'),
      'pending_team_applications',(select count(*) from public.season_teams st where st.registration_status='pending'),
      'pending_membership_requests',(select count(*) from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id where tm.status='pending' and st.registration_status='approved'),
      'open_seasons',(select count(*) from public.seasons s where s.status='registration_open')
    ),
    'player_reviews',coalesce((select jsonb_agg(jsonb_build_object(
      'player_id',p.id,'full_name',p.full_name,'email',p.email,'phone',p.phone,'created_at',r.created_at,
      'name_matched',r.name_matched,'phone_matched',r.phone_matched,'email_matched',r.email_matched
    ) order by r.created_at) from public.player_registration_reviews r join public.players p on p.id=r.player_id where r.status='pending'),'[]'::jsonb),
    'team_applications',coalesce((select jsonb_agg(jsonb_build_object(
      'season_team_id',st.id,'team_name',st.name,'season_name',s.name,'created_at',st.created_at
    ) order by st.created_at) from public.season_teams st join public.seasons s on s.id=st.season_id where st.registration_status='pending'),'[]'::jsonb),
    'membership_requests',coalesce((select jsonb_agg(jsonb_build_object(
      'membership_id',tm.id,'team_name',st.name,'player_name',p.full_name,'created_at',tm.created_at
    ) order by tm.created_at) from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id
      join public.players p on p.user_id=tm.user_id where tm.status='pending' and st.registration_status='approved'),'[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

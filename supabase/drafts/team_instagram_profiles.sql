-- Optional, season-specific team Instagram details.
-- Public links are restricted to canonical Instagram profile URLs.
alter table public.season_teams
  add column instagram_handle text,
  add column instagram_url text,
  add constraint season_teams_instagram_handle_valid check (
    instagram_handle is null
    or instagram_handle ~ '^[A-Za-z0-9._]{1,30}$'
  ),
  add constraint season_teams_instagram_url_valid check (
    instagram_url is null
    or instagram_url ~ '^https://www\.instagram\.com/[A-Za-z0-9._]{1,30}/$'
  );

-- Replace the original four-argument overload so PostgREST has one unambiguous
-- team-registration endpoint with optional social fields.
drop function if exists public.register_team(uuid,text,text,text);

create function public.register_team(
  p_season_id uuid,
  p_team_name text,
  p_primary_colour text default null,
  p_secondary_colour text default null,
  p_instagram_handle text default null,
  p_instagram_url text default null
)
returns public.season_teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_player public.players;
  v_season public.seasons;
  v_team_id uuid;
  v_slug text;
  v_instagram_handle text;
  v_instagram_url text;
  v_season_team public.season_teams;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if nullif(trim(p_team_name),'') is null or char_length(trim(p_team_name)) > 80 then
    raise exception 'Team name must be between 1 and 80 characters';
  end if;

  v_instagram_handle := nullif(regexp_replace(trim(coalesce(p_instagram_handle,'')), '^@', ''), '');
  if v_instagram_handle is not null and v_instagram_handle !~ '^[A-Za-z0-9._]{1,30}$' then
    raise exception 'Instagram handle must contain 1 to 30 letters, numbers, dots or underscores';
  end if;

  v_instagram_url := nullif(trim(coalesce(p_instagram_url,'')), '');
  if v_instagram_url is not null then
    if v_instagram_url !~* '^https://(www\.)?instagram\.com(:443)?/[A-Za-z0-9._]{1,30}/?$' then
      raise exception 'Instagram link must be a secure Instagram profile URL';
    end if;
    v_instagram_url := regexp_replace(
      v_instagram_url,
      '^https://(www\.)?instagram\.com(:443)?/([A-Za-z0-9._]{1,30})/?$',
      'https://www.instagram.com/\3/',
      'i'
    );
  end if;

  select * into v_player from public.players where user_id=v_user_id;
  if v_player.id is null or v_player.registration_status <> 'registered' or v_player.is_banned then
    raise exception 'An approved, eligible player registration is required to register a team';
  end if;

  select * into v_season from public.seasons where id=p_season_id and status='registration_open' for share;
  if v_season.id is null then raise exception 'This season is not accepting team registrations'; end if;

  v_slug := trim(both '-' from regexp_replace(lower(trim(p_team_name)),'[^a-z0-9]+','-','g'));
  if v_slug = '' then raise exception 'Team name must contain letters or numbers'; end if;
  if exists(select 1 from public.season_teams where season_id=p_season_id and slug=v_slug) then
    raise exception 'A team with that name is already registered for this season';
  end if;

  insert into public.teams(created_by) values(v_user_id) returning id into v_team_id;
  insert into public.season_teams(
    team_id,season_id,name,slug,primary_colour,secondary_colour,
    instagram_handle,instagram_url,registration_status
  )
  values(
    v_team_id,p_season_id,trim(p_team_name),v_slug,
    nullif(trim(p_primary_colour),''),nullif(trim(p_secondary_colour),''),
    v_instagram_handle,v_instagram_url,'pending'
  )
  returning * into v_season_team;

  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_season_team.id,v_user_id,'pending',false);

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_user_id,'team.registration.submitted','season_team',v_season_team.id::text,
    jsonb_build_object('season_id',p_season_id,'team_name',v_season_team.name));

  return v_season_team;
end;
$$;

revoke all on function public.register_team(uuid,text,text,text,text,text) from public,anon;
grant execute on function public.register_team(uuid,text,text,text,text,text) to authenticated;


-- Include submitted social details in the administrator approval queue so
-- reviewers can inspect the optional public profile before approving a team.
-- Preserve contextual location isolation and global-only player identity reviews
-- while adding the optional social fields to pending team applications.
create or replace function public.get_admin_dashboard_contextual(
  p_location_id uuid default null,
  p_league_id uuid default null,
  p_season_id uuid default null
) returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare
  v_result jsonb;
  v_location uuid:=p_location_id;
  v_league uuid:=p_league_id;
  v_season uuid:=p_season_id;
  v_global_admin boolean:=public.has_global_admin_role();
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
  if v_location is null and not v_global_admin then
    raise exception 'Location administrators must select an assigned location';
  end if;
  if v_location is not null and not public.can_administer_location(v_location) then
    raise exception 'You are not assigned to this location';
  end if;

  select jsonb_build_object(
    'counts',jsonb_build_object(
      'pending_player_reviews',case when v_global_admin then (select count(*) from public.player_registration_reviews r where r.status='pending') else 0 end,
      'pending_team_applications',(select count(*) from public.season_teams st join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where st.registration_status='pending' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location)),
      'pending_membership_requests',(select count(*) from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.status='pending' and st.registration_status='approved' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location)),
      'open_seasons',(select count(*) from public.seasons s join public.leagues l on l.id=s.league_id where s.status='registration_open' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location))
    ),
    'player_reviews',case when v_global_admin then coalesce((select jsonb_agg(jsonb_build_object('player_id',p.id,'full_name',p.full_name,'email',p.email,'phone',p.phone,'created_at',r.created_at,'name_matched',r.name_matched,'phone_matched',r.phone_matched,'email_matched',r.email_matched) order by r.created_at) from public.player_registration_reviews r join public.players p on p.id=r.player_id where r.status='pending'),'[]'::jsonb) else '[]'::jsonb end,
    'team_applications',coalesce((select jsonb_agg(jsonb_build_object('season_team_id',st.id,'team_name',st.name,'season_name',s.name,'created_at',st.created_at,'instagram_handle',st.instagram_handle,'instagram_url',st.instagram_url) order by st.created_at) from public.season_teams st join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where st.registration_status='pending' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location)),'[]'::jsonb),
    'membership_requests',coalesce((select jsonb_agg(jsonb_build_object('membership_id',tm.id,'team_name',st.name,'player_name',p.full_name,'created_at',tm.created_at) order by tm.created_at) from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id join public.players p on p.user_id=tm.user_id where tm.status='pending' and st.registration_status='approved' and (v_season is null or s.id=v_season) and (v_league is null or l.id=v_league) and (v_location is null or l.location_id=v_location)),'[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function public.get_admin_dashboard_contextual(uuid,uuid,uuid) from public,anon;
grant execute on function public.get_admin_dashboard_contextual(uuid,uuid,uuid) to authenticated;

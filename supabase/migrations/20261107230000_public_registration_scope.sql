-- Ensure public-facing registration RPCs cannot target unpublished or private seasons by UUID.
-- The UI already lists only public seasons; enforce the same rule at the database boundary.

create or replace function public.request_team_membership(p_season_team_id uuid)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_player public.players;
  v_membership public.team_memberships;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  select * into v_player from public.players where user_id = v_user_id;
  if v_player.id is null or v_player.registration_status <> 'registered' or v_player.is_banned then
    raise exception 'An approved, eligible player registration is required before joining a team';
  end if;
  if not exists (
    select 1 from public.season_teams st
    join public.seasons s on s.id = st.season_id
    join public.leagues l on l.id = s.league_id
    where st.id = p_season_team_id
      and st.registration_status = 'approved'
      and s.status = 'registration_open'
      and s.is_public = true
      and l.is_published = true
  ) then
    raise exception 'This team is not currently accepting public player requests';
  end if;
  insert into public.team_memberships(season_team_id,user_id,status)
  values(p_season_team_id,v_user_id,'pending')
  on conflict(season_team_id,user_id) do update
    set status='pending',left_at=null,joined_at=null,is_captain=false,updated_at=now()
    where public.team_memberships.status in ('left','rejected')
  returning * into v_membership;
  if v_membership.id is null then raise exception 'A membership or request already exists for this team'; end if;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id)
  values(v_user_id,'team.membership.requested','team_membership',v_membership.id::text);
  return v_membership;
end;
$$;

create or replace function public.register_team(
  p_season_id uuid,
  p_team_name text,
  p_primary_colour text default null,
  p_secondary_colour text default null
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
  v_season_team public.season_teams;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if nullif(trim(p_team_name),'') is null or char_length(trim(p_team_name)) > 80 then
    raise exception 'Team name must be between 1 and 80 characters';
  end if;
  select * into v_player from public.players where user_id=v_user_id;
  if v_player.id is null or v_player.registration_status <> 'registered' or v_player.is_banned then
    raise exception 'An approved, eligible player registration is required to register a team';
  end if;
  select s.* into v_season
  from public.seasons s join public.leagues l on l.id=s.league_id
  where s.id=p_season_id and s.status='registration_open'
    and s.is_public=true and l.is_published=true
  for share of s;
  if v_season.id is null then raise exception 'This season is not accepting public team registrations'; end if;
  v_slug := trim(both '-' from regexp_replace(lower(trim(p_team_name)),'[^a-z0-9]+','-','g'));
  if v_slug = '' then raise exception 'Team name must contain letters or numbers'; end if;
  if exists(select 1 from public.season_teams where season_id=p_season_id and slug=v_slug) then
    raise exception 'A team with that name is already registered for this season';
  end if;
  insert into public.teams(created_by) values(v_user_id) returning id into v_team_id;
  insert into public.season_teams(team_id,season_id,name,slug,primary_colour,secondary_colour,registration_status)
  values(v_team_id,p_season_id,trim(p_team_name),v_slug,nullif(trim(p_primary_colour),''),nullif(trim(p_secondary_colour),''),'pending')
  returning * into v_season_team;
  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_season_team.id,v_user_id,'pending',false);
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_user_id,'team.registration.submitted','season_team',v_season_team.id::text,
    jsonb_build_object('season_id',p_season_id,'team_name',v_season_team.name));
  return v_season_team;
end;
$$;

revoke all on function public.request_team_membership(uuid) from public, anon;
grant execute on function public.request_team_membership(uuid) to authenticated;
revoke all on function public.register_team(uuid,text,text,text) from public, anon;
grant execute on function public.register_team(uuid,text,text,text) to authenticated;

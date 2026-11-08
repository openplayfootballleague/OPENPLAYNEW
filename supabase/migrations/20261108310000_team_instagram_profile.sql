-- Team-owned Instagram profile links.
-- Additive only: the canonical social URL belongs to teams, not player profiles.
alter table public.teams
  add column instagram_profile_url text;

alter table public.teams
  add constraint teams_instagram_profile_url_valid
  check (
    instagram_profile_url is null
    or (
      instagram_profile_url ~ '^https://www[.]instagram[.]com/[A-Za-z0-9._]{1,30}/

create or replace function public.register_team(
  p_season_id uuid,
  p_team_name text,
  p_primary_colour text default null,
  p_secondary_colour text default null,
  p_instagram_profile_url text default null
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
  v_instagram_url text;
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

  v_instagram_url := nullif(trim(p_instagram_profile_url), '');
  if v_instagram_url is not null then
    if v_instagram_url !~* '^https://(www[.])?instagram[.]com/[A-Za-z0-9._]{1,30}/?$'
       or split_part(regexp_replace(v_instagram_url, '^https://(www[.])?instagram[.]com/', '', 'i'), '/', 1) ~ '[.]{2}|^[.]|[.]$' then
      raise exception 'Enter a valid HTTPS Instagram profile URL';
    end if;
    v_instagram_url := regexp_replace(v_instagram_url, '^https://instagram[.]com/', 'https://www.instagram.com/', 'i');
    if right(v_instagram_url,1) <> '/' then v_instagram_url := v_instagram_url || '/'; end if;
  end if;

  v_slug := trim(both '-' from regexp_replace(lower(trim(p_team_name)),'[^a-z0-9]+','-','g'));
  if v_slug = '' then raise exception 'Team name must contain letters or numbers'; end if;
  if exists(select 1 from public.season_teams where season_id=p_season_id and slug=v_slug) then
    raise exception 'A team with that name is already registered for this season';
  end if;
  insert into public.teams(created_by,instagram_profile_url)
  values(v_user_id,v_instagram_url) returning id into v_team_id;
  insert into public.season_teams(team_id,season_id,name,slug,primary_colour,secondary_colour,registration_status)
  values(v_team_id,p_season_id,trim(p_team_name),v_slug,nullif(trim(p_primary_colour),''),nullif(trim(p_secondary_colour),''),'pending')
  returning * into v_season_team;
  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_season_team.id,v_user_id,'pending',false);
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_user_id,'team.registration.submitted','season_team',v_season_team.id::text,
    jsonb_build_object('season_id',p_season_id,'team_name',v_season_team.name,
      'instagram_profile_provided',v_instagram_url is not null));
  return v_season_team;
end;
$$;

revoke all on function public.register_team(uuid,text,text,text,text) from public,anon;
grant execute on function public.register_team(uuid,text,text,text,text) to authenticated;

create or replace function public.update_team_instagram_profile(
  p_season_team_id uuid,
  p_instagram_profile_url text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_team_id uuid;
  v_location_id uuid;
  v_url text := nullif(trim(p_instagram_profile_url), '');
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  select st.team_id, l.location_id into v_team_id, v_location_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=p_season_team_id;
  if v_team_id is null then raise exception 'Team not found'; end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id=v_user_id and ur.role in ('admin','super_admin')
  ) and not public.can_administer_location(v_location_id) and not exists (
    select 1 from public.team_memberships tm
    where tm.season_team_id=p_season_team_id
      and tm.user_id=v_user_id
      and tm.status='active'
      and tm.is_captain=true
  ) then
    raise exception 'Active team captain or administrator permission required';
  end if;

  if v_url is not null then
    if v_url !~* '^https://(www[.])?instagram[.]com/[A-Za-z0-9._]{1,30}/?$'
       or split_part(regexp_replace(v_url, '^https://(www[.])?instagram[.]com/', '', 'i'), '/', 1) ~ '[.]{2}|^[.]|[.]$' then
      raise exception 'Enter a valid HTTPS Instagram profile URL';
    end if;
    v_url := regexp_replace(v_url, '^https://instagram[.]com/', 'https://www.instagram.com/', 'i');
    if right(v_url,1) <> '/' then v_url := v_url || '/'; end if;
  end if;

  update public.teams set instagram_profile_url=v_url where id=v_team_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_user_id,'team.instagram_profile.updated','team',v_team_id::text,
    jsonb_build_object('instagram_profile_provided',v_url is not null));
  return v_url;
end;
$$;

revoke all on function public.update_team_instagram_profile(uuid,text) from public,anon;
grant execute on function public.update_team_instagram_profile(uuid,text) to authenticated;

create or replace function public.get_captain_team_social_profiles()
returns table (
  season_team_id uuid,
  team_name text,
  instagram_profile_url text
)
language sql
security definer
set search_path = ''
as $$
  select st.id, st.name, t.instagram_profile_url
  from public.team_memberships tm
  join public.season_teams st on st.id=tm.season_team_id
  join public.teams t on t.id=st.team_id
  where tm.user_id=auth.uid()
    and tm.status='active'
    and tm.is_captain=true
  order by st.name;
$$;

revoke all on function public.get_captain_team_social_profiles() from public,anon;
grant execute on function public.get_captain_team_social_profiles() to authenticated;

-- Public team profiles are exposed through a narrowly scoped RPC.
-- Do not add a permissive policy to public.teams: authenticated already has
-- table-level SELECT for member/admin workflows, so a public policy there
-- would expose every selectable column (including created_by).
create or replace function public.get_public_team_directory(
  p_season_team_id uuid default null
)
returns table (
  season_team_id uuid,
  team_name text,
  season_id uuid,
  season_name text,
  starts_on date,
  primary_colour text,
  secondary_colour text,
  instagram_profile_url text
)
language sql
stable
security definer
set search_path = ''
as $$
  select st.id, st.name, s.id, s.name, s.starts_on,
         st.primary_colour, st.secondary_colour, t.instagram_profile_url
  from public.season_teams st
  join public.teams t on t.id=st.team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.registration_status='approved'
    and s.is_public=true
    and s.status in ('active','completed')
    and l.is_published=true
    and (p_season_team_id is null or st.id=p_season_team_id)
  order by s.starts_on desc, s.name, st.name;
$$;

revoke all on function public.get_public_team_directory(uuid) from public, anon;
grant execute on function public.get_public_team_directory(uuid) to anon, authenticated;

create or replace function public.admin_get_team_social_profiles()
returns table (
  season_team_id uuid,
  team_name text,
  season_name text,
  location_name text,
  instagram_profile_url text
)
language sql
security definer
set search_path = ''
as $$
  select st.id, st.name, s.name, l.name, t.instagram_profile_url
  from public.season_teams st
  join public.teams t on t.id=st.team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where exists (select 1 from public.user_roles ur where ur.user_id=auth.uid() and ur.role in ('admin','super_admin'))
     or public.can_administer_location(l.location_id)
  order by l.name, s.name, st.name;
$$;

revoke all on function public.admin_get_team_social_profiles() from public,anon;
grant execute on function public.admin_get_team_social_profiles() to authenticated;

      and split_part(
        regexp_replace(instagram_profile_url, '^https://www[.]instagram[.]com/', ''),
        '/',
        1
      ) !~ '(^[.]|[.]{2}|[.]$)'
    )
  );

create or replace function public.register_team(
  p_season_id uuid,
  p_team_name text,
  p_primary_colour text default null,
  p_secondary_colour text default null,
  p_instagram_profile_url text default null
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
  v_instagram_url text;
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

  v_instagram_url := nullif(trim(p_instagram_profile_url), '');
  if v_instagram_url is not null then
    if v_instagram_url !~* '^https://(www[.])?instagram[.]com/[A-Za-z0-9._]{1,30}/?$'
       or split_part(regexp_replace(v_instagram_url, '^https://(www[.])?instagram[.]com/', '', 'i'), '/', 1) ~ '[.]{2}|^[.]|[.]$' then
      raise exception 'Enter a valid HTTPS Instagram profile URL';
    end if;
    v_instagram_url := regexp_replace(v_instagram_url, '^https://instagram[.]com/', 'https://www.instagram.com/', 'i');
    if right(v_instagram_url,1) <> '/' then v_instagram_url := v_instagram_url || '/'; end if;
  end if;

  v_slug := trim(both '-' from regexp_replace(lower(trim(p_team_name)),'[^a-z0-9]+','-','g'));
  if v_slug = '' then raise exception 'Team name must contain letters or numbers'; end if;
  if exists(select 1 from public.season_teams where season_id=p_season_id and slug=v_slug) then
    raise exception 'A team with that name is already registered for this season';
  end if;
  insert into public.teams(created_by,instagram_profile_url)
  values(v_user_id,v_instagram_url) returning id into v_team_id;
  insert into public.season_teams(team_id,season_id,name,slug,primary_colour,secondary_colour,registration_status)
  values(v_team_id,p_season_id,trim(p_team_name),v_slug,nullif(trim(p_primary_colour),''),nullif(trim(p_secondary_colour),''),'pending')
  returning * into v_season_team;
  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_season_team.id,v_user_id,'pending',false);
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_user_id,'team.registration.submitted','season_team',v_season_team.id::text,
    jsonb_build_object('season_id',p_season_id,'team_name',v_season_team.name,
      'instagram_profile_provided',v_instagram_url is not null));
  return v_season_team;
end;
$$;

revoke all on function public.register_team(uuid,text,text,text,text) from public,anon;
grant execute on function public.register_team(uuid,text,text,text,text) to authenticated;

create or replace function public.update_team_instagram_profile(
  p_season_team_id uuid,
  p_instagram_profile_url text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_team_id uuid;
  v_location_id uuid;
  v_url text := nullif(trim(p_instagram_profile_url), '');
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  select st.team_id, l.location_id into v_team_id, v_location_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=p_season_team_id;
  if v_team_id is null then raise exception 'Team not found'; end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id=v_user_id and ur.role in ('admin','super_admin')
  ) and not public.can_administer_location(v_location_id) and not exists (
    select 1 from public.team_memberships tm
    where tm.season_team_id=p_season_team_id
      and tm.user_id=v_user_id
      and tm.status='active'
      and tm.is_captain=true
  ) then
    raise exception 'Active team captain or administrator permission required';
  end if;

  if v_url is not null then
    if v_url !~* '^https://(www[.])?instagram[.]com/[A-Za-z0-9._]{1,30}/?$'
       or split_part(regexp_replace(v_url, '^https://(www[.])?instagram[.]com/', '', 'i'), '/', 1) ~ '[.]{2}|^[.]|[.]$' then
      raise exception 'Enter a valid HTTPS Instagram profile URL';
    end if;
    v_url := regexp_replace(v_url, '^https://instagram[.]com/', 'https://www.instagram.com/', 'i');
    if right(v_url,1) <> '/' then v_url := v_url || '/'; end if;
  end if;

  update public.teams set instagram_profile_url=v_url where id=v_team_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_user_id,'team.instagram_profile.updated','team',v_team_id::text,
    jsonb_build_object('instagram_profile_provided',v_url is not null));
  return v_url;
end;
$$;

revoke all on function public.update_team_instagram_profile(uuid,text) from public,anon;
grant execute on function public.update_team_instagram_profile(uuid,text) to authenticated;

create or replace function public.get_captain_team_social_profiles()
returns table (
  season_team_id uuid,
  team_name text,
  instagram_profile_url text
)
language sql
security definer
set search_path = ''
as $$
  select st.id, st.name, t.instagram_profile_url
  from public.team_memberships tm
  join public.season_teams st on st.id=tm.season_team_id
  join public.teams t on t.id=st.team_id
  where tm.user_id=auth.uid()
    and tm.status='active'
    and tm.is_captain=true
  order by st.name;
$$;

revoke all on function public.get_captain_team_social_profiles() from public,anon;
grant execute on function public.get_captain_team_social_profiles() to authenticated;

-- Public team profiles are exposed through a narrowly scoped RPC.
-- Do not add a permissive policy to public.teams: authenticated already has
-- table-level SELECT for member/admin workflows, so a public policy there
-- would expose every selectable column (including created_by).
create or replace function public.get_public_team_directory(
  p_season_team_id uuid default null
)
returns table (
  season_team_id uuid,
  team_name text,
  season_id uuid,
  season_name text,
  starts_on date,
  primary_colour text,
  secondary_colour text,
  instagram_profile_url text
)
language sql
stable
security definer
set search_path = ''
as $$
  select st.id, st.name, s.id, s.name, s.starts_on,
         st.primary_colour, st.secondary_colour, t.instagram_profile_url
  from public.season_teams st
  join public.teams t on t.id=st.team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.registration_status='approved'
    and s.is_public=true
    and s.status in ('active','completed')
    and l.is_published=true
    and (p_season_team_id is null or st.id=p_season_team_id)
  order by s.starts_on desc, s.name, st.name;
$$;

revoke all on function public.get_public_team_directory(uuid) from public, anon;
grant execute on function public.get_public_team_directory(uuid) to anon, authenticated;

create or replace function public.admin_get_team_social_profiles()
returns table (
  season_team_id uuid,
  team_name text,
  season_name text,
  location_name text,
  instagram_profile_url text
)
language sql
security definer
set search_path = ''
as $$
  select st.id, st.name, s.name, l.name, t.instagram_profile_url
  from public.season_teams st
  join public.teams t on t.id=st.team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where exists (select 1 from public.user_roles ur where ur.user_id=auth.uid() and ur.role in ('admin','super_admin'))
     or public.can_administer_location(l.location_id)
  order by l.name, s.name, st.name;
$$;

revoke all on function public.admin_get_team_social_profiles() from public,anon;
grant execute on function public.admin_get_team_social_profiles() to authenticated;

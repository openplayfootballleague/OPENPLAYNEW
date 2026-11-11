-- Optional team-owned Instagram identity.
-- Keep the profile URL separate from the handle: only a validated profile URL
-- is used for a clickable public Instagram link.
alter table public.teams
  add column instagram_profile_url text,
  add column instagram_handle text;

alter table public.teams
  add constraint teams_instagram_profile_url_valid
  check (
    instagram_profile_url is null
    or (
      instagram_profile_url ~ '^https://www[.]instagram[.]com/[A-Za-z0-9._]{1,30}/$'
      and split_part(regexp_replace(instagram_profile_url,'^https://www[.]instagram[.]com/',''), '/', 1)
        !~ '(^[.]|[.]{2}|[.]$)'
    )
  ),
  add constraint teams_instagram_handle_valid
  check (
    instagram_handle is null
    or (
      instagram_handle ~ '^[A-Za-z0-9_](?:[A-Za-z0-9._]{0,28}[A-Za-z0-9_])?$'
      and instagram_handle !~ '[.]{2}'
    )
  );

-- Delegate to the existing four-argument registration RPC. This preserves
-- its approved-player, published-season, duplicate-name and audit safeguards.
create or replace function public.register_team(
  p_season_id uuid,
  p_team_name text,
  p_primary_colour text,
  p_secondary_colour text,
  p_instagram_profile_url text
)
returns public.season_teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_team public.season_teams;
  v_url text := nullif(trim(p_instagram_profile_url), '');
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if v_url is not null then
    if v_url !~* '^https://(www[.])?instagram[.]com/[A-Za-z0-9._]{1,30}/?$'
       or split_part(regexp_replace(v_url,'^https://(www[.])?instagram[.]com/','','i'), '/', 1) ~ '(^[.]|[.]{2}|[.]$)' then
      raise exception 'Enter a valid HTTPS Instagram profile URL';
    end if;
    v_url := regexp_replace(v_url,'^https://(www[.])?instagram[.]com/','https://www.instagram.com/','i');
    if right(v_url,1)<>'/' then v_url:=v_url||'/'; end if;
  end if;

  v_team := public.register_team(p_season_id,p_team_name,p_primary_colour,p_secondary_colour);
  update public.teams
     set instagram_profile_url=v_url
   where id=v_team.team_id and created_by=v_actor;
  if not found then raise exception 'Could not attach Instagram profile to the newly registered team'; end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'team.instagram_profile.submitted','team',v_team.team_id::text,
    jsonb_build_object('instagram_profile_provided',v_url is not null));
  return v_team;
end;
$$;
revoke all on function public.register_team(uuid,text,text,text,text) from public,anon;
grant execute on function public.register_team(uuid,text,text,text,text) to authenticated;

-- Six-argument overload keeps the profile URL and independent handle optional
-- at the UI boundary without changing the legacy four-argument signature.
create or replace function public.register_team(
  p_season_id uuid,
  p_team_name text,
  p_primary_colour text,
  p_secondary_colour text,
  p_instagram_profile_url text,
  p_instagram_handle text
)
returns public.season_teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_team public.season_teams;
  v_handle text := nullif(trim(p_instagram_handle),'');
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if v_handle is not null then
    v_handle := regexp_replace(v_handle,'^@','');
    if v_handle !~ '^[A-Za-z0-9_](?:[A-Za-z0-9._]{0,28}[A-Za-z0-9_])?$'
       or v_handle !~ '^[A-Za-z0-9_]'
       or v_handle ~ '[.]{2}' then
      raise exception 'Enter a valid Instagram handle';
    end if;
  end if;

  v_team := public.register_team(
    p_season_id,p_team_name,p_primary_colour,p_secondary_colour,p_instagram_profile_url
  );
  update public.teams
     set instagram_handle=v_handle
   where id=v_team.team_id and created_by=v_actor;
  if not found then raise exception 'Could not attach Instagram handle to the newly registered team'; end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'team.instagram_handle.submitted','team',v_team.team_id::text,
    jsonb_build_object('instagram_handle_provided',v_handle is not null));
  return v_team;
end;
$$;
revoke all on function public.register_team(uuid,text,text,text,text,text) from public,anon;
grant execute on function public.register_team(uuid,text,text,text,text,text) to authenticated;

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
  v_actor uuid:=auth.uid();
  v_team_id uuid;
  v_location_id uuid;
  v_url text:=nullif(trim(p_instagram_profile_url),'');
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select st.team_id,l.location_id into v_team_id,v_location_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=p_season_team_id;
  if v_team_id is null then raise exception 'Team not found'; end if;

  if not public.can_administer_location(v_location_id)
     and not exists(
       select 1 from public.team_memberships tm
       where tm.season_team_id=p_season_team_id
         and tm.user_id=v_actor and tm.status='active' and tm.is_captain is true
     ) then
    raise exception 'Active team captain or assigned location administrator permission required';
  end if;

  if v_url is not null then
    if v_url !~* '^https://(www[.])?instagram[.]com/[A-Za-z0-9._]{1,30}/?$'
       or split_part(regexp_replace(v_url,'^https://(www[.])?instagram[.]com/','','i'), '/', 1) ~ '(^[.]|[.]{2}|[.]$)' then
      raise exception 'Enter a valid HTTPS Instagram profile URL';
    end if;
    v_url:=regexp_replace(v_url,'^https://(www[.])?instagram[.]com/','https://www.instagram.com/','i');
    if right(v_url,1)<>'/' then v_url:=v_url||'/'; end if;
  end if;

  update public.teams set instagram_profile_url=v_url where id=v_team_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'team.instagram_profile.updated','team',v_team_id::text,
    jsonb_build_object('instagram_profile_provided',v_url is not null));
  return v_url;
end;
$$;
revoke all on function public.update_team_instagram_profile(uuid,text) from public,anon;
grant execute on function public.update_team_instagram_profile(uuid,text) to authenticated;

create or replace function public.get_public_team_directory(p_season_id uuid)
returns table(
  season_team_id uuid,
  team_name text,
  season_id uuid,
  season_name text,
  starts_on date,
  primary_colour text,
  secondary_colour text,
  instagram_profile_url text,
  instagram_handle text
)
language sql
stable
security definer
set search_path = ''
as $$
  select st.id,st.name,s.id,s.name,s.starts_on,st.primary_colour,st.secondary_colour,
         t.instagram_profile_url,t.instagram_handle
  from public.season_teams st
  join public.teams t on t.id=st.team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  join public.locations loc on loc.id=l.location_id
  where st.registration_status='approved'
    and s.id=p_season_id
    and s.is_public is true
    and s.status in ('registration_open','active','completed')
    and l.is_published is true
    and loc.is_active is true
  order by st.name;
$$;
revoke all on function public.get_public_team_directory(uuid) from public,anon;
grant execute on function public.get_public_team_directory(uuid) to anon,authenticated;

create or replace function public.get_public_team_profile(p_season_team_id uuid)
returns table(
  season_team_id uuid,
  team_name text,
  season_id uuid,
  season_name text,
  starts_on date,
  primary_colour text,
  secondary_colour text,
  instagram_profile_url text,
  instagram_handle text
)
language sql
stable
security definer
set search_path = ''
as $$
  select st.id,st.name,s.id,s.name,s.starts_on,st.primary_colour,st.secondary_colour,
         t.instagram_profile_url,t.instagram_handle
  from public.season_teams st
  join public.teams t on t.id=st.team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=p_season_team_id
    and st.registration_status='approved'
    and s.is_public is true
    and s.status in ('registration_open','active','completed')
    and l.is_published is true
    and loc.is_active is true
  limit 1;
$$;
revoke all on function public.get_public_team_profile(uuid) from public,anon;
grant execute on function public.get_public_team_profile(uuid) to anon,authenticated;

create or replace function public.get_captain_team_social_profiles()
returns table(season_team_id uuid,team_name text,instagram_profile_url text,instagram_handle text)
language sql
stable
security definer
set search_path = ''
as $$
  select st.id,st.name,t.instagram_profile_url,t.instagram_handle
  from public.team_memberships tm
  join public.season_teams st on st.id=tm.season_team_id
  join public.teams t on t.id=st.team_id
  where tm.user_id=auth.uid() and tm.status='active' and tm.is_captain is true
  order by st.name;
$$;
revoke all on function public.get_captain_team_social_profiles() from public,anon;
grant execute on function public.get_captain_team_social_profiles() to authenticated;


create or replace function public.admin_get_team_social_profiles()
returns table(
  season_team_id uuid,
  team_name text,
  season_name text,
  location_name text,
  instagram_profile_url text,
  instagram_handle text
)
language sql
stable
security definer
set search_path = ''
as $$
  select st.id,st.name,s.name,loc.name,t.instagram_profile_url,t.instagram_handle
  from public.season_teams st
  join public.teams t on t.id=st.team_id
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  join public.locations loc on loc.id=l.location_id
  where public.can_administer_location(loc.id)
  order by loc.name,s.name,st.name;
$$;
revoke all on function public.admin_get_team_social_profiles() from public,anon;
grant execute on function public.admin_get_team_social_profiles() to authenticated;

create or replace function public.update_team_instagram_details(
  p_season_team_id uuid,
  p_instagram_profile_url text,
  p_instagram_handle text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_team_id uuid;
  v_location_id uuid;
  v_url text:=nullif(trim(p_instagram_profile_url),'');
  v_handle text:=nullif(trim(p_instagram_handle),'');
begin
  if v_actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select st.team_id,l.location_id into v_team_id,v_location_id
  from public.season_teams st
  join public.seasons s on s.id=st.season_id
  join public.leagues l on l.id=s.league_id
  where st.id=p_season_team_id;
  if v_team_id is null then raise exception 'Team not found'; end if;

  if not public.can_administer_location(v_location_id)
     and not exists(
       select 1 from public.team_memberships tm
       where tm.season_team_id=p_season_team_id
         and tm.user_id=v_actor and tm.status='active' and tm.is_captain is true
     ) then
    raise exception 'Active team captain or assigned location administrator permission required';
  end if;

  if v_url is not null then
    if v_url !~* '^https://(www[.])?instagram[.]com/[A-Za-z0-9._]{1,30}/?$'
       or split_part(regexp_replace(v_url,'^https://(www[.])?instagram[.]com/','','i'), '/', 1) ~ '(^[.]|[.]{2}|[.]$)' then
      raise exception 'Enter a valid HTTPS Instagram profile URL';
    end if;
    v_url:=regexp_replace(v_url,'^https://(www[.])?instagram[.]com/','https://www.instagram.com/','i');
    if right(v_url,1)<>'/' then v_url:=v_url||'/'; end if;
  end if;

  if v_handle is not null then
    v_handle:=regexp_replace(v_handle,'^@','');
    if v_handle !~ '^[A-Za-z0-9_](?:[A-Za-z0-9._]{0,28}[A-Za-z0-9_])?$'
       or v_handle ~ '[.]{2}' then
      raise exception 'Enter a valid Instagram handle';
    end if;
  end if;

  update public.teams
     set instagram_profile_url=v_url,instagram_handle=v_handle
   where id=v_team_id;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'team.instagram_details.updated','team',v_team_id::text,
    jsonb_build_object(
      'instagram_profile_provided',v_url is not null,
      'instagram_handle_provided',v_handle is not null
    ));
end;
$$;
revoke all on function public.update_team_instagram_details(uuid,text,text) from public,anon;
grant execute on function public.update_team_instagram_details(uuid,text,text) to authenticated;

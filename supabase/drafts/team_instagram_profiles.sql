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
    if v_instagram_url !~* '^https://(www\.)?instagram\.com/[A-Za-z0-9._]{1,30}/?$' then
      raise exception 'Instagram link must be a secure Instagram profile URL';
    end if;
    v_instagram_url := regexp_replace(
      v_instagram_url,
      '^https://(www\.)?instagram\.com/([A-Za-z0-9._]{1,30})/?$',
      'https://www.instagram.com/\2/',
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

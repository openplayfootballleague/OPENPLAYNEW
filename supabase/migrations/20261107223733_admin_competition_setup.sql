-- Admin-only competition bootstrap. New records remain unpublished/draft until an
-- administrator explicitly opens registration or publishes the league.
create or replace function public.get_admin_competition_setup()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;

  return jsonb_build_object(
    'locations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id, 'name', l.name, 'town', l.town, 'region', l.region,
        'address', l.address, 'is_active', l.is_active
      ) order by l.name)
      from public.locations l
    ), '[]'::jsonb),
    'leagues', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id, 'location_id', l.location_id, 'location_name', loc.name,
        'name', l.name, 'format', l.format, 'description', l.description,
        'is_published', l.is_published
      ) order by loc.name, l.name)
      from public.leagues l
      join public.locations loc on loc.id = l.location_id
    ), '[]'::jsonb),
    'seasons', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'league_id', s.league_id, 'league_name', l.name,
        'location_name', loc.name, 'name', s.name, 'season_number', s.season_number,
        'starts_on', s.starts_on, 'ends_on', s.ends_on,
        'registration_opens_at', s.registration_opens_at,
        'registration_closes_at', s.registration_closes_at,
        'status', s.status, 'is_public', s.is_public
      ) order by loc.name, l.name, s.created_at desc)
      from public.seasons s
      join public.leagues l on l.id = s.league_id
      join public.locations loc on loc.id = l.location_id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_create_location(
  p_name text,
  p_town text,
  p_region text default 'North Devon',
  p_address text default null
)
returns public.locations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_slug text;
  v_location public.locations;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_name is null or length(btrim(p_name)) < 2 or length(btrim(p_name)) > 100 then
    raise exception 'Location name must be between 2 and 100 characters';
  end if;
  if p_town is null or length(btrim(p_town)) < 2 or length(btrim(p_town)) > 100 then
    raise exception 'Town must be between 2 and 100 characters';
  end if;
  if p_region is null or length(btrim(p_region)) < 2 or length(btrim(p_region)) > 100 then
    raise exception 'Region must be between 2 and 100 characters';
  end if;

  v_slug := trim(both '-' from regexp_replace(lower(btrim(p_name)), '[^a-z0-9]+', '-', 'g'));
  if v_slug = '' then raise exception 'Location name must contain letters or numbers'; end if;

  insert into public.locations(name, slug, town, region, address, is_active)
  values (btrim(p_name), v_slug, btrim(p_town), btrim(p_region), nullif(btrim(p_address), ''), true)
  returning * into v_location;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, after_data)
  values (v_actor, 'location.created', 'location', v_location.id::text,
    jsonb_build_object('name', v_location.name, 'town', v_location.town, 'region', v_location.region));

  return v_location;
end;
$$;

create or replace function public.admin_create_league(
  p_location_id uuid,
  p_name text,
  p_format public.competition_format,
  p_description text default null
)
returns public.leagues
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_location public.locations;
  v_slug text;
  v_league public.leagues;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_name is null or length(btrim(p_name)) < 2 or length(btrim(p_name)) > 120 then
    raise exception 'League name must be between 2 and 120 characters';
  end if;
  if p_format is null then raise exception 'Choose a competition format'; end if;

  select * into v_location from public.locations where id = p_location_id and is_active = true;
  if not found then raise exception 'Choose an active location'; end if;

  v_slug := v_location.slug || '-' ||
    trim(both '-' from regexp_replace(lower(btrim(p_name)), '[^a-z0-9]+', '-', 'g'));
  if v_slug = '' then raise exception 'League name must contain letters or numbers'; end if;

  insert into public.leagues(location_id, name, slug, format, description, is_published)
  values (p_location_id, btrim(p_name), v_slug, p_format, nullif(btrim(p_description), ''), false)
  returning * into v_league;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, after_data)
  values (v_actor, 'league.created', 'league', v_league.id::text,
    jsonb_build_object('location_id', p_location_id, 'name', v_league.name, 'format', v_league.format, 'is_published', false));

  return v_league;
end;
$$;

create or replace function public.admin_create_season(
  p_league_id uuid,
  p_name text,
  p_season_number integer default null,
  p_starts_on date default null,
  p_ends_on date default null,
  p_registration_opens_at timestamptz default null,
  p_registration_closes_at timestamptz default null
)
returns public.seasons
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_league public.leagues;
  v_season public.seasons;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_name is null or length(btrim(p_name)) < 2 or length(btrim(p_name)) > 120 then
    raise exception 'Season name must be between 2 and 120 characters';
  end if;
  if p_season_number is not null and p_season_number < 1 then
    raise exception 'Season number must be positive';
  end if;
  if p_starts_on is not null and p_ends_on is not null and p_ends_on < p_starts_on then
    raise exception 'Season end date cannot be before its start date';
  end if;
  if p_registration_opens_at is not null and p_registration_closes_at is not null
    and p_registration_closes_at <= p_registration_opens_at then
    raise exception 'Registration close must be after registration opens';
  end if;

  select * into v_league from public.leagues where id = p_league_id;
  if not found then raise exception 'Choose an existing league'; end if;

  insert into public.seasons(
    league_id, name, season_number, starts_on, ends_on,
    registration_opens_at, registration_closes_at, status, is_public
  )
  values (
    p_league_id, btrim(p_name), p_season_number, p_starts_on, p_ends_on,
    p_registration_opens_at, p_registration_closes_at, 'draft', false
  )
  returning * into v_season;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, after_data)
  values (v_actor, 'season.created', 'season', v_season.id::text,
    jsonb_build_object('league_id', p_league_id, 'name', v_season.name,
      'status', 'draft', 'is_public', false));

  return v_season;
end;
$$;

revoke all on function public.get_admin_competition_setup() from public, anon;
grant execute on function public.get_admin_competition_setup() to authenticated;
revoke all on function public.admin_create_location(text, text, text, text) from public, anon;
grant execute on function public.admin_create_location(text, text, text, text) to authenticated;
revoke all on function public.admin_create_league(uuid, text, public.competition_format, text) from public, anon;
grant execute on function public.admin_create_league(uuid, text, public.competition_format, text) to authenticated;
revoke all on function public.admin_create_season(uuid, text, integer, date, date, timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_create_season(uuid, text, integer, date, date, timestamptz, timestamptz) to authenticated;

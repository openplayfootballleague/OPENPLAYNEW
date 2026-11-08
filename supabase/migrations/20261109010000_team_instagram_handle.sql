-- Optional team Instagram handle, stored separately from the profile URL.
alter table public.teams
  add column instagram_handle text;

alter table public.teams
  add constraint teams_instagram_handle_valid
  check (
    instagram_handle is null
    or (
      instagram_handle ~ '^[A-Za-z0-9_](?:[A-Za-z0-9._]{0,28}[A-Za-z0-9_])?

-- Keep the existing five-argument registration function intact for legacy
-- callers. This explicit six-argument overload adds the optional handle while
-- delegating all team/season/player eligibility checks to the established RPC.
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
as $function$
declare
  v_actor uuid := auth.uid();
  v_team public.season_teams;
  v_handle text := nullif(trim(p_instagram_handle), '');
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  if v_handle is not null then
    v_handle := regexp_replace(v_handle, '^@', '');
    if v_handle !~ '^[A-Za-z0-9_](?:[A-Za-z0-9._]{0,28}[A-Za-z0-9_])?$'
       or position('..' in v_handle) > 0 then
      raise exception 'Enter a valid Instagram handle';
    end if;
  end if;

  v_team := public.register_team(
    p_season_id,
    p_team_name,
    p_primary_colour,
    p_secondary_colour,
    p_instagram_profile_url
  );

  update public.teams
     set instagram_handle = v_handle
   where id = v_team.team_id
     and created_by = v_actor;

  if not found then
    raise exception 'Could not attach Instagram handle to the newly registered team';
  end if;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, after_data)
  values (
    v_actor,
    'team.instagram_handle.submitted',
    'team',
    v_team.team_id::text,
    jsonb_build_object('instagram_handle_provided', v_handle is not null)
  );

  return v_team;
end;
$function$;

revoke all on function public.register_team(uuid,text,text,text,text,text) from public, anon;
grant execute on function public.register_team(uuid,text,text,text,text,text) to authenticated;

      and instagram_handle !~ '[.]{2}'
    )
  );

-- Keep the existing five-argument registration function intact for legacy
-- callers. This explicit six-argument overload adds the optional handle while
-- delegating all team/season/player eligibility checks to the established RPC.
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
as $function$
declare
  v_actor uuid := auth.uid();
  v_team public.season_teams;
  v_handle text := nullif(trim(p_instagram_handle), '');
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  if v_handle is not null then
    v_handle := regexp_replace(v_handle, '^@', '');
    if v_handle !~ '^[A-Za-z0-9_](?:[A-Za-z0-9._]{0,28}[A-Za-z0-9_])?$'
       or position('..' in v_handle) > 0 then
      raise exception 'Enter a valid Instagram handle';
    end if;
  end if;

  v_team := public.register_team(
    p_season_id,
    p_team_name,
    p_primary_colour,
    p_secondary_colour,
    p_instagram_profile_url
  );

  update public.teams
     set instagram_handle = v_handle
   where id = v_team.team_id
     and created_by = v_actor;

  if not found then
    raise exception 'Could not attach Instagram handle to the newly registered team';
  end if;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, after_data)
  values (
    v_actor,
    'team.instagram_handle.submitted',
    'team',
    v_team.team_id::text,
    jsonb_build_object('instagram_handle_provided', v_handle is not null)
  );

  return v_team;
end;
$function$;

revoke all on function public.register_team(uuid,text,text,text,text,text) from public, anon;
grant execute on function public.register_team(uuid,text,text,text,text,text) to authenticated;

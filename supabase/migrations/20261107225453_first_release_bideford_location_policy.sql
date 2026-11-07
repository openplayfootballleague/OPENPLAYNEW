alter table public.locations
  alter column is_active set default false;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'locations_first_release_active_bideford_check'
      and conrelid = 'public.locations'::regclass
  ) then
    alter table public.locations
      add constraint locations_first_release_active_bideford_check
      check (not is_active or lower(btrim(town)) = 'bideford');
  end if;
end;
$$;

create unique index if not exists locations_single_active_first_release_idx
  on public.locations ((true))
  where is_active;

comment on constraint locations_first_release_active_bideford_check on public.locations
  is 'First-release scope: Bideford is the only location permitted to be active. Expand only after explicit product-owner approval.';

comment on index public.locations_single_active_first_release_idx
  is 'First-release scope: at most one active location.';

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
  if v_slug = '' then
    raise exception 'Location name must contain letters or numbers';
  end if;

  insert into public.locations(name, slug, town, region, address, is_active)
  values (btrim(p_name), v_slug, btrim(p_town), btrim(p_region), nullif(btrim(p_address), ''), false)
  returning * into v_location;

  insert into public.audit_log(actor_user_id, action, entity_type, entity_id, after_data)
  values (
    v_actor,
    'location.created',
    'location',
    v_location.id::text,
    jsonb_build_object(
      'name', v_location.name,
      'town', v_location.town,
      'region', v_location.region,
      'is_active', false
    )
  );

  return v_location;
end;
$$;

create or replace function public.admin_set_location_active(
  p_location_id uuid,
  p_is_active boolean,
  p_reason text
)
returns public.locations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_location public.locations;
  v_before jsonb;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required' using errcode = '42501';
  end if;
  if p_location_id is null then
    raise exception 'A location is required';
  end if;
  if p_is_active is null then
    raise exception 'An activation state is required';
  end if;
  if p_reason is null or length(btrim(p_reason)) < 5 or length(btrim(p_reason)) > 500 then
    raise exception 'A reason between 5 and 500 characters is required';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(71408226);

  select *
    into v_location
    from public.locations
   where id = p_location_id
   for update;

  if not found then
    raise exception 'Location not found';
  end if;
  if v_location.is_active = p_is_active then
    raise exception 'Location already has the requested activation state';
  end if;

  if p_is_active then
    if lower(btrim(v_location.town)) <> 'bideford' then
      raise exception 'Only Bideford may be activated for the first release';
    end if;
    if exists (
      select 1
        from public.locations
       where is_active
         and id <> p_location_id
    ) then
      raise exception 'Only one location may be active for the first release';
    end if;
  else
    if exists (
      select 1
        from public.leagues l
        left join public.seasons s on s.league_id = l.id
       where l.location_id = p_location_id
         and (
           l.is_published is true
           or s.is_public is true
           or s.status in ('registration_open', 'active')
         )
    ) then
      raise exception 'Unpublish leagues and close or archive public seasons before deactivating this location';
    end if;
  end if;

  v_before := jsonb_build_object('is_active', v_location.is_active);

  update public.locations
     set is_active = p_is_active,
         updated_at = now()
   where id = p_location_id
   returning * into v_location;

  insert into public.audit_log(
    actor_user_id,
    action,
    entity_type,
    entity_id,
    before_data,
    after_data,
    reason
  )
  values (
    v_actor,
    case when p_is_active then 'location.activated' else 'location.deactivated' end,
    'location',
    v_location.id::text,
    v_before,
    jsonb_build_object(
      'is_active', v_location.is_active,
      'name', v_location.name,
      'town', v_location.town,
      'region', v_location.region
    ),
    btrim(p_reason)
  );

  return v_location;
end;
$$;

revoke all on function public.admin_create_location(text, text, text, text) from public, anon;
grant execute on function public.admin_create_location(text, text, text, text) to authenticated;

revoke all on function public.admin_set_location_active(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_location_active(uuid, boolean, text) to authenticated;

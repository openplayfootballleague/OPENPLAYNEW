-- Location activation is a platform-wide control and is restricted to global administrators.
-- Preserve the first-release Bideford rule, single-active-location lock and
-- safe deactivation checks while applying the global-role boundary.

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
  if v_actor is null or not exists (
    select 1
      from public.user_roles ur
     where ur.user_id = v_actor
       and ur.role in ('admin', 'super_admin')
  ) then
    raise exception 'Global administrator permission required' using errcode = '42501';
  end if;

  if p_location_id is null then
    raise exception 'A location is required' using errcode = '22023';
  end if;
  if p_is_active is null then
    raise exception 'An activation state is required' using errcode = '22023';
  end if;
  if p_reason is null or length(btrim(p_reason)) < 5 or length(btrim(p_reason)) > 500 then
    raise exception 'A reason between 5 and 500 characters is required' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(71408226);

  select *
    into v_location
    from public.locations
   where id = p_location_id
   for update;

  if not found then
    raise exception 'Location not found' using errcode = 'P0002';
  end if;
  if v_location.is_active is not distinct from p_is_active then
    raise exception 'Location already has the requested activation state' using errcode = '22023';
  end if;

  if p_is_active then
    if lower(btrim(v_location.town)) <> 'bideford' then
      raise exception 'Only Bideford may be activated for the first release' using errcode = '42501';
    end if;
    if exists (
      select 1
        from public.locations
       where is_active
         and id <> p_location_id
    ) then
      raise exception 'Only one location may be active for the first release' using errcode = '23505';
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
      raise exception 'Unpublish leagues and close or archive public seasons before deactivating this location' using errcode = '23514';
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

revoke all on function public.admin_set_location_active(uuid,boolean,text) from public, anon;
grant execute on function public.admin_set_location_active(uuid,boolean,text) to authenticated;

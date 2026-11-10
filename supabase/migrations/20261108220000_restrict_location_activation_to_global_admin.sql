-- Location activation is a platform-wide control and is restricted to global administrators.
-- This forward-only migration defines the RPC explicitly so the consolidated
-- migration history does not depend on an older branch-local function body.

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
  v_previous_active boolean;
begin
  if v_actor is null or not exists (
    select 1 from public.user_roles
    where user_id = v_actor and role in ('admin', 'super_admin')
  ) then
    raise exception 'Global administrator permission required' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'Enter a reason of at least 5 characters' using errcode = '22023';
  end if;

  select * into v_location
  from public.locations
  where id = p_location_id
  for update;

  if not found then
    raise exception 'Location not found' using errcode = 'P0002';
  end if;

  v_previous_active := v_location.is_active;
  if v_previous_active is distinct from p_is_active then
    update public.locations
    set is_active = p_is_active
    where id = p_location_id
    returning * into v_location;

    insert into public.audit_log(
      actor_user_id, action, entity_type, entity_id, before_data, after_data, reason
    ) values (
      v_actor,
      case when p_is_active then 'location.activated' else 'location.deactivated' end,
      'location',
      p_location_id::text,
      jsonb_build_object('is_active', v_previous_active),
      jsonb_build_object('is_active', p_is_active),
      btrim(p_reason)
    );
  end if;

  return v_location;
end;
$$;

revoke all on function public.admin_set_location_active(uuid,boolean,text) from public, anon;
grant execute on function public.admin_set_location_active(uuid,boolean,text) to authenticated;

-- Make location administrator assignment changes auditable and allow stale grants to be revoked.
-- Only global administrators may call this RPC. Granting still requires the league_admin
-- role; revocation deliberately does not, so stale assignments can always be cleaned up.

create or replace function public.admin_set_location_assignment(
  p_user_id uuid,
  p_location_id uuid,
  p_assigned boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment_id uuid;
  v_assignment_created_at timestamptz;
begin
  if auth.uid() is null or not exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role in ('admin', 'super_admin')
  ) then
    raise exception 'Global administrator permission required';
  end if;

  if p_assigned and not exists (
    select 1 from public.user_roles
    where user_id = p_user_id and role = 'league_admin'
  ) then
    raise exception 'The selected user must have the league_admin role';
  end if;

  if not exists (select 1 from public.locations where id = p_location_id) then
    raise exception 'Location not found';
  end if;

  if p_assigned then
    insert into public.location_admin_assignments(user_id, location_id, assigned_by)
    values (p_user_id, p_location_id, auth.uid())
    on conflict (user_id, location_id) do nothing
    returning id, created_at into v_assignment_id, v_assignment_created_at;

    if v_assignment_id is not null then
      insert into public.audit_log (
        actor_user_id, action, entity_type, entity_id, before_data, after_data
      ) values (
        auth.uid(),
        'location_admin.assignment_granted',
        'location_admin_assignment',
        v_assignment_id::text,
        null,
        jsonb_build_object(
          'user_id', p_user_id,
          'location_id', p_location_id,
          'assigned_by', auth.uid(),
          'assigned_at', v_assignment_created_at
        )
      );
    end if;
  else
    delete from public.location_admin_assignments
    where user_id = p_user_id and location_id = p_location_id
    returning id into v_assignment_id;

    if v_assignment_id is not null then
      insert into public.audit_log (
        actor_user_id, action, entity_type, entity_id, before_data, after_data
      ) values (
        auth.uid(),
        'location_admin.assignment_revoked',
        'location_admin_assignment',
        v_assignment_id::text,
        jsonb_build_object('user_id', p_user_id, 'location_id', p_location_id),
        null
      );
    end if;
  end if;
end;
$$;

revoke all on function public.admin_set_location_assignment(uuid, uuid, boolean) from public, anon;
grant execute on function public.admin_set_location_assignment(uuid, uuid, boolean) to authenticated;

comment on function public.admin_set_location_assignment(uuid, uuid, boolean) is
  'Global-admin-only location assignment mutation. Grants require league_admin role; revocations remain possible after role removal. Real changes are written to audit_log.';

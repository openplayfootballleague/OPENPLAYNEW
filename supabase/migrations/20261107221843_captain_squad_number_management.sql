-- Captains may assign or clear optional squad numbers for active players in their own team.
create or replace function public.set_team_squad_number(
  p_membership_id uuid,
  p_squad_number smallint default null
)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_membership public.team_memberships;
  v_before smallint;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  select * into v_membership
  from public.team_memberships
  where id=p_membership_id
  for update;
  if not found or v_membership.status <> 'active' then raise exception 'Active team membership not found'; end if;
  if not public.is_active_team_captain(v_membership.season_team_id) then
    raise exception 'Active captain permission required';
  end if;
  if p_squad_number is not null and (p_squad_number < 1 or p_squad_number > 99) then
    raise exception 'Squad numbers must be between 1 and 99';
  end if;
  v_before:=v_membership.squad_number;
  update public.team_memberships set squad_number=p_squad_number
  where id=p_membership_id returning * into v_membership;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data)
  values(v_actor,'team.squad_number.updated','team_membership',p_membership_id::text,
    jsonb_build_object('squad_number',v_before),jsonb_build_object('squad_number',v_membership.squad_number));
  return v_membership;
end;
$$;
revoke all on function public.set_team_squad_number(uuid,smallint) from public,anon;
grant execute on function public.set_team_squad_number(uuid,smallint) to authenticated;

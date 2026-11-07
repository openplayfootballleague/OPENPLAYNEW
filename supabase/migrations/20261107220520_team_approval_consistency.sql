-- Prevent approving a team registration without its submitting captain membership.
create or replace function public.resolve_team_registration(p_season_team_id uuid,p_decision text,p_reason text default null)
returns public.season_teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_season_team public.season_teams;
  v_captain_user_id uuid;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  select * into v_season_team from public.season_teams where id=p_season_team_id and registration_status='pending' for update;
  if not found then raise exception 'No pending team registration exists'; end if;
  select user_id into v_captain_user_id from public.team_memberships
    where season_team_id=p_season_team_id and status='pending' and is_captain=false for update;
  if v_captain_user_id is null then raise exception 'Team registration has no pending applicant to appoint as captain'; end if;
  update public.season_teams set registration_status=p_decision,
    approved_at=case when p_decision='approved' then now() else null end,
    approved_by=case when p_decision='approved' then v_actor else null end
  where id=p_season_team_id returning * into v_season_team;
  if p_decision='approved' then
    update public.team_memberships set status='active',is_captain=true,joined_at=now(),left_at=null
      where season_team_id=p_season_team_id and user_id=v_captain_user_id;
  else
    update public.team_memberships set status='rejected',left_at=now()
      where season_team_id=p_season_team_id and user_id=v_captain_user_id;
  end if;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,after_data)
  values(v_actor,'team.registration.'||p_decision,'season_team',p_season_team_id::text,nullif(trim(p_reason),''),
    jsonb_build_object('registration_status',v_season_team.registration_status,'captain_user_id',v_captain_user_id));
  return v_season_team;
end;
$$;

create or replace function public.admin_remove_player_from_team(p_membership_id uuid,p_reason text)
returns public.team_memberships language plpgsql security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_membership public.team_memberships; v_before jsonb; v_team_name text; v_next_status public.membership_status;
begin
if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
select * into v_membership from public.team_memberships where id=p_membership_id for update;
if not found then raise exception 'Team membership not found'; end if;
if v_membership.status not in ('active','pending') then raise exception 'Only active or pending memberships can be removed'; end if;
if v_membership.is_captain then raise exception 'Appoint a replacement captain before removing this player'; end if;
if v_membership.status='active' and exists(select 1 from public.fixture_team_sheet_players tsp join public.fixture_team_sheets ts on ts.id=tsp.team_sheet_id and ts.is_locked=true join public.fixtures f on f.id=ts.fixture_id where tsp.user_id=v_membership.user_id and ts.season_team_id=v_membership.season_team_id and f.status='scheduled' and f.scheduled_at>now()) then raise exception 'Player is on a locked upcoming team sheet. Amend the team sheet before removing them'; end if;
select name into v_team_name from public.season_teams where id=v_membership.season_team_id;
v_before:=jsonb_build_object('status',v_membership.status,'is_captain',v_membership.is_captain,'squad_number',v_membership.squad_number,'season_team_id',v_membership.season_team_id);
v_next_status:=case when v_membership.status='active' then 'left'::public.membership_status else 'rejected'::public.membership_status end;
update public.team_memberships set status=v_next_status,left_at=case when v_next_status='left'::public.membership_status then now() else left_at end,squad_number=null,updated_at=now() where id=p_membership_id returning * into v_membership;
insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data) values(v_actor,'team.membership.admin_removed','team_membership',p_membership_id::text,btrim(p_reason),v_before,jsonb_build_object('status',v_membership.status,'season_team_id',v_membership.season_team_id,'user_id',v_membership.user_id,'reason',btrim(p_reason)));
if v_next_status='left'::public.membership_status then perform public.enqueue_notification_event(v_membership.user_id,'team.membership_removed',jsonb_build_object('team_name',v_team_name,'reason',btrim(p_reason),'changed_at',now())); end if;
return v_membership;
end; $$;
revoke all on function public.admin_remove_player_from_team(uuid,text) from public,anon;
grant execute on function public.admin_remove_player_from_team(uuid,text) to authenticated;
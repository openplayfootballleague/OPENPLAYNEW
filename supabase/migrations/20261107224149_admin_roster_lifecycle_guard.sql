create or replace function public.admin_create_season_team(p_season_id uuid,p_team_name text,p_primary_colour text default null,p_secondary_colour text default null)
returns public.season_teams language plpgsql security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_season public.seasons; v_team_id uuid; v_slug text; v_season_team public.season_teams;
begin
if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
if p_team_name is null or length(btrim(p_team_name))<1 or length(btrim(p_team_name))>80 then raise exception 'Team name must be between 1 and 80 characters'; end if;
select * into v_season from public.seasons where id=p_season_id;
if not found then raise exception 'Choose an existing season'; end if;
if v_season.status in ('completed','archived') then raise exception 'Teams cannot be added to a completed or archived season'; end if;
v_slug:=trim(both '-' from regexp_replace(lower(btrim(p_team_name)),'[^a-z0-9]+','-','g'));
if v_slug='' then raise exception 'Team name must contain letters or numbers'; end if;
if exists(select 1 from public.season_teams where season_id=p_season_id and slug=v_slug) then raise exception 'A team with that name already exists in this season'; end if;
insert into public.teams(created_by) values(v_actor) returning id into v_team_id;
insert into public.season_teams(team_id,season_id,name,slug,primary_colour,secondary_colour,registration_status,approved_at,approved_by)
values(v_team_id,p_season_id,btrim(p_team_name),v_slug,nullif(btrim(p_primary_colour),''),nullif(btrim(p_secondary_colour),''),'approved',now(),v_actor) returning * into v_season_team;
insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data) values(v_actor,'team.admin_created','season_team',v_season_team.id::text,jsonb_build_object('season_id',p_season_id,'team_name',v_season_team.name,'registration_status','approved'));
return v_season_team; end; $$;
create or replace function public.admin_add_player_to_team(p_season_team_id uuid,p_user_id uuid,p_make_captain boolean default false)
returns public.team_memberships language plpgsql security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_team public.season_teams; v_season public.seasons; v_player public.players; v_existing_captain uuid; v_membership public.team_memberships;
begin
if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
select * into v_team from public.season_teams where id=p_season_team_id;
if not found then raise exception 'Choose an existing team'; end if;
if v_team.registration_status<>'approved' then raise exception 'Only approved teams can accept players'; end if;
select * into v_season from public.seasons where id=v_team.season_id;
if v_season.status in ('completed','archived') then raise exception 'Players cannot be added to a completed or archived season'; end if;
select * into v_player from public.players where user_id=p_user_id;
if not found or v_player.registration_status<>'registered' or v_player.is_banned then raise exception 'Choose a registered, eligible player'; end if;
if exists(select 1 from public.team_memberships tm join public.season_teams other_team on other_team.id=tm.season_team_id where tm.user_id=p_user_id and tm.status='active' and other_team.season_id=v_team.season_id and other_team.id<>p_season_team_id) then raise exception 'This player is already active in another team in this season. Use the transfer workflow.'; end if;
if p_make_captain then
select tm.user_id into v_existing_captain from public.team_memberships tm where tm.season_team_id=p_season_team_id and tm.status='active' and tm.is_captain=true limit 1;
if v_existing_captain is not null and v_existing_captain<>p_user_id then raise exception 'This team already has an active captain. Complete a captain handover first.'; end if;
end if;
insert into public.team_memberships as existing(season_team_id,user_id,status,is_captain,joined_at,left_at)
values(p_season_team_id,p_user_id,'active',coalesce(p_make_captain,false),now(),null)
on conflict(season_team_id,user_id) do update set status='active',is_captain=(existing.is_captain or excluded.is_captain),joined_at=coalesce(existing.joined_at,now()),left_at=null
returning * into v_membership;
insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data) values(v_actor,case when v_membership.is_captain then 'team.player_added_as_captain' else 'team.player_added_by_admin' end,'team_membership',v_membership.id::text,jsonb_build_object('season_team_id',p_season_team_id,'user_id',p_user_id,'is_captain',v_membership.is_captain));
return v_membership; end; $$;
revoke all on function public.admin_create_season_team(uuid,text,text,text) from public,anon;
grant execute on function public.admin_create_season_team(uuid,text,text,text) to authenticated;
revoke all on function public.admin_add_player_to_team(uuid,uuid,boolean) from public,anon;
grant execute on function public.admin_add_player_to_team(uuid,uuid,boolean) to authenticated;
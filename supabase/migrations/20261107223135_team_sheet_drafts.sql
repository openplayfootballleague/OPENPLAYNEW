alter table public.fixture_team_sheets alter column submitted_at drop not null, alter column submitted_at drop default, add column draft_saved_at timestamptz;
create or replace function public.save_team_sheet_draft(p_fixture_id uuid,p_season_team_id uuid,p_starters uuid[],p_substitutes uuid[] default '{}'::uuid[],p_goalkeeper_membership_id uuid default null)
returns public.fixture_team_sheets language plpgsql security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_fixture public.fixtures; v_format public.competition_format; v_sheet public.fixture_team_sheets; v_max_starters integer; v_max_substitutes integer; v_all_memberships uuid[];
begin
if v_actor is null then raise exception 'Authentication required'; end if;
if not public.is_active_team_captain(p_season_team_id) then raise exception 'Active team captain permission required'; end if;
select * into v_fixture from public.fixtures where id=p_fixture_id for update;
if not found then raise exception 'Fixture not found'; end if;
if v_fixture.status<>'scheduled' then raise exception 'Only scheduled fixtures can have team-sheet drafts'; end if;
if p_season_team_id not in (v_fixture.home_team_id,v_fixture.away_team_id) then raise exception 'This team is not playing in the selected fixture'; end if;
select l.format into v_format from public.seasons s join public.leagues l on l.id=s.league_id where s.id=v_fixture.season_id;
v_max_starters:=case when v_format='six_a_side' then 6 else 7 end;
v_max_substitutes:=case when v_format='six_a_side' then 3 else 4 end;
if coalesce(cardinality(p_starters),0)>v_max_starters then raise exception 'Select no more than % starting players in a draft',v_max_starters; end if;
if coalesce(cardinality(p_substitutes),0)>v_max_substitutes then raise exception 'Select no more than % substitutes in a draft',v_max_substitutes; end if;
if p_goalkeeper_membership_id is not null and not (p_goalkeeper_membership_id=any(coalesce(p_starters,'{}'::uuid[]))) then raise exception 'The goalkeeper must be one of the starting players'; end if;
v_all_memberships:=coalesce(p_starters,'{}'::uuid[])||coalesce(p_substitutes,'{}'::uuid[]);
if (select count(distinct x) from unnest(v_all_memberships) x)<>cardinality(v_all_memberships) then raise exception 'A player can only appear once on a team-sheet draft'; end if;
if exists(select 1 from unnest(v_all_memberships) x where not exists(select 1 from public.team_memberships tm join public.players p on p.user_id=tm.user_id where tm.id=x and tm.season_team_id=p_season_team_id and tm.status='active' and p.registration_status='registered' and p.is_banned=false)) then raise exception 'Every selected player must have an active, approved membership in this team'; end if;
select * into v_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=p_season_team_id for update;
if found and v_sheet.is_locked then raise exception 'This team sheet has already been submitted and is locked'; end if;
if v_sheet.id is null then
insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,submitted_at,is_locked,draft_saved_at) values(p_fixture_id,p_season_team_id,v_actor,null,false,now()) returning * into v_sheet;
else
update public.fixture_team_sheets set submitted_by=v_actor,submitted_at=null,is_locked=false,draft_saved_at=now() where id=v_sheet.id returning * into v_sheet;
delete from public.fixture_team_sheet_players where team_sheet_id=v_sheet.id;
end if;
insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,squad_number_snapshot,is_goalkeeper) select v_sheet.id,tm.user_id,'starter',tm.squad_number,tm.id=p_goalkeeper_membership_id from public.team_memberships tm where tm.id=any(coalesce(p_starters,'{}'::uuid[])) and tm.season_team_id=p_season_team_id and tm.status='active';
insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,squad_number_snapshot,is_goalkeeper) select v_sheet.id,tm.user_id,'substitute',tm.squad_number,false from public.team_memberships tm where tm.id=any(coalesce(p_substitutes,'{}'::uuid[])) and tm.season_team_id=p_season_team_id and tm.status='active';
insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data) values(v_actor,'fixture.team_sheet.draft_saved','fixture_team_sheet',v_sheet.id::text,jsonb_build_object('fixture_id',p_fixture_id,'season_team_id',p_season_team_id,'starters',cardinality(p_starters),'substitutes',cardinality(p_substitutes),'goalkeeper_membership_id',p_goalkeeper_membership_id));
return v_sheet;
end; $$;
create or replace function public.get_captain_team_sheet(p_fixture_id uuid)
returns table(season_team_id uuid,starters uuid[],substitutes uuid[],goalkeeper_membership_id uuid,is_locked boolean,submitted_at timestamptz,draft_saved_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid();
begin
if v_actor is null then raise exception 'Authentication required'; end if;
return query
select s.season_team_id,coalesce(array_agg(tm.id) filter(where tsp.role='starter'),'{}'::uuid[]),coalesce(array_agg(tm.id) filter(where tsp.role='substitute'),'{}'::uuid[]),(array_agg(tm.id) filter(where tsp.is_goalkeeper))[1],s.is_locked,s.submitted_at,s.draft_saved_at
from public.fixture_team_sheets s
join public.team_memberships captain on captain.season_team_id=s.season_team_id and captain.user_id=v_actor and captain.is_captain=true and captain.status='active'
left join public.fixture_team_sheet_players tsp on tsp.team_sheet_id=s.id
left join public.team_memberships tm on tm.user_id=tsp.user_id and tm.season_team_id=s.season_team_id and tm.status='active'
where s.fixture_id=p_fixture_id group by s.id;
end; $$;
create or replace function public.submit_team_sheet(p_fixture_id uuid,p_season_team_id uuid,p_starters uuid[],p_substitutes uuid[] default '{}'::uuid[],p_goalkeeper_membership_id uuid default null)
returns public.fixture_team_sheets language plpgsql security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_fixture public.fixtures; v_format public.competition_format; v_sheet public.fixture_team_sheets; v_expected_starters integer; v_max_substitutes integer; v_all_memberships uuid[];
begin
if v_actor is null then raise exception 'Authentication required'; end if;
if not public.is_active_team_captain(p_season_team_id) then raise exception 'Active team captain permission required'; end if;
select * into v_fixture from public.fixtures where id=p_fixture_id for update;
if not found then raise exception 'Fixture not found'; end if;
if v_fixture.status<>'scheduled' then raise exception 'Team sheets can only be submitted for scheduled fixtures'; end if;
if p_season_team_id not in (v_fixture.home_team_id,v_fixture.away_team_id) then raise exception 'This team is not playing in the selected fixture'; end if;
select l.format into v_format from public.seasons s join public.leagues l on l.id=s.league_id where s.id=v_fixture.season_id;
v_expected_starters:=case when v_format='six_a_side' then 6 else 7 end; v_max_substitutes:=case when v_format='six_a_side' then 3 else 4 end;
if coalesce(cardinality(p_starters),0)<>v_expected_starters then raise exception 'Select exactly % starting players',v_expected_starters; end if;
if coalesce(cardinality(p_substitutes),0)>v_max_substitutes then raise exception 'Select no more than % substitutes',v_max_substitutes; end if;
if p_goalkeeper_membership_id is null or not (p_goalkeeper_membership_id=any(coalesce(p_starters,'{}'::uuid[]))) then raise exception 'Select one goalkeeper from your starting players'; end if;
v_all_memberships:=coalesce(p_starters,'{}'::uuid[])||coalesce(p_substitutes,'{}'::uuid[]);
if (select count(distinct x) from unnest(v_all_memberships) x)<>cardinality(v_all_memberships) then raise exception 'A player can only appear once on a team sheet'; end if;
if exists(select 1 from unnest(v_all_memberships) x where not exists(select 1 from public.team_memberships tm join public.players p on p.user_id=tm.user_id where tm.id=x and tm.season_team_id=p_season_team_id and tm.status='active' and p.registration_status='registered' and p.is_banned=false)) then raise exception 'Every selected player must have an active, approved membership in this team'; end if;
select * into v_sheet from public.fixture_team_sheets where fixture_id=p_fixture_id and season_team_id=p_season_team_id for update;
if found and v_sheet.is_locked then raise exception 'This team sheet is locked'; end if;
if v_sheet.id is null then insert into public.fixture_team_sheets(fixture_id,season_team_id,submitted_by,submitted_at,is_locked,draft_saved_at) values(p_fixture_id,p_season_team_id,v_actor,now(),true,null) returning * into v_sheet;
else update public.fixture_team_sheets set submitted_by=v_actor,submitted_at=now(),is_locked=true,draft_saved_at=null where id=v_sheet.id returning * into v_sheet; delete from public.fixture_team_sheet_players where team_sheet_id=v_sheet.id; end if;
insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,squad_number_snapshot,is_goalkeeper) select v_sheet.id,tm.user_id,'starter',tm.squad_number,tm.id=p_goalkeeper_membership_id from public.team_memberships tm where tm.id=any(coalesce(p_starters,'{}'::uuid[])) and tm.season_team_id=p_season_team_id and tm.status='active';
insert into public.fixture_team_sheet_players(team_sheet_id,user_id,role,squad_number_snapshot,is_goalkeeper) select v_sheet.id,tm.user_id,'substitute',tm.squad_number,false from public.team_memberships tm where tm.id=any(coalesce(p_substitutes,'{}'::uuid[])) and tm.season_team_id=p_season_team_id and tm.status='active';
insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data) values(v_actor,'fixture.team_sheet.submitted','fixture_team_sheet',v_sheet.id::text,jsonb_build_object('fixture_id',p_fixture_id,'season_team_id',p_season_team_id,'starters',cardinality(p_starters),'substitutes',cardinality(p_substitutes),'goalkeeper_membership_id',p_goalkeeper_membership_id,'is_locked',true));
return v_sheet;
end; $$;
revoke all on function public.save_team_sheet_draft(uuid,uuid,uuid[],uuid[],uuid) from public,anon;
grant execute on function public.save_team_sheet_draft(uuid,uuid,uuid[],uuid[],uuid) to authenticated;
revoke all on function public.get_captain_team_sheet(uuid) from public,anon;
grant execute on function public.get_captain_team_sheet(uuid) to authenticated;
revoke all on function public.submit_team_sheet(uuid,uuid,uuid[],uuid[],uuid) from public,anon;
grant execute on function public.submit_team_sheet(uuid,uuid,uuid[],uuid[],uuid) to authenticated;
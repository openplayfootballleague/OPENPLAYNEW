create or replace function public.save_admin_context_preference(p_location_id uuid default null,p_league_id uuid default null,p_season_id uuid default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid();v_league_location uuid;v_season_league uuid;
begin
 if v_user is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
 if p_season_id is not null then
  select s.league_id into v_season_league from public.seasons s where s.id=p_season_id;
  if v_season_league is null then raise exception 'Selected season was not found'; end if;
  if p_league_id is null then p_league_id:=v_season_league; end if;
  if p_league_id<>v_season_league then raise exception 'Selected season does not belong to selected league'; end if;
 end if;
 if p_league_id is not null then
  select l.location_id into v_league_location from public.leagues l where l.id=p_league_id;
  if v_league_location is null then raise exception 'Selected league was not found'; end if;
  if p_location_id is null then p_location_id:=v_league_location; end if;
  if p_location_id<>v_league_location then raise exception 'Selected league does not belong to selected location'; end if;
 end if;
 if p_location_id is not null and not public.can_administer_location(p_location_id) then raise exception 'You are not assigned to this location'; end if;
 if p_location_id is null and exists(select 1 from public.user_roles where user_id=v_user and role='league_admin') then raise exception 'Location administrators must select an assigned location'; end if;
 insert into public.admin_context_preferences(user_id,location_id,league_id,season_id,updated_at) values(v_user,p_location_id,p_league_id,p_season_id,now())
 on conflict(user_id) do update set location_id=excluded.location_id,league_id=excluded.league_id,season_id=excluded.season_id,updated_at=now();
 return jsonb_build_object('location_id',p_location_id,'league_id',p_league_id,'season_id',p_season_id);
end;
$$;

create or replace function public.get_admin_competition_setup()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid();
begin
 if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
 if exists(select 1 from public.user_roles where user_id=v_actor and role='league_admin') and not exists(select 1 from public.location_admin_assignments where user_id=v_actor) then raise exception 'No locations have been assigned to this administrator'; end if;
 return jsonb_build_object(
 'locations',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'town',l.town,'region',l.region,'address',l.address,'is_active',l.is_active) order by l.name) from public.locations l where public.can_administer_location(l.id)),'[]'::jsonb),
 'leagues',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'location_id',l.location_id,'location_name',loc.name,'name',l.name,'format',l.format,'description',l.description,'is_published',l.is_published) order by loc.name,l.name) from public.leagues l join public.locations loc on loc.id=l.location_id where public.can_administer_location(l.location_id)),'[]'::jsonb),
 'seasons',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'league_id',s.league_id,'league_name',l.name,'location_name',loc.name,'name',s.name,'season_number',s.season_number,'starts_on',s.starts_on,'ends_on',s.ends_on,'registration_opens_at',s.registration_opens_at,'registration_closes_at',s.registration_closes_at,'status',s.status,'is_public',s.is_public) order by loc.name,l.name,s.created_at desc) from public.seasons s join public.leagues l on l.id=s.league_id join public.locations loc on loc.id=l.location_id where public.can_administer_location(l.location_id)),'[]'::jsonb),
 'season_teams',coalesce((select jsonb_agg(jsonb_build_object('id',st.id,'season_id',st.season_id,'season_name',s.name,'league_name',l.name,'location_name',loc.name,'name',st.name,'registration_status',st.registration_status,'primary_colour',st.primary_colour,'secondary_colour',st.secondary_colour,'member_count',(select count(*) from public.team_memberships tm where tm.season_team_id=st.id and tm.status='active'),'captain_name',(select p.full_name from public.team_memberships tm join public.players p on p.user_id=tm.user_id where tm.season_team_id=st.id and tm.status='active' and tm.is_captain limit 1)) order by loc.name,s.name,st.name) from public.season_teams st join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id join public.locations loc on loc.id=l.location_id where public.can_administer_location(l.location_id)),'[]'::jsonb),
 'registered_players',coalesce((select jsonb_agg(jsonb_build_object('user_id',p.user_id,'full_name',p.full_name,'email',p.email) order by p.full_name) from public.players p where p.registration_status='registered' and p.is_banned=false and exists(select 1 from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.user_id=p.user_id and tm.status='active' and public.can_administer_location(l.location_id))),'[]'::jsonb),
 'fixtures',coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'season_id',f.season_id,'season_name',s.name,'gameweek',f.gameweek,'fixture_number',f.fixture_number,'home_team_id',f.home_team_id,'away_team_id',f.away_team_id,'home_team_name',ht.name,'away_team_name',at.name,'venue_id',f.venue_id,'venue_name',venue.name,'scheduled_at',f.scheduled_at,'status',f.status,'home_score',r.home_score,'away_score',r.away_score,'notes',f.notes) order by f.scheduled_at desc nulls last,f.gameweek desc,f.fixture_number) from public.fixtures f join public.seasons s on s.id=f.season_id join public.leagues l on l.id=s.league_id join public.season_teams ht on ht.id=f.home_team_id join public.season_teams at on at.id=f.away_team_id left join public.locations venue on venue.id=f.venue_id left join public.fixture_results r on r.fixture_id=f.id where public.can_administer_location(l.location_id)),'[]'::jsonb)
 );
end;
$$;

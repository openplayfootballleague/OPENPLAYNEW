create or replace function public.admin_set_league_published(p_league_id uuid,p_is_published boolean)
returns public.leagues language plpgsql security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_league public.leagues; v_before boolean;
begin
if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
select * into v_league from public.leagues where id=p_league_id for update;
if not found then raise exception 'League not found'; end if;
v_before:=v_league.is_published;
if p_is_published then
if not exists(select 1 from public.locations where id=v_league.location_id and is_active=true) then raise exception 'The league location must be active before publication'; end if;
elsif exists(select 1 from public.seasons s where s.league_id=p_league_id and s.status in ('registration_open','active')) then
raise exception 'Close registration or complete active seasons before unpublishing this league';
end if;
update public.leagues set is_published=p_is_published,updated_at=now() where id=p_league_id returning * into v_league;
insert into public.audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data) values(v_actor,'league.publication_changed','league',p_league_id::text,jsonb_build_object('is_published',v_before),jsonb_build_object('is_published',p_is_published));
return v_league; end; $$;
create or replace function public.admin_transition_season(p_season_id uuid,p_next_status public.season_status)
returns public.seasons language plpgsql security definer set search_path = '' as $$
declare v_actor uuid:=auth.uid(); v_season public.seasons; v_league public.leagues; v_location public.locations; v_previous public.season_status;
begin
if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
select * into v_season from public.seasons where id=p_season_id for update;
if not found then raise exception 'Season not found'; end if;
v_previous:=v_season.status;
if not ((v_previous='draft' and p_next_status='registration_open') or (v_previous='registration_open' and p_next_status='active') or (v_previous='active' and p_next_status='completed') or (v_previous='completed' and p_next_status='archived')) then raise exception 'Invalid season transition from % to %',v_previous,p_next_status; end if;
select * into v_league from public.leagues where id=v_season.league_id;
select * into v_location from public.locations where id=v_league.location_id;
if p_next_status in ('registration_open','active') and (not v_league.is_published or not v_location.is_active) then raise exception 'Publish the league and keep its location active before opening or activating a season'; end if;
if p_next_status='registration_open' then
update public.seasons set status='registration_open',is_public=true,registration_opens_at=coalesce(registration_opens_at,now()),updated_at=now() where id=p_season_id returning * into v_season;
elsif p_next_status='active' then
update public.seasons set status='active',is_public=true,registration_closes_at=coalesce(registration_closes_at,now()),updated_at=now() where id=p_season_id returning * into v_season;
else
update public.seasons set status=p_next_status,updated_at=now() where id=p_season_id returning * into v_season;
end if;
insert into public.audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data) values(v_actor,'season.status_changed','season',p_season_id::text,jsonb_build_object('status',v_previous),jsonb_build_object('status',v_season.status,'is_public',v_season.is_public));
return v_season; end; $$;
revoke all on function public.admin_set_league_published(uuid,boolean) from public,anon;
grant execute on function public.admin_set_league_published(uuid,boolean) to authenticated;
revoke all on function public.admin_transition_season(uuid,public.season_status) from public,anon;
grant execute on function public.admin_transition_season(uuid,public.season_status) to authenticated;
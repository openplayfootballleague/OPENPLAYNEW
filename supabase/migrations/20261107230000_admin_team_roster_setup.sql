-- Admin-managed teams for an empty-database/manual-onboarding launch.
-- Only already registered, eligible player accounts can be added to a squad.
create or replace function public.get_admin_competition_setup()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_actor uuid := auth.uid();
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  return jsonb_build_object(
    'locations', coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'town',l.town,'region',l.region,'address',l.address,'is_active',l.is_active) order by l.name) from public.locations l),'[]'::jsonb),
    'leagues', coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'location_id',l.location_id,'location_name',loc.name,'name',l.name,'format',l.format,'description',l.description,'is_published',l.is_published) order by loc.name,l.name) from public.leagues l join public.locations loc on loc.id=l.location_id),'[]'::jsonb),
    'seasons', coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'league_id',s.league_id,'league_name',l.name,'location_name',loc.name,'name',s.name,'season_number',s.season_number,'starts_on',s.starts_on,'ends_on',s.ends_on,'registration_opens_at',s.registration_opens_at,'registration_closes_at',s.registration_closes_at,'status',s.status,'is_public',s.is_public) order by loc.name,l.name,s.created_at desc) from public.seasons s join public.leagues l on l.id=s.league_id join public.locations loc on loc.id=l.location_id),'[]'::jsonb),
    'season_teams', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',st.id,'season_id',st.season_id,'season_name',s.name,'league_name',l.name,
        'location_name',loc.name,'name',st.name,'registration_status',st.registration_status,
        'primary_colour',st.primary_colour,'secondary_colour',st.secondary_colour,
        'member_count',(select count(*) from public.team_memberships tm where tm.season_team_id=st.id and tm.status='active'),
        'captain_name',(select p.full_name from public.team_memberships tm join public.players p on p.user_id=tm.user_id where tm.season_team_id=st.id and tm.status='active' and tm.is_captain limit 1)
      ) order by loc.name,s.name,st.name)
      from public.season_teams st
      join public.seasons s on s.id=st.season_id
      join public.leagues l on l.id=s.league_id
      join public.locations loc on loc.id=l.location_id
    ),'[]'::jsonb),
    'registered_players', coalesce((
      select jsonb_agg(jsonb_build_object('user_id',p.user_id,'full_name',p.full_name,'email',p.email) order by p.full_name)
      from public.players p
      where p.registration_status='registered' and p.is_banned=false
    ),'[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_create_season_team(
  p_season_id uuid,
  p_team_name text,
  p_primary_colour text default null,
  p_secondary_colour text default null
)
returns public.season_teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_season public.seasons;
  v_team_id uuid;
  v_slug text;
  v_season_team public.season_teams;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  if p_team_name is null or length(btrim(p_team_name)) < 1 or length(btrim(p_team_name)) > 80 then
    raise exception 'Team name must be between 1 and 80 characters';
  end if;
  select * into v_season from public.seasons where id=p_season_id;
  if not found then raise exception 'Choose an existing season'; end if;
  v_slug := trim(both '-' from regexp_replace(lower(btrim(p_team_name)),'[^a-z0-9]+','-','g'));
  if v_slug = '' then raise exception 'Team name must contain letters or numbers'; end if;
  if exists(select 1 from public.season_teams where season_id=p_season_id and slug=v_slug) then
    raise exception 'A team with that name already exists in this season';
  end if;

  insert into public.teams(created_by) values(v_actor) returning id into v_team_id;
  insert into public.season_teams(
    team_id,season_id,name,slug,primary_colour,secondary_colour,
    registration_status,approved_at,approved_by
  )
  values(
    v_team_id,p_season_id,btrim(p_team_name),v_slug,
    nullif(btrim(p_primary_colour),''),nullif(btrim(p_secondary_colour),''),
    'approved',now(),v_actor
  )
  returning * into v_season_team;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'team.admin_created','season_team',v_season_team.id::text,
    jsonb_build_object('season_id',p_season_id,'team_name',v_season_team.name,'registration_status','approved'));
  return v_season_team;
end;
$$;

create or replace function public.admin_add_player_to_team(
  p_season_team_id uuid,
  p_user_id uuid,
  p_make_captain boolean default false
)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_team public.season_teams;
  v_player public.players;
  v_existing_captain uuid;
  v_membership public.team_memberships;
begin
  if v_actor is null or not public.has_platform_role() then
    raise exception 'Administrator permission required';
  end if;
  select * into v_team from public.season_teams where id=p_season_team_id;
  if not found then raise exception 'Choose an existing team'; end if;
  if v_team.registration_status <> 'approved' then
    raise exception 'Only approved teams can accept players';
  end if;
  select * into v_player from public.players where user_id=p_user_id;
  if not found or v_player.registration_status <> 'registered' or v_player.is_banned then
    raise exception 'Choose a registered, eligible player';
  end if;

  if exists(
    select 1 from public.team_memberships tm
    join public.season_teams other_team on other_team.id=tm.season_team_id
    where tm.user_id=p_user_id and tm.status='active'
      and other_team.season_id=v_team.season_id
      and other_team.id<>p_season_team_id
  ) then
    raise exception 'This player is already active in another team in this season. Use the transfer workflow.';
  end if;

  if p_make_captain then
    select tm.user_id into v_existing_captain
    from public.team_memberships tm
    where tm.season_team_id=p_season_team_id and tm.status='active' and tm.is_captain=true
    limit 1;
    if v_existing_captain is not null and v_existing_captain<>p_user_id then
      raise exception 'This team already has an active captain. Complete a captain handover first.';
    end if;
  end if;

  insert into public.team_memberships(season_team_id,user_id,status,is_captain,joined_at,left_at)
  values(p_season_team_id,p_user_id,'active',coalesce(p_make_captain,false),now(),null)
  on conflict(season_team_id,user_id) do update set
    status='active',
    is_captain=(public.team_memberships.is_captain or excluded.is_captain),
    joined_at=coalesce(public.team_memberships.joined_at,now()),
    left_at=null
  returning * into v_membership;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,case when v_membership.is_captain then 'team.player_added_as_captain' else 'team.player_added_by_admin' end,
    'team_membership',v_membership.id::text,
    jsonb_build_object('season_team_id',p_season_team_id,'user_id',p_user_id,'is_captain',v_membership.is_captain));
  return v_membership;
end;
$$;

revoke all on function public.get_admin_competition_setup() from public,anon;
grant execute on function public.get_admin_competition_setup() to authenticated;
revoke all on function public.admin_create_season_team(uuid,text,text,text) from public,anon;
grant execute on function public.admin_create_season_team(uuid,text,text,text) to authenticated;
revoke all on function public.admin_add_player_to_team(uuid,uuid,boolean) from public,anon;
grant execute on function public.admin_add_player_to_team(uuid,uuid,boolean) to authenticated;

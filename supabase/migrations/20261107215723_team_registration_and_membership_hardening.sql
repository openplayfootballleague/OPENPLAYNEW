-- Harden account eligibility and complete team registration approval.

create or replace function public.register_player(
  p_full_name text,
  p_phone text,
  p_email text,
  p_date_of_birth date
)
returns public.players
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_auth_email text;
  v_email_confirmed_at timestamptz;
  v_name_match boolean;
  v_phone_match boolean;
  v_email_match boolean;
  v_match_count integer;
  v_player public.players;
  v_matched_ids uuid[];
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if nullif(trim(p_full_name), '') is null or nullif(trim(p_phone), '') is null
     or nullif(trim(p_email), '') is null or p_date_of_birth is null then
    raise exception 'Full name, phone, email and date of birth are required';
  end if;
  if p_date_of_birth > current_date or p_date_of_birth < date '1900-01-01' then
    raise exception 'Date of birth is invalid';
  end if;
  select lower(trim(u.email)), u.email_confirmed_at
    into v_auth_email, v_email_confirmed_at
    from auth.users u where u.id = v_user_id;
  if v_auth_email is null or lower(trim(p_email)) <> v_auth_email then
    raise exception 'Registration email must match the signed-in account email';
  end if;
  if v_email_confirmed_at is null then raise exception 'Verify your email address before registering as a player'; end if;
  if exists (select 1 from public.players p where p.user_id = v_user_id) then
    raise exception 'Player registration has already been submitted';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('openplay-player-registration', 0));
  select
    exists(select 1 from public.players p where lower(trim(p.full_name)) = lower(trim(p_full_name))),
    exists(select 1 from public.players p where regexp_replace(p.phone, '[^0-9]', '', 'g') = regexp_replace(p_phone, '[^0-9]', '', 'g')),
    exists(select 1 from public.players p where lower(trim(p.email)) = lower(trim(p_email)))
  into v_name_match, v_phone_match, v_email_match;
  v_match_count := (case when v_name_match then 1 else 0 end)
    + (case when v_phone_match then 1 else 0 end)
    + (case when v_email_match then 1 else 0 end);
  select coalesce(array_agg(distinct p.id), '{}'::uuid[]) into v_matched_ids
  from public.players p
  where (v_name_match and lower(trim(p.full_name)) = lower(trim(p_full_name)))
     or (v_phone_match and regexp_replace(p.phone, '[^0-9]', '', 'g') = regexp_replace(p_phone, '[^0-9]', '', 'g'))
     or (v_email_match and lower(trim(p.email)) = lower(trim(p_email)));
  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status)
  values(v_user_id,trim(p_full_name),trim(p_phone),lower(trim(p_email)),p_date_of_birth,
    case when v_match_count >= 2 then 'pending_review'::public.player_registration_status
         else 'registered'::public.player_registration_status end)
  returning * into v_player;
  if v_match_count >= 2 then
    insert into public.player_registration_reviews(player_id,name_matched,phone_matched,email_matched,matched_player_ids)
    values(v_player.id,v_name_match,v_phone_match,v_email_match,v_matched_ids);
  end if;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_user_id,case when v_match_count >= 2 then 'player.registration.flagged' else 'player.registration.approved' end,
    'player',v_player.id::text,jsonb_build_object('registration_status',v_player.registration_status,
    'name_matched',v_name_match,'phone_matched',v_phone_match,'email_matched',v_email_match));
  return v_player;
end;
$$;

create or replace function public.request_team_membership(p_season_team_id uuid)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_player public.players;
  v_membership public.team_memberships;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  select * into v_player from public.players where user_id = v_user_id;
  if v_player.id is null or v_player.registration_status <> 'registered' or v_player.is_banned then
    raise exception 'An approved, eligible player registration is required before joining a team';
  end if;
  if not exists(select 1 from public.season_teams st join public.seasons s on s.id=st.season_id
    where st.id=p_season_team_id and st.registration_status='approved' and s.status='registration_open') then
    raise exception 'This team is not currently accepting player requests';
  end if;
  insert into public.team_memberships(season_team_id,user_id,status)
  values(p_season_team_id,v_user_id,'pending')
  on conflict(season_team_id,user_id) do update
    set status='pending',left_at=null,joined_at=null,is_captain=false,updated_at=now()
    where public.team_memberships.status in ('left','rejected')
  returning * into v_membership;
  if v_membership.id is null then raise exception 'A membership or request already exists for this team'; end if;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id)
  values(v_user_id,'team.membership.requested','team_membership',v_membership.id::text);
  return v_membership;
end;
$$;

create or replace function public.resolve_team_membership_request(p_membership_id uuid,p_decision text)
returns public.team_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_membership public.team_memberships;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  select * into v_membership from public.team_memberships where id=p_membership_id and status='pending' for update;
  if not found then raise exception 'No pending team request exists'; end if;
  if not public.has_platform_role() and not public.is_active_team_captain(v_membership.season_team_id) then
    raise exception 'Captain permission required';
  end if;
  update public.team_memberships set
    status=case when p_decision='approved' then 'active'::public.membership_status else 'rejected'::public.membership_status end,
    joined_at=case when p_decision='approved' then now() else joined_at end,
    left_at=case when p_decision='rejected' then now() else null end
  where id=p_membership_id returning * into v_membership;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_actor,'team.membership.'||p_decision,'team_membership',p_membership_id::text,
    jsonb_build_object('status',v_membership.status));
  return v_membership;
end;
$$;

-- Team applications create a season-specific team profile in pending status.
-- The submitting player only becomes captain after an administrator approves it.
create or replace function public.register_team(
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
  v_user_id uuid := auth.uid();
  v_player public.players;
  v_season public.seasons;
  v_team_id uuid;
  v_slug text;
  v_season_team public.season_teams;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if nullif(trim(p_team_name),'') is null or char_length(trim(p_team_name)) > 80 then
    raise exception 'Team name must be between 1 and 80 characters';
  end if;
  select * into v_player from public.players where user_id=v_user_id;
  if v_player.id is null or v_player.registration_status <> 'registered' or v_player.is_banned then
    raise exception 'An approved, eligible player registration is required to register a team';
  end if;
  select * into v_season from public.seasons where id=p_season_id and status='registration_open' for share;
  if v_season.id is null then raise exception 'This season is not accepting team registrations'; end if;
  v_slug := trim(both '-' from regexp_replace(lower(trim(p_team_name)),'[^a-z0-9]+','-','g'));
  if v_slug = '' then raise exception 'Team name must contain letters or numbers'; end if;
  if exists(select 1 from public.season_teams where season_id=p_season_id and slug=v_slug) then
    raise exception 'A team with that name is already registered for this season';
  end if;
  insert into public.teams(created_by) values(v_user_id) returning id into v_team_id;
  insert into public.season_teams(team_id,season_id,name,slug,primary_colour,secondary_colour,registration_status)
  values(v_team_id,p_season_id,trim(p_team_name),v_slug,nullif(trim(p_primary_colour),''),nullif(trim(p_secondary_colour),''),'pending')
  returning * into v_season_team;
  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_season_team.id,v_user_id,'pending',false);
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,after_data)
  values(v_user_id,'team.registration.submitted','season_team',v_season_team.id::text,
    jsonb_build_object('season_id',p_season_id,'team_name',v_season_team.name));
  return v_season_team;
end;
$$;

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
  select * into v_season_team from public.season_teams
  where id=p_season_team_id and registration_status='pending' for update;
  if not found then raise exception 'No pending team registration exists'; end if;
  select user_id into v_captain_user_id from public.team_memberships
  where season_team_id=p_season_team_id and status='pending' and is_captain=false for update;
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

revoke all on function public.register_team(uuid,text,text,text) from public,anon;
grant execute on function public.register_team(uuid,text,text,text) to authenticated;
revoke all on function public.resolve_team_registration(uuid,text,text) from public,anon;
grant execute on function public.resolve_team_registration(uuid,text,text) to authenticated;

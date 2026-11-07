create or replace function public.admin_get_player_detail(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_player public.players; v_profile public.profiles;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  select * into v_player from public.players where user_id=p_user_id;
  if not found then raise exception 'Player not found'; end if;
  select * into v_profile from public.profiles where id=p_user_id;

  return jsonb_build_object(
    'player',jsonb_build_object(
      'user_id',v_player.user_id,'full_name',v_player.full_name,'email',v_player.email,
      'phone',v_player.phone,'date_of_birth',v_player.date_of_birth,
      'registration_status',v_player.registration_status,'is_banned',v_player.is_banned,
      'banned_at',v_player.banned_at,'banned_reason',v_player.banned_reason,
      'is_genuine',v_player.is_genuine,'created_at',v_player.created_at
    ),
    'profile',jsonb_build_object(
      'first_name',v_profile.first_name,'last_name',v_profile.last_name,
      'display_name',v_profile.display_name,'date_of_birth',v_profile.date_of_birth,
      'phone',v_profile.phone,'emergency_contact_name',v_profile.emergency_contact_name,
      'emergency_contact_phone',v_profile.emergency_contact_phone,
      'preferred_position',v_profile.preferred_position,'avatar_path',v_profile.avatar_path
    ),
    'memberships',coalesce((
      select jsonb_agg(jsonb_build_object(
        'membership_id',tm.id,'team_name',st.name,'season_name',se.name,
        'league_name',l.name,'location_name',loc.name,'status',tm.status,
        'is_captain',tm.is_captain,'squad_number',tm.squad_number,
        'joined_at',tm.joined_at,'left_at',tm.left_at
      ) order by tm.created_at desc)
      from public.team_memberships tm
      join public.season_teams st on st.id=tm.season_team_id
      join public.seasons se on se.id=st.season_id
      join public.leagues l on l.id=se.league_id
      join public.locations loc on loc.id=l.location_id
      where tm.user_id=p_user_id
    ),'[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_update_player_profile(
  p_user_id uuid,
  p_first_name text,
  p_last_name text,
  p_display_name text,
  p_phone text,
  p_emergency_contact_name text,
  p_emergency_contact_phone text,
  p_preferred_position text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_player public.players;
  v_profile public.profiles;
  v_before jsonb;
  v_full_name text;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  if p_phone is null or length(btrim(p_phone))<7 then raise exception 'Enter a valid contact phone number'; end if;
  v_full_name:=btrim(concat_ws(' ',nullif(btrim(p_first_name),''),nullif(btrim(p_last_name),'')));
  if length(v_full_name)<2 then raise exception 'Enter the player first name and/or last name'; end if;

  select * into v_player from public.players where user_id=p_user_id for update;
  if not found then raise exception 'Player not found'; end if;
  select * into v_profile from public.profiles where id=p_user_id for update;

  v_before:=jsonb_build_object(
    'full_name',v_player.full_name,'phone',v_player.phone,
    'first_name',v_profile.first_name,'last_name',v_profile.last_name,
    'display_name',v_profile.display_name,'emergency_contact_name',v_profile.emergency_contact_name,
    'emergency_contact_phone',v_profile.emergency_contact_phone,
    'preferred_position',v_profile.preferred_position
  );

  update public.profiles set
    first_name=nullif(btrim(p_first_name),''),
    last_name=nullif(btrim(p_last_name),''),
    display_name=nullif(btrim(p_display_name),''),
    phone=btrim(p_phone),
    emergency_contact_name=nullif(btrim(p_emergency_contact_name),''),
    emergency_contact_phone=nullif(btrim(p_emergency_contact_phone),''),
    preferred_position=nullif(btrim(p_preferred_position),''),
    updated_at=now()
  where id=p_user_id returning * into v_profile;

  update public.players set full_name=v_full_name,phone=btrim(p_phone),updated_at=now()
  where user_id=p_user_id returning * into v_player;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,'player.profile.admin_corrected','player',p_user_id::text,btrim(p_reason),v_before,
    jsonb_build_object(
      'full_name',v_player.full_name,'phone',v_player.phone,
      'first_name',v_profile.first_name,'last_name',v_profile.last_name,
      'display_name',v_profile.display_name,'emergency_contact_name',v_profile.emergency_contact_name,
      'emergency_contact_phone',v_profile.emergency_contact_phone,
      'preferred_position',v_profile.preferred_position
    ));
  return public.admin_get_player_detail(p_user_id);
end;
$$;

create or replace function public.admin_set_player_ban(
  p_user_id uuid,
  p_is_banned boolean,
  p_reason text
)
returns public.players
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor uuid:=auth.uid(); v_player public.players; v_before jsonb;
begin
  if v_actor is null or not public.has_platform_role() then raise exception 'Administrator permission required'; end if;
  if p_reason is null or length(btrim(p_reason))<5 then raise exception 'Enter a reason of at least 5 characters'; end if;
  if p_user_id=v_actor and p_is_banned then raise exception 'You cannot ban your own administrator account'; end if;
  select * into v_player from public.players where user_id=p_user_id for update;
  if not found then raise exception 'Player not found'; end if;
  v_before:=jsonb_build_object('is_banned',v_player.is_banned,'banned_at',v_player.banned_at,'banned_reason',v_player.banned_reason);
  update public.players set
    is_banned=p_is_banned,
    banned_at=case when p_is_banned then now() else null end,
    banned_reason=case when p_is_banned then btrim(p_reason) else null end,
    updated_at=now()
  where user_id=p_user_id returning * into v_player;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(v_actor,case when p_is_banned then 'player.banned' else 'player.unbanned' end,
    'player',p_user_id::text,btrim(p_reason),v_before,
    jsonb_build_object('is_banned',v_player.is_banned,'banned_at',v_player.banned_at,'banned_reason',v_player.banned_reason));
  return v_player;
end;
$$;

revoke all on function public.admin_get_player_detail(uuid) from public,anon;
grant execute on function public.admin_get_player_detail(uuid) to authenticated;
revoke all on function public.admin_update_player_profile(uuid,text,text,text,text,text,text,text,text) from public,anon;
grant execute on function public.admin_update_player_profile(uuid,text,text,text,text,text,text,text,text) to authenticated;
revoke all on function public.admin_set_player_ban(uuid,boolean,text) from public,anon;
grant execute on function public.admin_set_player_ban(uuid,boolean,text) to authenticated;

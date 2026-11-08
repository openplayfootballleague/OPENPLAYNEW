-- Enforce the agreed ban semantics in one transaction.
-- Historical memberships, appearances, results and statistics are retained.
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
declare
  v_actor uuid := auth.uid();
  v_player public.players;
  v_before jsonb;
  v_team record;
  v_successor public.team_memberships;
  v_successor_name text;
  v_appearance_count bigint;
  v_admin record;
begin
  if v_actor is null
     or not exists (
       select 1 from public.user_roles ur
       where ur.user_id = v_actor and ur.role in ('admin','super_admin')
     ) then
    raise exception 'Global administrator permission required';
  end if;
  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'Enter a reason of at least 5 characters';
  end if;
  if p_user_id = v_actor and p_is_banned then
    raise exception 'You cannot ban your own administrator account';
  end if;

  select * into v_player
  from public.players
  where user_id = p_user_id
  for update;
  if not found then raise exception 'Player not found'; end if;

  v_before := jsonb_build_object(
    'is_banned',v_player.is_banned,
    'banned_at',v_player.banned_at,
    'banned_reason',v_player.banned_reason,
    'registration_status',v_player.registration_status
  );

  if p_is_banned then
    -- Revoke current captaincy before choosing successors. Process each team
    -- independently and lock its memberships to serialize captain changes.
    for v_team in
      select tm.season_team_id, st.season_id
      from public.team_memberships tm
      join public.season_teams st on st.id = tm.season_team_id
      where tm.user_id = p_user_id
        and tm.status = 'active'
        and tm.is_captain = true
      order by tm.season_team_id
      for update of tm
    loop
      perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('captain-handover:'||v_team.season_team_id::text,0)
      );

      update public.team_memberships
      set is_captain = false, updated_at = now()
      where season_team_id = v_team.season_team_id
        and user_id = p_user_id
        and status = 'active';

      v_successor := null;
      v_successor_name := null;
      v_appearance_count := 0;

      select tm.*, p.full_name, coalesce(app.appearances,0)
      into v_successor, v_successor_name, v_appearance_count
      from public.team_memberships tm
      join public.players p on p.user_id = tm.user_id
      left join lateral (
        select count(*)::bigint as appearances
        from public.fixture_team_sheets ts
        join public.fixtures f on f.id = ts.fixture_id
        join public.fixture_team_sheet_players tsp on tsp.team_sheet_id = ts.id
        where ts.season_team_id = tm.season_team_id
          and tsp.user_id = tm.user_id
          and tsp.did_appear = true
          and f.season_id = v_team.season_id
      ) app on true
      where tm.season_team_id = v_team.season_team_id
        and tm.status = 'active'
        and tm.user_id <> p_user_id
        and p.registration_status = 'registered'
        and p.is_banned = false
      order by coalesce(app.appearances,0) desc,
               p.full_name collate "C" asc,
               tm.id
      limit 1
      for update of tm;

      if found then
        update public.team_memberships
        set is_captain = true, updated_at = now()
        where id = v_successor.id;

        insert into public.audit_log(
          actor_user_id,action,entity_type,entity_id,reason,before_data,after_data
        ) values (
          v_actor,'team.captain.auto_succeeded','team_membership',
          v_successor.id::text,btrim(p_reason),
          jsonb_build_object('former_captain_user_id',p_user_id,'season_team_id',v_team.season_team_id),
          jsonb_build_object('new_captain_user_id',v_successor.user_id,'appearances',v_appearance_count)
        );
        perform public.enqueue_notification_event(
          v_successor.user_id,'team.captain.handover_completed',
          jsonb_build_object('season_team_id',v_team.season_team_id,'changed_at',now(),'role','captain')
        );
      else
        insert into public.audit_log(
          actor_user_id,action,entity_type,entity_id,reason,after_data
        ) values (
          v_actor,'team.captain.successor_missing','season_team',
          v_team.season_team_id::text,btrim(p_reason),
          jsonb_build_object('former_captain_user_id',p_user_id,'admin_action_required',true)
        );
        for v_admin in
          select distinct ur.user_id
          from public.user_roles ur
          where ur.role in ('admin','super_admin')
        loop
          perform public.enqueue_notification_event(
            v_admin.user_id,'team.captain.successor_missing',
            jsonb_build_object('season_team_id',v_team.season_team_id,'changed_at',now())
          );
        end loop;
      end if;
    end loop;

    -- Preserve membership rows for historical records; deactivate current
    -- memberships and reject outstanding requests.
    update public.team_memberships
    set status = case when status = 'active' then 'left'::public.membership_status
                      when status = 'pending' then 'rejected'::public.membership_status
                      else status end,
        is_captain = false,
        left_at = case when status in ('active','pending') then now() else left_at end,
        updated_at = now()
    where user_id = p_user_id
      and status in ('active','pending');
  end if;

  update public.players
  set is_banned = p_is_banned,
      banned_at = case when p_is_banned then now() else null end,
      banned_reason = case when p_is_banned then btrim(p_reason) else null end,
      registration_status = case
        when p_is_banned then registration_status
        when is_banned then 'pending_review'::public.player_registration_status
        else registration_status
      end,
      updated_at = now()
  where user_id = p_user_id
  returning * into v_player;

  insert into public.audit_log(
    actor_user_id,action,entity_type,entity_id,reason,before_data,after_data
  ) values (
    v_actor,
    case when p_is_banned then 'player.banned' else 'player.unbanned' end,
    'player',p_user_id::text,btrim(p_reason),v_before,
    jsonb_build_object(
      'is_banned',v_player.is_banned,
      'banned_at',v_player.banned_at,
      'banned_reason',v_player.banned_reason,
      'registration_status',v_player.registration_status,
      'membership_reactivation_required',not p_is_banned
    )
  );
  return v_player;
end;
$$;

revoke all on function public.admin_set_player_ban(uuid,boolean,text) from public, anon;
grant execute on function public.admin_set_player_ban(uuid,boolean,text) to authenticated;

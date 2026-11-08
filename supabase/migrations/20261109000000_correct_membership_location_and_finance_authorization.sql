-- Forward-only correction for three live authorization mismatches.
-- This migration intentionally preserves the existing business logic and audit paths.
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  -- Captains may resolve requests for their own team. Platform admins retain
  -- global access; league admins require an explicit assignment to that team location.
  v_def := pg_catalog.pg_get_functiondef(
    'public.resolve_team_membership_request(uuid,text)'::regprocedure
  );
  v_old := ' if not public.can_administer_location((select l.location_id from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.id=p_membership_id)) then raise exception ''You are not assigned to this location''; end if;' || E'\n';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected membership location guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, '');
  v_old := '  if not public.has_platform_role()' || E'\n' ||
           '     and not public.is_active_team_captain(v_membership.season_team_id) then' || E'\n' ||
           '    raise exception ''Captain permission required'';' || E'\n' ||
           '  end if;';
  v_new := '  if not (' || E'\n' ||
           '    exists (select 1 from public.user_roles ur where ur.user_id=v_actor and ur.role in (''admin'',''super_admin''))' || E'\n' ||
           '    or (' || E'\n' ||
           '      exists (select 1 from public.user_roles ur where ur.user_id=v_actor and ur.role=''league_admin'')' || E'\n' ||
           '      and public.can_administer_location((' || E'\n' ||
           '        select l.location_id from public.season_teams st' || E'\n' ||
           '        join public.seasons s on s.id=st.season_id' || E'\n' ||
           '        join public.leagues l on l.id=s.league_id' || E'\n' ||
           '        where st.id=v_membership.season_team_id' || E'\n' ||
           '      ))' || E'\n' ||
           '    )' || E'\n' ||
           '    or public.is_active_team_captain(v_membership.season_team_id)' || E'\n' ||
           '  ) then' || E'\n' ||
           '    raise exception ''Captain or authorised location administrator permission required'' using errcode = ''42501'';' || E'\n' ||
           '  end if;';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected membership role guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, v_new);
  execute v_def;

  -- Location activation is a platform-wide control: only admin/super_admin.
  v_def := pg_catalog.pg_get_functiondef(
    'public.admin_set_location_active(uuid,boolean,text)'::regprocedure
  );
  v_old := ' if not public.can_administer_location(p_location_id) then raise exception ''You are not assigned to this location''; end if;' || E'\n';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected location activation scope guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, '');
  v_old := '  if v_actor is null or not public.has_platform_role() then' || E'\n' ||
           '    raise exception ''Administrator permission required'' using errcode = ''42501'';' || E'\n' ||
           '  end if;';
  v_new := '  if v_actor is null or not exists (' || E'\n' ||
           '    select 1 from public.user_roles ur' || E'\n' ||
           '    where ur.user_id=v_actor and ur.role in (''admin'',''super_admin'')' || E'\n' ||
           '  ) then' || E'\n' ||
           '    raise exception ''Global administrator permission required'' using errcode = ''42501'';' || E'\n' ||
           '  end if;';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected location activation role guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, v_new);
  execute v_def;

  -- finance_admin is intentionally a global finance role per has_finance_access().
  -- Validate the season below; do not impose unrelated league-admin assignment.
  v_def := pg_catalog.pg_get_functiondef(
    'public.admin_set_player_fixture_fee(uuid,integer,integer,text)'::regprocedure
  );
  v_old := ' if not public.can_administer_location((select l.location_id from public.seasons s join public.leagues l on l.id=s.league_id where s.id=p_season_id)) then raise exception ''You are not assigned to this location''; end if;' || E'\n';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected player-fee location guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, '');
  if pg_catalog.strpos(v_def, 'if not public.has_finance_access()') = 0 then
    raise exception 'Finance authorization guard missing; refusing partial migration';
  end if;
  execute v_def;
end;
$migration$;

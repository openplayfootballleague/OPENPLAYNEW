-- Forward-only correction for three live authorization mismatches.
-- This migration intentionally preserves the existing business logic and audit paths.
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
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

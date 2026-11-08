-- Restrict legacy unfiltered admin RPCs to global administrators.
-- Location administrators must use the contextual RPCs, which require an
-- explicit assigned location through assert_admin_location_context().
do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  -- The unfiltered dashboard includes global review queues and player contact data.
  v_def := pg_catalog.pg_get_functiondef('public.get_admin_dashboard()'::regprocedure);
  v_old := '  if auth.uid() is null or not public.has_platform_role() then raise exception ''Administrator permission required''; end if;';
  v_new := '  if auth.uid() is null or not exists(select 1 from public.user_roles where user_id=auth.uid() and role in (''admin'',''super_admin'')) then raise exception ''Global administrator permission required'' using errcode = ''42501''; end if;';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected get_admin_dashboard authorization guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, v_new);
  execute v_def;

  -- The unfiltered player register exposes player contact details across locations.
  v_def := pg_catalog.pg_get_functiondef('public.get_admin_player_register(text,text,integer,integer)'::regprocedure);
  v_old := '  if v_actor is null or not public.has_platform_role() then raise exception ''Administrator permission required''; end if;';
  v_new := '  if v_actor is null or not exists(select 1 from public.user_roles where user_id=v_actor and role in (''admin'',''super_admin'')) then raise exception ''Global administrator permission required'' using errcode = ''42501''; end if;';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected get_admin_player_register authorization guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, v_new);
  execute v_def;

  -- The unfiltered transfer queue exposes player identities and transfer reasons.
  v_def := pg_catalog.pg_get_functiondef('public.admin_get_transfer_requests(text)'::regprocedure);
  v_old := '  if v_actor is null or not public.has_platform_role() then raise exception ''Administrator permission required''; end if;';
  v_new := '  if v_actor is null or not exists(select 1 from public.user_roles where user_id=v_actor and role in (''admin'',''super_admin'')) then raise exception ''Global administrator permission required'' using errcode = ''42501''; end if;';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected admin_get_transfer_requests authorization guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, v_new);
  execute v_def;

  -- The unfiltered team-sheet RPC exposes player names and squad details across locations.
  v_def := pg_catalog.pg_get_functiondef('public.get_admin_team_sheets()'::regprocedure);
  v_old := 'if auth.uid() is null or not public.has_platform_role() then raise exception ''Administrator permission required''; end if;';
  v_new := 'if auth.uid() is null or not exists(select 1 from public.user_roles where user_id=auth.uid() and role in (''admin'',''super_admin'')) then raise exception ''Global administrator permission required'' using errcode = ''42501''; end if;';
  if pg_catalog.strpos(v_def, v_old) = 0 then
    raise exception 'Expected get_admin_team_sheets authorization guard not found; refusing partial migration';
  end if;
  v_def := pg_catalog.replace(v_def, v_old, v_new);
  execute v_def;
end;
$migration$;

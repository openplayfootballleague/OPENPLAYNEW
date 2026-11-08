-- Restrict first-release location activation/deactivation to global administrators.
-- Location-scoped league administrators may manage their assigned competition,
-- but must not activate or deactivate platform locations.
do $$
declare
  v_definition text;
  v_old text := E'  if v_actor is null or not public.has_platform_role() then\n    raise exception ''Administrator permission required'' using errcode = ''42501'';\n  end if;';
  v_new text := E'  if v_actor is null or not exists (\n    select 1 from public.user_roles\n    where user_id = v_actor and role in (''admin'', ''super_admin'')\n  ) then\n    raise exception ''Global administrator permission required'' using errcode = ''42501'';\n  end if;';
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'public.admin_set_location_active(uuid,boolean,text)'::regprocedure
  );
  if position(v_old in v_definition) = 0 then
    if position('role in (''admin'', ''super_admin'')' in v_definition) > 0 then
      raise notice 'admin_set_location_active already has the global-admin guard';
      return;
    end if;
    raise exception 'Expected admin_set_location_active role guard was not found; refusing an unsafe automatic rewrite';
  end if;
  v_definition := replace(v_definition, v_old, v_new);
  execute v_definition;
end;
$$;

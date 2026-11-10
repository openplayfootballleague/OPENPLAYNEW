-- Do not represent global-only player identity reviews as a zero queue to location admins.
-- They may see location-scoped competition queues, but player identity matching is
-- intentionally restricted to global administrators.
do $$
declare
  v_def text;
  v_before text := '''pending_player_reviews'',(case when exists(select 1 from public.user_roles where user_id=auth.uid() and role in (''admin'',''super_admin'')) then (select count(*) from public.player_registration_reviews r where r.status=''pending'') else 0 end)';
  v_after text := '''pending_player_reviews'',(case when exists(select 1 from public.user_roles where user_id=auth.uid() and role in (''admin'',''super_admin'')) then (select count(*) from public.player_registration_reviews r where r.status=''pending'') else null end)';
begin
  v_def := pg_get_functiondef('public.get_admin_dashboard_contextual(uuid,uuid,uuid)'::regprocedure);
  if position(v_before in v_def)=0 then
    if position(v_after in v_def)>0 then
      return;
    end if;
    raise exception 'Expected global-only player review count expression was not found';
  end if;
  v_def := replace(v_def,v_before,v_after);
  execute v_def;
end;
$$;

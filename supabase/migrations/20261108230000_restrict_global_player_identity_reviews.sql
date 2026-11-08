do $$
declare v_def text;
begin
 v_def:=pg_get_functiondef('public.get_admin_dashboard_contextual(uuid,uuid,uuid)'::regprocedure);
 v_def:=replace(v_def,
  '''pending_player_reviews'',(select count(*) from public.player_registration_reviews r where r.status=''pending'')',
  '''pending_player_reviews'',(case when exists(select 1 from public.user_roles where user_id=auth.uid() and role in (''admin'',''super_admin'')) then (select count(*) from public.player_registration_reviews r where r.status=''pending'') else 0 end)');
 v_def:=replace(v_def,
  'from public.player_registration_reviews r join public.players p on p.id=r.player_id where r.status=''pending''',
  'from public.player_registration_reviews r join public.players p on p.id=r.player_id where r.status=''pending'' and exists(select 1 from public.user_roles where user_id=auth.uid() and role in (''admin'',''super_admin''))');
 execute v_def;
 v_def:=pg_get_functiondef('public.resolve_player_registration_review(uuid,text,text)'::regprocedure);
 v_def:=replace(v_def,'if v_actor is null or not public.has_platform_role() then','if v_actor is null or not exists(select 1 from public.user_roles where user_id=v_actor and role in (''admin'',''super_admin'')) then');
 execute v_def;
end;
$$;

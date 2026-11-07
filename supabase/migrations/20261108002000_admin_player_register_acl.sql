revoke all on function public.get_admin_player_register(text,text,integer,integer) from public,anon;
grant execute on function public.get_admin_player_register(text,text,integer,integer) to authenticated;

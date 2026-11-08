do $$
declare v_sig text;v_def text;v_pos integer;v_check text;
begin
 foreach v_sig in array array[
 'get_admin_audit_history(text,integer,integer)','admin_get_notification_events(text,integer,integer)',
 'admin_get_notification_dispatch_status()','admin_retry_notification(uuid,text)',
 'admin_set_notification_hold(uuid,boolean,text)','admin_set_notification_dispatch_enabled(boolean,text,boolean)',
 'admin_get_player_detail(uuid)','admin_set_player_ban(uuid,boolean,text)','admin_set_player_genuine(uuid,boolean,text)',
 'admin_update_player_profile(uuid,text,text,text,text,text,text,text,text)'
 ] loop
  v_def:=pg_get_functiondef(v_sig::regprocedure);
  if position('role in (''admin'',''super_admin'')' in v_def)=0 then
   v_pos:=position(E'\nbegin\n' in v_def);
   if v_pos=0 then raise exception 'Function body marker not found: %',v_sig; end if;
   v_check:=' if auth.uid() is null or not exists(select 1 from public.user_roles where user_id=auth.uid() and role in (''admin'',''super_admin'')) then raise exception ''Global administrator permission required''; end if;'||E'\n';
   v_def:=overlay(v_def placing E'\nbegin\n'||v_check from v_pos for 7);execute v_def;
  end if;
 end loop;
 v_sig:='get_admin_season_statistics(uuid)';v_def:=pg_get_functiondef(v_sig::regprocedure);
 if position('can_administer_location' in v_def)=0 then
  v_pos:=position(E'\nbegin\n' in v_def);
  v_check:=' if not public.can_administer_location((select l.location_id from public.seasons s join public.leagues l on l.id=s.league_id where s.id=p_season_id)) then raise exception ''You are not assigned to this location''; end if;'||E'\n';
  v_def:=overlay(v_def placing E'\nbegin\n'||v_check from v_pos for 7);execute v_def;
 end if;
 v_sig:='get_admin_fixture_scorer_options(uuid)';v_def:=pg_get_functiondef(v_sig::regprocedure);
 if position('can_administer_location' in v_def)=0 then
  v_pos:=position(E'\nbegin\n' in v_def);
  v_check:=' if not public.can_administer_location((select l.location_id from public.fixtures f join public.seasons s on s.id=f.season_id join public.leagues l on l.id=s.league_id where f.id=p_fixture_id)) then raise exception ''You are not assigned to this location''; end if;'||E'\n';
  v_def:=overlay(v_def placing E'\nbegin\n'||v_check from v_pos for 7);execute v_def;
 end if;
end;
$$;

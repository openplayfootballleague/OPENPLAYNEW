do $$
declare v_sig text;v_def text;v_pos integer;v_check text;v_expr text;
begin
 for v_sig,v_expr in select * from (values
 ('admin_create_league(uuid,text,competition_format,text)','p_location_id'),
 ('admin_create_season(uuid,text,integer,date,date,timestamp with time zone,timestamp with time zone)','(select l.location_id from public.leagues l where l.id=p_league_id)'),
 ('admin_create_season_team(uuid,text,text,text)','(select l.location_id from public.seasons s join public.leagues l on l.id=s.league_id where s.id=p_season_id)'),
 ('admin_create_fixture(uuid,integer,integer,uuid,uuid,timestamp with time zone,uuid,text)','(select l.location_id from public.seasons s join public.leagues l on l.id=s.league_id where s.id=p_season_id)'),
 ('admin_amend_team_sheet(uuid,uuid[],uuid[],uuid,text)','(select l.location_id from public.fixture_team_sheets sh join public.fixtures f on f.id=sh.fixture_id join public.seasons s on s.id=f.season_id join public.leagues l on l.id=s.league_id where sh.id=p_team_sheet_id)'),
 ('admin_record_fixture_result_with_appearances(uuid,integer,integer,uuid[],uuid[],uuid[],uuid[],text)','(select l.location_id from public.fixtures f join public.seasons s on s.id=f.season_id join public.leagues l on l.id=s.league_id where f.id=p_fixture_id)'),
 ('admin_set_fixture_status(uuid,fixture_status,text)','(select l.location_id from public.fixtures f join public.seasons s on s.id=f.season_id join public.leagues l on l.id=s.league_id where f.id=p_fixture_id)'),
 ('admin_set_league_published(uuid,boolean)','(select l.location_id from public.leagues l where l.id=p_league_id)'),
 ('admin_set_location_active(uuid,boolean,text)','p_location_id'),
 ('admin_transition_season(uuid,season_status)','(select l.location_id from public.seasons s join public.leagues l on l.id=s.league_id where s.id=p_season_id)'),
 ('admin_set_player_fixture_fee(uuid,integer,integer,text)','(select l.location_id from public.seasons s join public.leagues l on l.id=s.league_id where s.id=p_season_id)'),
 ('admin_add_player_to_team(uuid,uuid,boolean)','(select l.location_id from public.season_teams st join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where st.id=p_season_team_id)'),
 ('admin_remove_player_from_team(uuid,text)','(select l.location_id from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.id=p_membership_id)'),
 ('admin_resolve_player_transfer_request(uuid,text,text)','(select l.location_id from public.player_transfer_requests r join public.season_teams st on st.id=r.source_season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where r.id=p_request_id)'),
 ('resolve_team_membership_request(uuid,text)','(select l.location_id from public.team_memberships tm join public.season_teams st on st.id=tm.season_team_id join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where tm.id=p_membership_id)'),
 ('resolve_team_registration(uuid,text,text)','(select l.location_id from public.season_teams st join public.seasons s on s.id=st.season_id join public.leagues l on l.id=s.league_id where st.id=p_season_team_id)')
 ) as scoped(signature,expression)
 loop
  v_def:=pg_get_functiondef(v_sig::regprocedure);
  if position('assert_admin_location_context' in v_def)=0 and position('can_administer_location' in v_def)=0 then
   v_pos:=position(E'\nbegin\n' in v_def);
   if v_pos=0 then raise exception 'Function body marker not found: %',v_sig; end if;
   v_check:=' if not public.can_administer_location('||v_expr||') then raise exception ''You are not assigned to this location''; end if;'||E'\n';
   v_def:=overlay(v_def placing E'\nbegin\n'||v_check from v_pos for 7);
   execute v_def;
  end if;
 end loop;
end;
$$;

do $$
declare v_sig text;v_def text;v_pos integer;v_check text;
begin
 foreach v_sig in array array[
 'admin_create_location(text,text,text,text)',
 'admin_get_player_detail(uuid)',
 'admin_set_player_ban(uuid,boolean,text)',
 'admin_set_player_genuine(uuid,boolean,text)',
 'admin_update_player_profile(uuid,text,text,text,text,text,text,text,text)',
 'admin_get_notification_events(text,integer,integer)',
 'admin_get_notification_dispatch_status()',
 'admin_retry_notification(uuid,text)',
 'admin_set_notification_hold(uuid,boolean,text)',
 'admin_set_notification_dispatch_enabled(boolean,text,boolean)'
 ] loop
  v_def:=pg_get_functiondef(v_sig::regprocedure);
  if position('role in (''admin'',''super_admin'')' in v_def)=0 then
   v_pos:=position(E'\nbegin\n' in v_def);
   if v_pos=0 then raise exception 'Function body marker not found: %',v_sig; end if;
   v_check:=' if auth.uid() is null or not exists(select 1 from public.user_roles where user_id=auth.uid() and role in (''admin'',''super_admin'')) then raise exception ''Global administrator permission required''; end if;'||E'\n';
   v_def:=overlay(v_def placing E'\nbegin\n'||v_check from v_pos for 7);
   execute v_def;
  end if;
 end loop;
end;
$$;

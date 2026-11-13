do $season_round_robin$
declare
  v_admin uuid:=gen_random_uuid();
  v_admin_email text:='ci-round-robin-admin-'||substr(gen_random_uuid()::text,1,8)||'@openplay.invalid';
  v_season uuid:=gen_random_uuid();
  v_team uuid;
  v_venue uuid;
  v_preview jsonb;
  v_generated jsonb;
  v_denied boolean;
  v_fixture_count integer;
  v_round_count integer;
  v_times time[];
  i integer;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values(v_admin,'authenticated','authenticated',v_admin_email,'','{}'::jsonb,now(),now());
  insert into public.user_roles(user_id,role,granted_by)
  values(v_admin,'league_admin','00000000-0000-4000-8000-000000000005');
  insert into public.location_admin_assignments(user_id,location_id,assigned_by)
  values(v_admin,'00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000005');

  select id into v_venue from public.venues
  where location_id='00000000-0000-4000-8000-000000000010'
    and name='CI Friday Astro' and is_active=true;
  if v_venue is null then raise exception 'Expected the active CI Friday Astro venue from the venue regression test'; end if;

  insert into public.seasons(id,league_id,name,season_number,is_public,status,starts_on,ends_on)
  values(v_season,'00000000-0000-4000-8000-000000000020','CI Round Robin Season',999,false,'registration_open',date '2026-11-01',date '2027-03-31');

  for i in 1..8 loop
    v_team:=gen_random_uuid();
    insert into public.teams(id,created_by)
    values(v_team,'00000000-0000-4000-8000-000000000005');
    insert into public.season_teams(id,team_id,season_id,name,slug,registration_status)
    values(gen_random_uuid(),v_team,v_season,format('CI Round Robin Team %s',i),
      'ci-round-robin-'||i::text||'-'||substr(gen_random_uuid()::text,1,8),'approved');
  end loop;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_admin,'role','authenticated')::text,true);

  perform public.admin_update_season_matchday_settings(
    v_season,5,time '20:00',25,5,v_venue,'double'
  );

  v_preview:=public.admin_preview_round_robin_fixtures(v_season,date '2026-11-20');
  if (v_preview->>'round_count')::integer<>14 then raise exception 'Expected 14 gameweeks for eight teams in double round-robin mode'; end if;
  if (v_preview->>'fixture_count')::integer<>56 then raise exception 'Expected 56 fixtures for eight teams in double round-robin mode'; end if;
  if v_preview->>'venue_name'<>'CI Friday Astro' then raise exception 'Fixture preview did not use the configured venue'; end if;
  if v_preview->>'last_matchday_date'<>'2027-02-19' then raise exception 'Unexpected final matchday date: %',v_preview->>'last_matchday_date'; end if;
  if jsonb_array_length(v_preview->'fixtures')<>56 then raise exception 'Fixture preview did not return all 56 fixtures'; end if;
  if exists(select 1 from public.fixtures where season_id=v_season) then raise exception 'Preview must not create fixtures'; end if;

  perform public.admin_update_season_matchday_settings(v_season,5,time '20:00',26,5,v_venue,'double');
  v_denied:=false;
  begin
    perform public.admin_generate_round_robin_fixtures(v_season,date '2026-11-20',v_preview->>'settings_hash');
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Generation must reject a stale schedule preview after settings change'; end if;
  perform public.admin_update_season_matchday_settings(v_season,5,time '20:00',25,5,v_venue,'double');
  v_preview:=public.admin_preview_round_robin_fixtures(v_season,date '2026-11-20');

  v_generated:=public.admin_generate_round_robin_fixtures(v_season,date '2026-11-20',v_preview->>'settings_hash');
  if (v_generated->>'fixture_count')::integer<>56 or (v_generated->>'round_count')::integer<>14 then
    raise exception 'Fixture generation returned an unexpected summary: %',v_generated;
  end if;
  select count(*),count(distinct gameweek) into v_fixture_count,v_round_count
  from public.fixtures where season_id=v_season;
  if v_fixture_count<>56 or v_round_count<>14 then
    raise exception 'Expected 56 fixtures across 14 gameweeks; found % fixtures across % gameweeks',v_fixture_count,v_round_count;
  end if;
  if exists(
    select 1 from public.fixtures where season_id=v_season
    group by gameweek having count(*)<>4
  ) then raise exception 'Every gameweek should contain four fixtures for eight teams'; end if;
  if exists(
    select 1 from public.fixtures
    where season_id=v_season and (
      extract(dow from scheduled_at at time zone 'Europe/London')<>5
      or (scheduled_at at time zone 'Europe/London')::time<time '20:00'
      or (scheduled_at at time zone 'Europe/London')::time+interval '25 minutes'>time '22:00'
    )
  ) then raise exception 'Generated fixtures fall outside the configured Friday venue hours'; end if;

  select array_agg((scheduled_at at time zone 'Europe/London')::time order by fixture_number)
  into v_times from public.fixtures where season_id=v_season and gameweek=1;
  if v_times<>array[time '20:00',time '20:30',time '21:00',time '21:30'] then
    raise exception 'Unexpected sequential kick-off slots: %',v_times;
  end if;

  if exists(
    select 1 from public.season_teams st
    where st.season_id=v_season and (
      (select count(*) from public.fixtures f where f.season_id=v_season and f.home_team_id=st.id)<>7
      or (select count(*) from public.fixtures f where f.season_id=v_season and f.away_team_id=st.id)<>7
    )
  ) then raise exception 'Double round-robin schedule must give every team seven home and seven away fixtures'; end if;
  if exists(
    select 1 from public.fixtures f
    where f.season_id=v_season and f.home_team_id=f.away_team_id
  ) then raise exception 'A generated fixture cannot have the same home and away team'; end if;
  if not exists(select 1 from public.audit_log where action='fixtures.generated' and entity_id=v_season::text) then
    raise exception 'Fixture generation must create an audit record';
  end if;

  v_denied:=false;
  begin
    perform public.admin_generate_round_robin_fixtures(v_season,date '2026-11-20',v_preview->>'settings_hash');
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Fixture generation must not overwrite an existing schedule'; end if;

  v_denied:=false;
  begin
    perform public.admin_update_season_matchday_settings(v_season,5,time '20:00',25,5,v_venue,'double');
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Matchday settings must be locked after fixtures are generated'; end if;

  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000006',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000006","role":"authenticated"}',true);
  v_denied:=false;
  begin
    perform public.admin_preview_round_robin_fixtures(v_season,date '2026-11-20');
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'Finance-only administrators must not preview fixture generation'; end if;

  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_admin,'role','authenticated')::text,true);
  v_denied:=false;
  begin
    perform public.admin_preview_round_robin_fixtures('00000000-0000-4000-8000-000000000031',date '2026-11-20');
  exception when others then v_denied:=true;
  end;
  if not v_denied then raise exception 'A location administrator must not preview fixtures for another location'; end if;

  raise notice 'Season matchday settings and 8-team double round-robin generation checks passed';
end
$season_round_robin$;

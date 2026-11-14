-- Negative and positive coverage for team-sheet composition rules (AGENTS.md product rules):
-- 6-a-side: exactly 6 starters, up to 3 substitutes; 7-a-side: exactly 7 starters, up to 4.
-- A goalkeeper must be one of the starters; players may not repeat; every selection must be
-- an active, approved member of the submitting team; only that team's active captain may submit.
begin;


do $test$
declare
  v_admin uuid:=gen_random_uuid();
  v_location uuid;
  v_format text;
  v_league uuid; v_season uuid; v_team uuid; v_opp_team uuid; v_season_team uuid; v_opp uuid; v_fixture uuid;
  v_members uuid[]; v_opp_members uuid[]; v_user uuid; v_member uuid; v_captain uuid;
  v_starters integer; v_subs integer; i integer;
  v_failed text;
  v_sheet public.fixture_team_sheets;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values(v_admin,'authenticated','authenticated','ci-sheet-admin@openplay.invalid','','{}'::jsonb,now(),now(),now());
  insert into public.locations(name,slug,town,region,is_active)
  values('Team Sheet Test Location','ci-team-sheet-location','Bideford','Devon',false) returning id into v_location;

  foreach v_format in array array['six_a_side','seven_a_side'] loop
    v_starters:=case when v_format='six_a_side' then 6 else 7 end;
    v_subs:=case when v_format='six_a_side' then 3 else 4 end;
    insert into public.leagues(location_id,name,slug,format,is_published)
    values(v_location,'CI Sheet '||v_format,'ci-sheet-'||replace(v_format,'_','-'),v_format::public.competition_format,false) returning id into v_league;
    insert into public.seasons(league_id,name,season_number,status,is_public)
    values(v_league,'CI Sheet Season '||v_format,1,'active',false) returning id into v_season;
    insert into public.teams(created_by) values(v_admin) returning id into v_team;
    insert into public.teams(created_by) values(v_admin) returning id into v_opp_team;
    insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
    values(v_team,v_season,'Sheet Home '||v_format,'ci-sheet-home-'||replace(v_format,'_','-'),'approved',now(),v_admin) returning id into v_season_team;
    insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
    values(v_opp_team,v_season,'Sheet Away '||v_format,'ci-sheet-away-'||replace(v_format,'_','-'),'approved',now(),v_admin) returning id into v_opp;

    v_members:='{}'; v_opp_members:='{}';
    for i in 1..(v_starters+v_subs+2) loop
      v_user:=gen_random_uuid();
      insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
      values(v_user,'authenticated','authenticated',format('ci-sheet-%s-%s@openplay.invalid',v_format,i),'','{}'::jsonb,now(),now(),now());
      insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
      values(v_user,format('Sheet %s %s',v_format,i),format('+4477009%s%s',case when v_format='six_a_side' then '41' else '42' end,lpad(i::text,3,'0')),
             format('ci-sheet-%s-%s@openplay.invalid',v_format,i),date '1995-01-01','registered',false);
      insert into public.team_memberships(season_team_id,user_id,status,is_captain,joined_at)
      values(v_season_team,v_user,'active',i=1,now()) returning id into v_member;
      v_members:=v_members||v_member;
      if i=1 then v_captain:=v_user; end if;
    end loop;
    -- One member of the opposing team, used for the ineligible-player case.
    v_user:=gen_random_uuid();
    insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
    values(v_user,'authenticated','authenticated',format('ci-sheet-opp-%s@openplay.invalid',v_format),'','{}'::jsonb,now(),now(),now());
    insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
    values(v_user,'Sheet Opponent '||v_format,format('+4477009%s999',case when v_format='six_a_side' then '41' else '42' end),
           format('ci-sheet-opp-%s@openplay.invalid',v_format),date '1995-01-01','registered',false);
    insert into public.team_memberships(season_team_id,user_id,status,is_captain,joined_at)
    values(v_opp,v_user,'active',false,now()) returning id into v_member;
    v_opp_members:=array[v_member];

    insert into public.fixtures(season_id,gameweek,fixture_number,home_team_id,away_team_id,scheduled_at,status)
    values(v_season,1,1,v_season_team,v_opp,now()+interval '3 days','scheduled') returning id into v_fixture;

    -- Each invalid sheet must be rejected with its specific rule.
    perform set_config('request.jwt.claim.sub',v_captain::text,true);
    for i in 1..7 loop
      v_failed:=null;
      begin
        case i
          when 1 then -- too few starters
            perform public.submit_team_sheet(v_fixture,v_season_team,v_members[1:v_starters-1],'{}',v_members[1]);
          when 2 then -- too many starters
            perform public.submit_team_sheet(v_fixture,v_season_team,v_members[1:v_starters+1],'{}',v_members[1]);
          when 3 then -- too many substitutes
            perform public.submit_team_sheet(v_fixture,v_season_team,v_members[1:v_starters],v_members[v_starters+1:v_starters+v_subs+1],v_members[1]);
          when 4 then -- no goalkeeper
            perform public.submit_team_sheet(v_fixture,v_season_team,v_members[1:v_starters],'{}',null);
          when 5 then -- goalkeeper is a substitute, not a starter
            perform public.submit_team_sheet(v_fixture,v_season_team,v_members[1:v_starters],v_members[v_starters+1:v_starters+1],v_members[v_starters+1]);
          when 6 then -- duplicate selection
            perform public.submit_team_sheet(v_fixture,v_season_team,v_members[1:v_starters],v_members[1:1],v_members[1]);
          when 7 then -- player from another team
            perform public.submit_team_sheet(v_fixture,v_season_team,v_members[1:v_starters-1]||v_opp_members,'{}',v_members[1]);
        end case;
      exception when others then v_failed:=sqlerrm;
      end;
      if v_failed is null then raise exception '% case % must be rejected',v_format,i; end if;
      if not (case i
        when 1 then v_failed like 'Select exactly % starting players'
        when 2 then v_failed like 'Select exactly % starting players'
        when 3 then v_failed like 'Select no more than % substitutes'
        when 4 then v_failed='Select one goalkeeper from your starting players'
        when 5 then v_failed='Select one goalkeeper from your starting players'
        when 6 then v_failed='A player can only appear once on a team sheet'
        when 7 then v_failed='Every selected player must have an active, approved membership in this team'
      end) then raise exception '% case % rejected for the wrong reason: %',v_format,i,v_failed; end if;
      if exists(select 1 from public.fixture_team_sheets where fixture_id=v_fixture) then
        raise exception '% case % left a team sheet behind',v_format,i;
      end if;
    end loop;

    -- Only the team's active captain may submit.
    perform set_config('request.jwt.claim.sub',(select user_id::text from public.team_memberships where id=v_members[2]),true);
    v_failed:=null;
    begin
      perform public.submit_team_sheet(v_fixture,v_season_team,v_members[1:v_starters],'{}',v_members[1]);
    exception when others then v_failed:=sqlerrm;
    end;
    if v_failed is distinct from 'Active team captain permission required' then
      raise exception '% non-captain submission must be refused, got %',v_format,coalesce(v_failed,'success');
    end if;

    -- The maximum valid sheet is accepted and locked.
    perform set_config('request.jwt.claim.sub',v_captain::text,true);
    v_sheet:=public.submit_team_sheet(v_fixture,v_season_team,v_members[1:v_starters],v_members[v_starters+1:v_starters+v_subs],v_members[1]);
    if not v_sheet.is_locked then raise exception '% valid sheet must be locked after submission',v_format; end if;
    if (select count(*) from public.fixture_team_sheet_players where team_sheet_id=v_sheet.id and role='starter')<>v_starters
       or (select count(*) from public.fixture_team_sheet_players where team_sheet_id=v_sheet.id and role='substitute')<>v_subs
       or (select count(*) from public.fixture_team_sheet_players where team_sheet_id=v_sheet.id and is_goalkeeper)<>1 then
      raise exception '% valid sheet stored the wrong selection',v_format;
    end if;
    perform set_config('request.jwt.claim.sub','',true);
  end loop;
end;
$test$;

rollback;

-- Team registration form, accepted fee snapshot, declarations and private captain details.
begin;

do $team_registration_application$
declare
  v_player constant uuid:='97000000-0000-4000-8000-000000000001';
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_terms record;
  v_season_team public.season_teams;
  v_membership public.team_memberships;
  v_details public.team_registration_details;
  v_rejected boolean;
begin
  if not exists (
    select 1 from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='team_registration_details' and c.relrowsecurity
  ) then
    raise exception 'Private team registration details must have RLS enabled';
  end if;

  if has_table_privilege('anon','public.team_registration_details','SELECT')
     or has_table_privilege('authenticated','public.team_registration_details','INSERT')
     or has_table_privilege('authenticated','public.team_registration_details','UPDATE')
     or has_table_privilege('authenticated','public.team_registration_details','DELETE') then
    raise exception 'Team captain contact and declaration records must not be directly exposed or mutable';
  end if;

  if has_function_privilege('anon','public.get_team_registration_terms(uuid)','EXECUTE')
     or has_function_privilege('anon','public.register_team(uuid,text,text,text,text,text,text,boolean,boolean,integer,integer,integer,boolean,boolean,boolean,boolean,boolean,boolean,text)','EXECUTE') then
    raise exception 'Team registration RPCs must not be anonymously executable';
  end if;

  if not exists (
    select 1 from storage.buckets
    where id='team-crests' and public is true
      and allowed_mime_types @> array['image/png','image/jpeg','image/svg+xml']::text[]
  ) then
    raise exception 'The public team crest bucket must allow PNG, JPG and SVG uploads';
  end if;

  insert into auth.users(id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values(v_player,'authenticated','authenticated','ci-team-registration@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.players(user_id,full_name,phone,email,date_of_birth,registration_status,is_banned,is_genuine)
  values(v_player,'CI Team Captain','07700900991','ci-team-registration@openplay.invalid',date '1990-01-01','registered',false,true);

  select id into v_location from public.locations where is_active=true order by created_at limit 1;
  if v_location is null then raise exception 'Expected an active location from the local Supabase seed'; end if;

  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Team Registration League','ci-team-registration-league',true)
  returning id into v_league;

  insert into public.seasons(league_id,name,season_number,status,is_public,gameweek_count)
  values(v_league,'CI Team Registration Season',997,'registration_open',true,14)
  returning id into v_season;

  insert into public.season_fee_configs(season_id,effective_from_gameweek,team_fee_pence,reason)
  values
    (v_season,1,3000,'CI initial weekly fee'),
    (v_season,8,3500,'CI scheduled weekly fee change');

  perform set_config('request.jwt.claim.sub',v_player::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);

  select * into v_terms from public.get_team_registration_terms(v_season);
  if v_terms.weekly_fee_pence<>3000 or v_terms.gameweek_count<>14 or v_terms.full_season_total_pence<>45500 then
    raise exception 'Registration terms must calculate the initial weekly fee and all scheduled gameweek fees';
  end if;

  v_rejected:=false;
  begin
    perform public.register_team(
      v_season,'CI Registration Team','Orange and black','https://www.instagram.com/ci.registration/',
      'returning',null,null,true,false,3100,45500,14,true,
      true,true,true,true,true,'CI registration notes'
    );
  exception when others then
    v_rejected:=true;
  end;
  if not v_rejected then raise exception 'Registration must reject a stale or incorrect accepted weekly fee'; end if;

  v_rejected:=false;
  begin
    perform public.register_team(
      v_season,'CI Registration Team','Orange and black','https://www.instagram.com/ci.registration/',
      'returning',null,null,true,false,3000,45500,14,true,
      true,true,true,false,true,'CI registration notes'
    );
  exception when others then
    v_rejected:=true;
  end;
  if not v_rejected then raise exception 'Registration must reject an unaccepted minimum-age declaration'; end if;

  select * into v_season_team
  from public.register_team(
    v_season,'CI Registration Team','Orange and black','https://www.instagram.com/ci.registration/',
    'returning',null,null,true,false,3000,45500,14,true,
    true,true,true,true,true,'CI registration notes'
  );

  if v_season_team.registration_status<>'pending'
     or v_season_team.instagram_url<>'https://www.instagram.com/ci.registration/'
     or v_season_team.badge_path is not null then
    raise exception 'Team application must remain pending and retain optional public branding';
  end if;

  select * into v_membership
  from public.team_memberships
  where season_team_id=v_season_team.id and user_id=v_player;

  if not found or v_membership.status<>'pending' or v_membership.is_captain then
    raise exception 'Applicant must not become captain or active player before administrator approval';
  end if;

  select * into v_details
  from public.team_registration_details
  where season_team_id=v_season_team.id;

  if not found
     or v_details.captain_full_name<>'CI Team Captain'
     or v_details.captain_mobile<>'07700900991'
     or v_details.captain_whatsapp<>'07700900991'
     or not v_details.captain_whatsapp_same_as_mobile
     or v_details.captain_no_whatsapp
     or v_details.team_status<>'returning'
     or v_details.weekly_fee_accepted_pence<>3000
     or v_details.full_season_total_accepted_pence<>45500
     or v_details.gameweek_count_accepted<>14
     or v_details.fee_accepted_competition_id<>v_league
     or v_details.fee_accepted_at is null
     or v_details.declarations_accepted_at is null
     or v_details.declarations_version<>'team-registration-v1-2026-11-12'
     or v_details.additional_information<>'CI registration notes' then
    raise exception 'Private application record must retain captain, fee acceptance, declaration and optional notes';
  end if;
end;
$team_registration_application$;

rollback;

-- Age-tier and guardian-consent lifecycle regression tests.
-- Runs only in the disposable local Supabase database created by CI.

do $age_tier_guardian_consent$
declare
  v_admin constant uuid := '91000000-0000-4000-8000-000000000001';
  v_minor constant uuid := '91000000-0000-4000-8000-000000000002';
  v_underage constant uuid := '91000000-0000-4000-8000-000000000003';
  v_consent_id uuid;
  v_location uuid;
  v_league uuid;
  v_season uuid;
  v_team uuid;
  v_season_team uuid;
  v_player public.players;
  v_rejected boolean;
  v_verify_token constant text := repeat('a',64);
  v_withdraw_token constant text := repeat('b',64);
  v_verify_token_2 constant text := repeat('c',64);
  v_withdraw_token_2 constant text := repeat('d',64);
  v_verify_hash text;
  v_withdraw_hash text;
  v_verify_hash_2 text;
  v_withdraw_hash_2 text;
begin
  -- Age decisions use the UK civil date across UTC midnight and BST changes.
  if public.open_play_uk_date('2026-03-28 23:30:00+00'::timestamptz) <> date '2026-03-28'
     or public.open_play_uk_date('2026-03-29 00:30:00+00'::timestamptz) <> date '2026-03-29'
     or public.open_play_uk_date('2026-03-29 01:30:00+00'::timestamptz) <> date '2026-03-29' then
    raise exception 'UK civil-date calculation is incorrect around the spring clock change';
  end if;
  if extract(year from age(date '2025-02-28',date '2008-02-29')) <> 16
     or extract(year from age(date '2025-03-01',date '2008-02-29')) <> 17 then
    raise exception 'Leap-day age calculation is inconsistent';
  end if;
  if extract(year from age(date '2026-11-08',date '2008-11-09')) <> 17
     or extract(year from age(date '2026-11-09',date '2008-11-09')) <> 18 then
    raise exception 'Eighteenth-birthday age transition is incorrect';
  end if;

  insert into auth.users
    (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_admin,'authenticated','authenticated','ci-guardian-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_minor,'authenticated','authenticated','ci-guardian-player@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_underage,'authenticated','authenticated','ci-underage-player@openplay.invalid','','{}'::jsonb,now(),now(),now());
  insert into public.user_roles(user_id,role,granted_by) values(v_admin,'admin',v_admin);

  -- Hash test tokens as the migration/test owner. The helper is intentionally
  -- not executable by authenticated clients; only the trusted Edge Function
  -- supplies token hashes to the consent-request RPC.
  v_verify_hash:=public.hash_guardian_consent_token(v_verify_token);
  v_withdraw_hash:=public.hash_guardian_consent_token(v_withdraw_token);
  v_verify_hash_2:=public.hash_guardian_consent_token(v_verify_token_2);
  v_withdraw_hash_2:=public.hash_guardian_consent_token(v_withdraw_token_2);

  -- Token-bearing consent RPCs must be callable only by the trusted Edge Function.
  if has_function_privilege('anon','public.request_player_guardian_consent(uuid,date,text,text,text,text)','EXECUTE')
     or has_function_privilege('authenticated','public.request_player_guardian_consent(uuid,date,text,text,text,text)','EXECUTE')
     or has_function_privilege('anon','public.verify_player_guardian_consent(text)','EXECUTE')
     or has_function_privilege('authenticated','public.verify_player_guardian_consent(text)','EXECUTE')
     or has_function_privilege('anon','public.withdraw_player_guardian_consent(text)','EXECUTE')
     or has_function_privilege('authenticated','public.withdraw_player_guardian_consent(text)','EXECUTE') then
    raise exception 'A client role can directly execute a privileged guardian-consent RPC';
  end if;
  if not has_function_privilege('service_role','public.request_player_guardian_consent(uuid,date,text,text,text,text)','EXECUTE')
     or not has_function_privilege('service_role','public.verify_player_guardian_consent(text)','EXECUTE')
     or not has_function_privilege('service_role','public.withdraw_player_guardian_consent(text)','EXECUTE') then
    raise exception 'Trusted service role is missing guardian-consent RPC execution';
  end if;

  -- Under-16s may browse public information but cannot create player identities.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_underage::text,true);
  v_rejected:=false;
  begin
    perform public.register_player('Under Sixteen','07700900991','ci-underage-player@openplay.invalid',
      (public.open_play_uk_date(statement_timestamp())-interval '15 years')::date);
  exception when others then v_rejected:=true;
  end;
  execute 'reset role';
  if not v_rejected then raise exception 'A 15-year-old was able to register as a player'; end if;

  -- A 16-year-old cannot register without verified and administrator-approved consent.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_minor::text,true);
  v_rejected:=false;
  begin
    perform public.register_player('Guardian Test Player','07700900992','ci-guardian-player@openplay.invalid',
      (public.open_play_uk_date(statement_timestamp())-interval '16 years')::date);
  exception when others then v_rejected:=true;
  end;
  if not v_rejected then raise exception 'A 16-year-old registered without guardian consent'; end if;

  execute 'reset role';
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  perform * from public.request_player_guardian_consent(
    v_minor,(public.open_play_uk_date(statement_timestamp())-interval '16 years')::date,'Guardian Test','guardian@openplay.invalid',
    v_verify_hash,
    v_withdraw_hash
  );
  execute 'reset role';

  if not exists(
    select 1 from public.player_guardian_consents
    where player_user_id=v_minor
      and withdrawal_token_hash is not null
      and withdrawal_token_expires_at>now()
      and withdrawal_token_expires_at<=now()+interval '2 years'
  ) then
    raise exception 'Guardian withdrawal token was not created with its two-year expiry';
  end if;

  -- Repeated requests are throttled; they must not be used to spam a guardian.
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  v_rejected:=false;
  begin
    perform * from public.request_player_guardian_consent(
      v_minor,(public.open_play_uk_date(statement_timestamp())-interval '16 years')::date,'Guardian Test','guardian@openplay.invalid',
      v_verify_hash_2,
      v_withdraw_hash_2
    );
  exception when others then
    v_rejected:=true;
  end;
  execute 'reset role';
  if not v_rejected then raise exception 'Guardian consent request cooldown was not enforced'; end if;

  -- The guardian must explicitly confirm the single-use verification link.
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  if public.verify_player_guardian_consent(v_verify_token)<>'pending_admin_review' then
    raise exception 'Guardian verification did not move the request to administrator review';
  end if;
  execute 'reset role';

  select id into v_consent_id from public.player_guardian_consents where player_user_id=v_minor;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  if public.admin_review_guardian_consent(v_consent_id,'approved','Verified guardian relationship')<>'approved' then
    raise exception 'Administrator approval was not recorded';
  end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_minor::text,true);
  select * into v_player from public.register_player(
    'Guardian Test Player','07700900992','ci-guardian-player@openplay.invalid',
    (public.open_play_uk_date(statement_timestamp())-interval '16 years')::date
  );
  execute 'reset role';
  if v_player.registration_status<>'registered' then
    raise exception 'Player registration did not proceed after verified guardian consent and admin approval';
  end if;

  -- Give the player an active captain membership to verify withdrawal suspension.
  insert into public.locations(name,slug,town,region,is_active)
  values('CI Guardian Consent','ci-guardian-consent','Bideford','North Devon',false)
  returning id into v_location;
  insert into public.leagues(location_id,name,slug,is_published)
  values(v_location,'CI Guardian Consent','ci-guardian-consent',false)
  returning id into v_league;
  insert into public.seasons(league_id,name,season_number,status,is_public)
  values(v_league,'CI Guardian Consent',998,'active',false)
  returning id into v_season;
  insert into public.teams(created_by) values(v_admin) returning id into v_team;
  insert into public.season_teams(team_id,season_id,name,slug,registration_status,approved_at,approved_by)
  values(v_team,v_season,'Guardian Test Team','ci-guardian-test-team','approved',now(),v_admin)
  returning id into v_season_team;
  insert into public.team_memberships(season_team_id,user_id,status,is_captain)
  values(v_season_team,v_minor,'active',true);

  -- An under-16 basic-view account must not inherit another player's private
  -- membership data or direct access to guardian-consent records.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_underage::text,true);
  select count(*) into v_count from public.team_memberships;
  if v_count <> 0 then
    raise exception 'An under-16 basic-view account can read another player''s team membership';
  end if;
  if has_table_privilege('authenticated','public.player_guardian_consents','SELECT') then
    raise exception 'Authenticated users have direct access to private guardian-consent records';
  end if;
  execute 'reset role';

  -- Withdrawal links are one-use and time-limited. An expired token cannot
  -- revoke consent; the parent must request a fresh verified link.
  update public.player_guardian_consents
  set withdrawal_token_expires_at=now()-interval '1 second'
  where player_user_id=v_minor;
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  v_rejected:=false;
  begin
    perform public.withdraw_player_guardian_consent(v_withdraw_token);
  exception when others then v_rejected:=true;
  end;
  execute 'reset role';
  if not v_rejected then raise exception 'Expired guardian withdrawal token was accepted'; end if;
  update public.player_guardian_consents
  set withdrawal_token_expires_at=now()+interval '1 year'
  where player_user_id=v_minor;

  -- Withdrawal is deliberately a POST action in the Edge Function; the SQL
  -- RPC consumes the one-time secret and revokes current player/team access.
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  if public.withdraw_player_guardian_consent(v_withdraw_token)<>'withdrawn' then
    raise exception 'Guardian withdrawal was not recorded';
  end if;
  execute 'reset role';

  if exists(
    select 1 from public.player_guardian_consents
    where player_user_id=v_minor
      and (withdrawal_token_hash is not null or withdrawal_token_expires_at is not null)
  ) then
    raise exception 'Guardian withdrawal did not consume and clear its one-use token';
  end if;
  if (select registration_status from public.players where user_id=v_minor)<>'rejected' then
    raise exception 'Guardian withdrawal did not suspend player registration';
  end if;
  if exists(select 1 from public.team_memberships where user_id=v_minor and status in ('active','pending')) then
    raise exception 'Guardian withdrawal did not revoke active and pending team memberships';
  end if;
  if exists(select 1 from public.team_memberships where user_id=v_minor and is_captain) then
    raise exception 'Guardian withdrawal left captaincy active';
  end if;

  -- The separate identity-review RPC must not bypass the guardian-consent
  -- requirement when an administrator attempts to restore player access.
  insert into public.player_registration_reviews(
    player_id,name_matched,phone_matched,email_matched,matched_player_ids
  ) values(v_player.id,true,true,false,array[v_player.id]);
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_rejected:=false;
  begin
    perform public.resolve_player_registration_review(v_player.id,'approved','CI guardian bypass test');
  exception when others then
    v_rejected:=true;
  end;
  execute 'reset role';
  if not v_rejected then
    raise exception 'Admin identity-review approval bypassed withdrawn guardian consent';
  end if;
  if (select registration_status from public.players where user_id=v_minor)<>'rejected' then
    raise exception 'Failed identity-review approval changed the suspended player registration';
  end if;
  if (select status from public.player_registration_reviews where player_id=v_player.id)<>'pending' then
    raise exception 'Failed identity-review approval consumed the pending review';
  end if;

  -- Withdrawal and verification links are one-use; a second withdrawal fails.
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  v_rejected:=false;
  begin
    perform public.withdraw_player_guardian_consent(v_withdraw_token);
  exception when others then v_rejected:=true;
  end;
  execute 'reset role';
  if not v_rejected then raise exception 'Guardian withdrawal token was reusable'; end if;

  -- A fresh consent cycle after withdrawal restores the pre-suspension player
  -- registration state, but does not silently reactivate historical memberships.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_minor::text,true);
  execute 'reset role';
  update public.player_guardian_consents
  set requested_at=now()-interval '2 minutes'
  where player_user_id=v_minor;
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  perform * from public.request_player_guardian_consent(
    v_minor,(public.open_play_uk_date(statement_timestamp())-interval '16 years')::date,'Guardian Test','guardian@openplay.invalid',
    v_verify_hash_2,
    v_withdraw_hash_2
  );
  execute 'reset role';
  execute 'set local role service_role';
  perform set_config('request.jwt.claim.role','service_role',true);
  perform public.verify_player_guardian_consent(v_verify_token_2);
  execute 'reset role';
  select id into v_consent_id from public.player_guardian_consents where player_user_id=v_minor;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  perform public.admin_review_guardian_consent(v_consent_id,'approved','Reverified guardian consent');
  execute 'reset role';
  if (select registration_status from public.players where user_id=v_minor)<>'registered' then
    raise exception 'Approved renewed guardian consent did not restore the prior player registration status';
  end if;
  if exists(select 1 from public.team_memberships where user_id=v_minor and status='active') then
    raise exception 'Renewed consent unexpectedly reactivated old team memberships';
  end if;
end;
$age_tier_guardian_consent$;

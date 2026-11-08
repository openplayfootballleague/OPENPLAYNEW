-- Phase 1 player registration identity and review-data security regression.
-- Runs only in the disposable local Supabase database created by CI.

do $player_registration_security$
declare
  v_registration_def text;
  v_policy record;
  v_count integer;
  v_can_select boolean;
  v_denied boolean;
begin
  v_registration_def := lower(pg_catalog.pg_get_functiondef(
    'public.register_player(text,text,text,date)'::regprocedure
  ));

  if pg_catalog.strpos(v_registration_def, 'qualifying_matches') = 0
     or pg_catalog.strpos(v_registration_def, 'match_evidence') = 0
     or pg_catalog.strpos(v_registration_def, '>= 2') = 0
     or pg_catalog.strpos(v_registration_def, 'matched_candidate_count') = 0 then
    raise exception 'Player registration must store per-candidate evidence and require two matches on one candidate';
  end if;

  if pg_catalog.strpos(v_registration_def,
       'exists(select 1 from public.players p where lower(trim(p.full_name))') > 0 then
    raise exception 'Legacy independent cross-player identity matching remains in register_player';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='player_registration_reviews'
      and column_name='match_evidence'
      and data_type='jsonb'
      and is_nullable='NO'
  ) then
    raise exception 'Per-candidate identity evidence column is missing or nullable';
  end if;

  select * into v_policy
  from pg_catalog.pg_policies
  where schemaname='public'
    and tablename='player_registration_reviews'
    and policyname='player_registration_reviews_admin_only';

  if not found
     or v_policy.cmd <> 'SELECT'
     or v_policy.roles <> array['authenticated']::name[]
     or pg_catalog.strpos(lower(v_policy.qual), 'has_global_admin_role') = 0 then
    raise exception 'Identity-review SELECT policy must be limited to global administrators';
  end if;

  if has_table_privilege('anon','public.player_registration_reviews','SELECT') then
    raise exception 'Anonymous users must not read identity-review records';
  end if;
  if not has_table_privilege('authenticated','public.player_registration_reviews','SELECT') then
    raise exception 'Authenticated global administrators must retain SELECT privilege';
  end if;
  if has_table_privilege('authenticated','public.player_registration_reviews','INSERT')
     or has_table_privilege('authenticated','public.player_registration_reviews','UPDATE')
     or has_table_privilege('authenticated','public.player_registration_reviews','DELETE') then
    raise exception 'Authenticated clients must not directly mutate identity-review records';
  end if;

  if exists (
    select 1 from pg_catalog.pg_policies
    where schemaname='public'
      and tablename='player_registration_reviews'
      and cmd in ('INSERT','UPDATE','DELETE','ALL')
  ) then
    raise exception 'Identity-review table must not expose direct client mutation policies';
  end if;

  -- Exercise the per-candidate two-of-three rule with a split-match false
  -- positive and each valid two-field combination.
  create temporary table identity_match_candidates (
    id integer,
    full_name text,
    phone text,
    email text
  ) on commit drop;

  insert into identity_match_candidates values
    (1,'Alice Example','+447700900101','alice@example.invalid'),
    (2,'Bob Example','+447700900202','bob@example.invalid');

  select count(*) into v_count
  from (
    select id
    from identity_match_candidates
    where
      (case when lower(trim(full_name))=lower(trim('Alice Example')) then 1 else 0 end)
      + (case when pg_catalog.regexp_replace(phone,'[^0-9]','','g')
                    = pg_catalog.regexp_replace('+447700900202','[^0-9]','','g') then 1 else 0 end)
      + (case when lower(trim(email))=lower(trim('new@example.invalid')) then 1 else 0 end) >= 2
  ) split_matches;
  if v_count <> 0 then
    raise exception 'A name match on one player and phone match on another must not trigger review';
  end if;

  select count(*) into v_count
  from identity_match_candidates
  where
    (case when lower(trim(full_name))=lower(trim('Alice Example')) then 1 else 0 end)
    + (case when pg_catalog.regexp_replace(phone,'[^0-9]','','g')
                  = pg_catalog.regexp_replace('+447700900101','[^0-9]','','g') then 1 else 0 end)
    + (case when lower(trim(email))=lower(trim('new@example.invalid')) then 1 else 0 end) >= 2;
  if v_count <> 1 then raise exception 'Name plus phone match must trigger review for one candidate'; end if;

  select count(*) into v_count
  from identity_match_candidates
  where
    (case when lower(trim(full_name))=lower(trim('Alice Example')) then 1 else 0 end)
    + (case when pg_catalog.regexp_replace(phone,'[^0-9]','','g')
                  = pg_catalog.regexp_replace('+447700900999','[^0-9]','','g') then 1 else 0 end)
    + (case when lower(trim(email))=lower(trim('alice@example.invalid')) then 1 else 0 end) >= 2;
  if v_count <> 1 then raise exception 'Name plus email match must trigger review for one candidate'; end if;

  select count(*) into v_count
  from identity_match_candidates
  where
    (case when lower(trim(full_name))=lower(trim('New Name')) then 1 else 0 end)
    + (case when pg_catalog.regexp_replace(phone,'[^0-9]','','g')
                  = pg_catalog.regexp_replace('+447700900101','[^0-9]','','g') then 1 else 0 end)
    + (case when lower(trim(email))=lower(trim('alice@example.invalid')) then 1 else 0 end) >= 2;
  if v_count <> 1 then raise exception 'Phone plus email match must trigger review for one candidate'; end if;

  select count(*) into v_count
  from identity_match_candidates
  where
    (case when lower(trim(full_name))=lower(trim('Alice Example')) then 1 else 0 end)
    + (case when pg_catalog.regexp_replace(phone,'[^0-9]','','g')
                  = pg_catalog.regexp_replace('+447700900999','[^0-9]','','g') then 1 else 0 end)
    + (case when lower(trim(email))=lower(trim('new@example.invalid')) then 1 else 0 end) >= 2;
  if v_count <> 0 then raise exception 'A single identity match must not trigger review'; end if;
end;
$player_registration_security$;

-- Exercise the actual registration RPC against controlled candidate rows.
do $register_player_identity_runtime$
declare
  v_candidate_a uuid;
  v_candidate_b uuid;
  v_player_status text;
  v_review record;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    ('00000000-0000-4000-8000-000000000201','authenticated','authenticated','ci-seed-a@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    ('00000000-0000-4000-8000-000000000202','authenticated','authenticated','ci-seed-b@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    ('00000000-0000-4000-8000-000000000203','authenticated','authenticated','ci-split-match@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    ('00000000-0000-4000-8000-000000000204','authenticated','authenticated','ci-name-phone@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    ('00000000-0000-4000-8000-000000000205','authenticated','authenticated','ci-name-email@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    ('00000000-0000-4000-8000-000000000206','authenticated','authenticated','ci-phone-email@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    ('00000000-0000-4000-8000-000000000207','authenticated','authenticated','ci-one-match@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    ('00000000-0000-4000-8000-000000000208','authenticated','authenticated','ci-no-match@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.players (user_id,full_name,phone,email,date_of_birth,registration_status,is_banned)
  values ('00000000-0000-4000-8000-000000000201','Alice Example','+447700900201','ci-name-email@openplay.invalid',date '1990-01-01','registered',false)
  returning id into v_candidate_a;

  insert into public.players (user_id,full_name,phone,email,date_of_birth,registration_status,is_banned,banned_at)
  values ('00000000-0000-4000-8000-000000000202','Bob Example','+447700900202','ci-phone-email@openplay.invalid',date '1990-01-02','registered',true,now())
  returning id into v_candidate_b;

  execute 'set local role authenticated';

  -- A name match on candidate A and phone match on candidate B must not combine.
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000203',true);
  perform public.register_player('Alice Example','+447700900202','ci-split-match@openplay.invalid',date '1990-01-01');
  select registration_status::text into v_player_status from public.players where user_id='00000000-0000-4000-8000-000000000203';
  if v_player_status <> 'registered'
     or exists(select 1 from public.player_registration_reviews r join public.players p on p.id=r.player_id where p.user_id='00000000-0000-4000-8000-000000000203') then
    raise exception 'Split matches across two existing players incorrectly triggered manual review';
  end if;

  -- Name + phone against one candidate.
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000204',true);
  perform public.register_player('Alice Example','+447700900201','ci-name-phone@openplay.invalid',date '1990-01-01');
  select registration_status::text into v_player_status from public.players where user_id='00000000-0000-4000-8000-000000000204';
  if v_player_status <> 'pending_review' then raise exception 'Name plus phone match did not trigger review'; end if;
  execute 'reset role';
  select r.* into v_review from public.player_registration_reviews r join public.players p on p.id=r.player_id where p.user_id='00000000-0000-4000-8000-000000000204';
  if v_review.matched_player_ids <> array[v_candidate_a]::uuid[]
     or jsonb_array_length(v_review.match_evidence) <> 1
     or (v_review.match_evidence->0->>'name_matched')::boolean is not true
     or (v_review.match_evidence->0->>'phone_matched')::boolean is not true
     or (v_review.match_evidence->0->>'email_matched')::boolean is not false then
    raise exception 'Name plus phone review evidence is not candidate-specific';
  end if;
  execute 'set local role authenticated';

  -- Name + email against one candidate.
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000205',true);
  perform public.register_player('Alice Example','+447700900299','ci-name-email@openplay.invalid',date '1990-01-01');
  select registration_status::text into v_player_status from public.players where user_id='00000000-0000-4000-8000-000000000205';
  if v_player_status <> 'pending_review' then raise exception 'Name plus email match did not trigger review'; end if;

  -- Phone + email against a banned candidate: banned records remain in duplicate evaluation.
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000206',true);
  perform public.register_player('Charlie Example','+447700900202','ci-phone-email@openplay.invalid',date '1990-01-02');
  select registration_status::text into v_player_status from public.players where user_id='00000000-0000-4000-8000-000000000206';
  if v_player_status <> 'pending_review' then raise exception 'Phone plus email match against a banned candidate was not evaluated consistently'; end if;
  execute 'reset role';
  select r.* into v_review from public.player_registration_reviews r join public.players p on p.id=r.player_id where p.user_id='00000000-0000-4000-8000-000000000206';
  if v_review.matched_player_ids <> array[v_candidate_b]::uuid[]
     or jsonb_array_length(v_review.match_evidence) <> 1
     or (v_review.match_evidence->0->>'phone_matched')::boolean is not true
     or (v_review.match_evidence->0->>'email_matched')::boolean is not true then
    raise exception 'Phone plus email evidence for a banned candidate is incomplete';
  end if;

  -- A single matching metric must not trigger review; DOB alone is never a metric.
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000207',true);
  perform public.register_player('Alice Example','+447700900299','ci-one-match@openplay.invalid',date '1990-01-01');
  select registration_status::text into v_player_status from public.players where user_id='00000000-0000-4000-8000-000000000207';
  if v_player_status <> 'registered' then raise exception 'A single identity metric incorrectly triggered review'; end if;

  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000208',true);
  perform public.register_player('Charlie Example','+447700900299','ci-no-match@openplay.invalid',date '1990-01-01');
  select registration_status::text into v_player_status from public.players where user_id='00000000-0000-4000-8000-000000000208';
  if v_player_status <> 'registered' then raise exception 'DOB-only overlap incorrectly triggered identity review'; end if;

  execute 'reset role';
end;
$register_player_identity_runtime$;

-- Verify row-level visibility using disposable test identities.
do $identity_review_role_matrix$
declare
  v_count integer;
  v_denied boolean := false;
  v_player_id uuid;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    ('00000000-0000-4000-8000-000000000101','authenticated','authenticated','ci-review-league-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    ('00000000-0000-4000-8000-000000000102','authenticated','authenticated','ci-review-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    ('00000000-0000-4000-8000-000000000103','authenticated','authenticated','ci-review-super-admin@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    ('00000000-0000-4000-8000-000000000104','authenticated','authenticated','ci-review-player@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.user_roles (user_id,role,granted_by)
  values
    ('00000000-0000-4000-8000-000000000101','league_admin','00000000-0000-4000-8000-000000000102'),
    ('00000000-0000-4000-8000-000000000102','admin','00000000-0000-4000-8000-000000000102'),
    ('00000000-0000-4000-8000-000000000103','super_admin','00000000-0000-4000-8000-000000000102');

  insert into public.players (user_id,full_name,phone,email,date_of_birth,registration_status)
  values ('00000000-0000-4000-8000-000000000104','CI Review Player','+447700900104','ci-review-player@openplay.invalid',date '1990-01-04','pending_review')
  returning id into v_player_id;

  insert into public.player_registration_reviews
    (player_id,name_matched,phone_matched,email_matched,matched_player_ids,match_evidence)
  values
    (v_player_id,true,true,false,'{}'::uuid[],
     '[{"player_id":"00000000-0000-4000-8000-000000000001","name_matched":true,"phone_matched":true,"email_matched":false}]'::jsonb);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
  if not public.has_platform_role() or public.has_global_admin_role() then
    raise exception 'League admin role classification is incorrect for review-data test';
  end if;
  select count(*) into v_count from public.player_registration_reviews where player_id=v_player_id;
  if v_count <> 0 then raise exception 'League admin can read global player identity-review evidence'; end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',true);
  select count(*) into v_count from public.player_registration_reviews where player_id=v_player_id;
  if v_count <> 1 then raise exception 'Global admin cannot read player identity-review evidence'; end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000103',true);
  select count(*) into v_count from public.player_registration_reviews where player_id=v_player_id;
  if v_count <> 1 then raise exception 'Super admin cannot read player identity-review evidence'; end if;
  execute 'reset role';

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000104',true);
  select count(*) into v_count from public.player_registration_reviews where player_id=v_player_id;
  if v_count <> 0 then raise exception 'Ordinary player can read global player identity-review evidence'; end if;
  execute 'reset role';

  execute 'set local role anon';
  v_denied := false;
  begin
    execute 'select count(*) from public.player_registration_reviews';
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Anonymous caller unexpectedly queried identity-review records'; end if;
  execute 'reset role';
end;
$identity_review_role_matrix$;

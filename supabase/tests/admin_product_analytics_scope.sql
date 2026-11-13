-- Minimal admin product-analytics scope RPC regression. Run on a disposable clean Supabase database.
do $product_analytics_scope$
declare
  v_scope jsonb;
  v_denied boolean := false;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,created_at,updated_at)
  values
    ('f2000000-0000-4000-8000-000000000001','authenticated','authenticated','ci-scope-global@openplay.invalid','','{}'::jsonb,now(),now()),
    ('f2000000-0000-4000-8000-000000000002','authenticated','authenticated','ci-scope-location@openplay.invalid','','{}'::jsonb,now(),now()),
    ('f2000000-0000-4000-8000-000000000003','authenticated','authenticated','ci-scope-player@openplay.invalid','','{}'::jsonb,now(),now());

  insert into public.user_roles(user_id,role,granted_by)
  values
    ('f2000000-0000-4000-8000-000000000001','admin','f2000000-0000-4000-8000-000000000001'),
    ('f2000000-0000-4000-8000-000000000002','league_admin','f2000000-0000-4000-8000-000000000001');

  insert into public.locations(id,name,slug,town,region,is_active)
  values
    ('f2000000-0000-4000-8000-000000000010','Scope Location A','ci-scope-location-a','Bideford','Devon',false),
    ('f2000000-0000-4000-8000-000000000011','Scope Location B','ci-scope-location-b','Barnstaple','Devon',false);

  insert into public.location_admin_assignments(user_id,location_id,assigned_by)
  values ('f2000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000010','f2000000-0000-4000-8000-000000000001');

  insert into public.leagues(id,location_id,name,slug,is_published)
  values
    ('f2000000-0000-4000-8000-000000000020','f2000000-0000-4000-8000-000000000010','Scope League A','ci-scope-league-a',false),
    ('f2000000-0000-4000-8000-000000000021','f2000000-0000-4000-8000-000000000011','Scope League B','ci-scope-league-b',false);

  insert into public.seasons(id,league_id,name,season_number,is_public,status,recruitment_status)
  values
    ('f2000000-0000-4000-8000-000000000030','f2000000-0000-4000-8000-000000000020','Scope Season A',1,false,'registration_open','open'),
    ('f2000000-0000-4000-8000-000000000031','f2000000-0000-4000-8000-000000000021','Scope Season B',1,false,'registration_open','open');

  perform set_config('request.jwt.claim.sub','f2000000-0000-4000-8000-000000000001',true);
  perform set_config('request.jwt.claims','{"sub":"f2000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
  select public.get_admin_product_analytics_scope() into v_scope;

  if jsonb_array_length(v_scope->'locations')<>2
     or jsonb_array_length(v_scope->'leagues')<>2
     or jsonb_array_length(v_scope->'seasons')<>2
     or not (v_scope->'locations' @> jsonb_build_array('f2000000-0000-4000-8000-000000000010'))
     or not (v_scope->'locations' @> jsonb_build_array('f2000000-0000-4000-8000-000000000011')) then
    raise exception 'Global administrator did not receive both authorised competition scopes: %', v_scope;
  end if;
  if v_scope::text ~* 'email|full_name|phone|date_of_birth|user_id|profile' then
    raise exception 'Product analytics scope RPC returned unnecessary identity/profile data';
  end if;

  perform set_config('request.jwt.claim.sub','f2000000-0000-4000-8000-000000000002',true);
  perform set_config('request.jwt.claims','{"sub":"f2000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
  select public.get_admin_product_analytics_scope() into v_scope;

  if jsonb_array_length(v_scope->'locations')<>1
     or jsonb_array_length(v_scope->'leagues')<>1
     or jsonb_array_length(v_scope->'seasons')<>1
     or not (v_scope->'locations' @> jsonb_build_array('f2000000-0000-4000-8000-000000000010'))
     or (v_scope->'locations' @> jsonb_build_array('f2000000-0000-4000-8000-000000000011')) then
    raise exception 'Location administrator scope did not isolate its assigned location';
  end if;

  perform set_config('request.jwt.claim.sub','f2000000-0000-4000-8000-000000000003',true);
  perform set_config('request.jwt.claims','{"sub":"f2000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
  begin
    perform public.get_admin_product_analytics_scope();
    v_denied := false;
  exception when others then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Ordinary player accessed administrator product analytics scope'; end if;

  if pg_catalog.has_function_privilege('anon','public.get_admin_product_analytics_scope()','EXECUTE') then
    raise exception 'Anonymous role must not execute the product analytics scope RPC';
  end if;
  if not pg_catalog.has_function_privilege('authenticated','public.get_admin_product_analytics_scope()','EXECUTE') then
    raise exception 'Authenticated role must execute the permission-checked product analytics scope RPC';
  end if;

  raise notice 'Minimal product analytics scope and role isolation regressions passed';
end;
$product_analytics_scope$;

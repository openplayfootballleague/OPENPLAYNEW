-- Player self-service profile permission regression.
-- The confirmed Player Hub editor may replace the profile picture only.
-- All identity/contact/player fields use approved workflows.
do $profile_self_service_permissions$
declare
  v_profile_rls boolean;
  v_unexpected_update_columns text;
begin
  if has_table_privilege('authenticated', 'public.profiles', 'UPDATE') then
    raise exception 'Authenticated users must not have table-level UPDATE on profiles';
  end if;

  if not has_column_privilege('authenticated', 'public.profiles', 'avatar_path', 'UPDATE') then
    raise exception 'Players must be able to replace their own profile picture';
  end if;

  if has_column_privilege('authenticated', 'public.profiles', 'first_name', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'last_name', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'display_name', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'phone', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'preferred_position', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'date_of_birth', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'emergency_contact_name', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'emergency_contact_phone', 'UPDATE') then
    raise exception 'Only avatar_path may be updated directly by a player';
  end if;

  select string_agg(c.column_name, ', ' order by c.ordinal_position)
    into v_unexpected_update_columns
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'profiles'
    and c.column_name not in (
      'avatar_path'
    )
    and has_column_privilege('authenticated', 'public.profiles', c.column_name, 'UPDATE');

  if v_unexpected_update_columns is not null then
    raise exception 'Unexpected self-service profile UPDATE privileges: %',
      v_unexpected_update_columns;
  end if;

  select c.relrowsecurity
    into v_profile_rls
  from pg_class c
  where c.oid = 'public.profiles'::regclass;

  if coalesce(v_profile_rls, false) is not true then
    raise exception 'RLS must remain enabled on public.profiles';
  end if;

  if not exists (
    select 1
    from pg_policies p
    where p.schemaname = 'public'
      and p.tablename = 'profiles'
      and p.policyname = 'profiles_update_self'
      and p.cmd = 'UPDATE'
      and p.qual ilike '%auth.uid()%'
      and p.with_check ilike '%auth.uid()%'
      and p.qual not ilike '%has_platform_role%'
      and p.with_check not ilike '%has_platform_role%'
  ) then
    raise exception 'The owner/admin row-level UPDATE policy must remain present';
  end if;

  if not exists (
    select 1
    from pg_policies p
    where p.schemaname = 'storage'
      and p.tablename = 'objects'
      and p.policyname = 'profile_avatars_owner_insert'
      and p.cmd = 'INSERT'
      and 'authenticated' = any(p.roles)
      and p.with_check ilike '%storage.foldername(name)%'
      and p.with_check ilike '%auth.uid()%'
  ) then
    raise exception 'Avatar uploads must remain restricted to the authenticated owner folder';
  end if;

  if not exists (
    select 1
    from pg_policies p
    where p.schemaname = 'storage'
      and p.tablename = 'objects'
      and p.policyname = 'profile_avatars_owner_update'
      and p.cmd = 'UPDATE'
      and 'authenticated' = any(p.roles)
      and p.qual ilike '%storage.foldername(name)%'
      and p.qual ilike '%auth.uid()%'
      and p.with_check ilike '%storage.foldername(name)%'
      and p.with_check ilike '%auth.uid()%'
  ) then
    raise exception 'Avatar replacement must remain restricted to the authenticated owner folder';
  end if;

  if not exists (
    select 1
    from pg_policies p
    where p.schemaname = 'storage'
      and p.tablename = 'objects'
      and p.policyname = 'profile_avatars_owner_delete'
      and p.cmd = 'DELETE'
      and 'authenticated' = any(p.roles)
      and p.qual ilike '%storage.foldername(name)%'
      and p.qual ilike '%auth.uid()%'
  ) then
    raise exception 'Avatar cleanup must remain restricted to the authenticated owner folder';
  end if;

  raise notice 'Player self-service profile permission assertions passed';
end;
$profile_self_service_permissions$;

-- Two-authenticated-user Data API tests remain required:
-- 1. User A can update only their own avatar_path.
-- 2. User A cannot update identity, contact, DOB, emergency-contact or player fields.
-- 3. User A cannot update User B's profile row.
-- 4. User A can upload/replace/delete only objects in User A's UUID folder.
-- 5. User A cannot upload/replace/delete objects in User B's UUID folder.


-- Runtime ownership test: avatar replacement is allowed only on the caller's row.
do $profile_self_service_runtime$
declare
  v_user_a uuid := '00000000-0000-4000-8000-000000000301';
  v_user_b uuid := '00000000-0000-4000-8000-000000000302';
  v_rows integer;
  v_denied boolean := false;
begin
  insert into auth.users (id,aud,role,email,encrypted_password,raw_user_meta_data,email_confirmed_at,created_at,updated_at)
  values
    (v_user_a,'authenticated','authenticated','ci-profile-a@openplay.invalid','','{}'::jsonb,now(),now(),now()),
    (v_user_b,'authenticated','authenticated','ci-profile-b@openplay.invalid','','{}'::jsonb,now(),now(),now());

  insert into public.profiles(id,first_name,last_name,display_name,phone,preferred_position,created_at,updated_at)
  values
    (v_user_a,'Profile','Owner A','Owner A','+447700900301','Defender',now(),now()),
    (v_user_b,'Profile','Owner B','Owner B','+447700900302','Forward',now(),now())
  on conflict (id) do nothing;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_user_a::text,true);

  update public.profiles set avatar_path=v_user_a::text||'/avatar.png' where id=v_user_a;
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then
    raise exception 'A player must be able to update their own avatar path';
  end if;

  begin
    update public.profiles set first_name='Unauthorized' where id=v_user_a;
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then
    raise exception 'A player must not update their own identity fields directly';
  end if;

  update public.profiles set avatar_path=v_user_a::text||'/other-user.png' where id=v_user_b;
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'A player must not update another user's avatar path';
  end if;

  execute 'reset role';
end;
$profile_self_service_runtime$;

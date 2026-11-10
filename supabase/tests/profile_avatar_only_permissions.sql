-- Profile self-service security regression.
-- Run only in a disposable development/test database after the forward-only
-- profile permission correction. This is a catalog assertion, not a substitute
-- for authenticated positive/negative Data API tests with two real test users.
--
-- Expected contract:
--   * authenticated may update only profiles.avatar_path on their own row;
--   * no other profile column is client-writable;
--   * row-level ownership remains enforced;
--   * avatar object writes/deletes remain restricted to the caller's UUID folder.

do $profile_avatar_permissions$
declare
  v_profile_rls boolean;
  v_policy record;
begin
  if has_table_privilege('authenticated', 'public.profiles', 'UPDATE') then
    raise exception 'Authenticated users must not have table-level UPDATE on profiles';
  end if;

  if not has_column_privilege('authenticated', 'public.profiles', 'avatar_path', 'UPDATE') then
    raise exception 'Authenticated users must retain UPDATE on profiles.avatar_path';
  end if;

  if has_column_privilege('authenticated', 'public.profiles', 'first_name', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'last_name', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'display_name', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'date_of_birth', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'phone', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'emergency_contact_name', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'emergency_contact_phone', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'preferred_position', 'UPDATE') then
    raise exception 'Authenticated users retain UPDATE on a non-avatar profile field';
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
      and p.policyname = 'profiles_update_self_or_global_admin'
      and p.cmd = 'UPDATE'
      and p.qual ilike '%auth.uid()%'
      and p.with_check ilike '%auth.uid()%'
  ) then
    raise exception 'The owner/global-admin row-level UPDATE policy must remain present';
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

  raise notice 'Profile avatar-only permission assertions passed';
end;
$profile_avatar_permissions$;

-- Still required in an isolated database with two authenticated test users:
-- 1. User A updates their own avatar_path successfully.
-- 2. User A cannot update first_name, last_name, display_name, phone,
--    preferred_position, DOB or emergency contacts (permission denied).
-- 3. User A cannot update User B's avatar_path (zero rows or denied).
-- 4. Upload, replacement and deletion in User A's UUID folder succeed.
-- 5. Upload, replacement and deletion in User B's UUID folder fail.

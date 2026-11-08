-- Profile self-service privilege regression.
-- Run only in a disposable development/test database after replaying migrations.
--
-- The Player Hub edits the ordinary presentation/contact fields directly.
-- Sensitive identity and emergency-contact data remains admin-managed.
-- Admin corrections must use trusted SECURITY DEFINER RPCs.
--
-- Expected contract:
--   * authenticated has column-level UPDATE on the Player Hub editable fields;
--   * authenticated has no table-level UPDATE and no other column UPDATE grant;
--   * row-level ownership remains enforced;
--   * avatar object writes/deletes remain restricted to the caller's UUID folder.
-- This catalogue assertion is not a substitute for authenticated Data API tests.

do $profile_self_service_permissions$
declare
  v_profile_rls boolean;
  v_unexpected_column text;
begin
  if has_table_privilege('authenticated', 'public.profiles', 'UPDATE') then
    raise exception 'Authenticated users must not have table-level UPDATE on profiles';
  end if;

  if not has_column_privilege('authenticated', 'public.profiles', 'first_name', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'last_name', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'display_name', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'phone', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'preferred_position', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.profiles', 'avatar_path', 'UPDATE') then
    raise exception 'Player Hub self-service profile fields must retain column-level UPDATE grants';
  end if;

  select a.attname
    into v_unexpected_column
  from pg_attribute a
  where a.attrelid = 'public.profiles'::regclass
    and a.attnum > 0
    and not a.attisdropped
    and a.attname not in (
      'first_name',
      'last_name',
      'display_name',
      'phone',
      'preferred_position',
      'avatar_path'
    )
    and has_column_privilege('authenticated', 'public.profiles', a.attname, 'UPDATE')
  limit 1;

  if v_unexpected_column is not null then
    raise exception 'Authenticated users must not have UPDATE on protected profile column: %', v_unexpected_column;
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
      and p.policyname = 'profiles_update_self_or_admin'
      and p.cmd = 'UPDATE'
      and p.qual ilike '%auth.uid()%'
      and p.with_check ilike '%auth.uid()%'
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

  raise notice 'Profile self-service privilege and avatar ownership assertions passed';
end;
$profile_self_service_permissions$;

-- Still required in an isolated database with two authenticated test users:
-- 1. User A can update their own allowed profile fields.
-- 2. User A cannot update DOB, emergency contacts, id or timestamps.
-- 3. User A cannot update User B's profile (zero rows or denied).
-- 4. Upload, replacement and deletion in User A's UUID avatar folder succeed.
-- 5. Upload, replacement and deletion in User B's UUID folder fail.

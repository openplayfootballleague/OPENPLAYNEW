-- Player self-service profile permission regression.
-- The confirmed Player Hub editor may update identity/presentation fields and
-- avatar_path. DOB and emergency-contact fields remain admin-managed.
do $profile_self_service_permissions$
declare
  v_profile_rls boolean;
  v_unexpected_update_columns text;
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
    raise exception 'Confirmed Player Hub self-service profile fields must remain writable';
  end if;

  if has_column_privilege('authenticated', 'public.profiles', 'date_of_birth', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'emergency_contact_name', 'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles', 'emergency_contact_phone', 'UPDATE') then
    raise exception 'DOB and emergency-contact fields must remain admin-managed';
  end if;

  select string_agg(c.column_name, ', ' order by c.ordinal_position)
    into v_unexpected_update_columns
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'profiles'
    and c.column_name not in (
      'first_name', 'last_name', 'display_name', 'phone',
      'preferred_position', 'avatar_path'
    )
    and has_column_privilege('authenticated', 'public.profiles', c.column_name, 'UPDATE');

  if v_unexpected_update_columns is not null then
    raise exception 'Unexpected self-service profile UPDATE privileges: %',
      v_unexpected_update_columns;
  end if;

  select c.relrowsecurity into v_profile_rls
  from pg_class c where c.oid = 'public.profiles'::regclass;
  if coalesce(v_profile_rls, false) is not true then
    raise exception 'RLS must remain enabled on public.profiles';
  end if;

  if not exists (
    select 1 from pg_policies p
    where p.schemaname = 'public' and p.tablename = 'profiles'
      and p.policyname = 'profiles_update_self_or_admin' and p.cmd = 'UPDATE'
      and p.qual ilike '%auth.uid()%' and p.with_check ilike '%auth.uid()%'
  ) then
    raise exception 'The owner/admin row-level UPDATE policy must remain present';
  end if;

  if not exists (
    select 1 from pg_policies p
    where p.schemaname = 'storage' and p.tablename = 'objects'
      and p.policyname = 'profile_avatars_owner_insert' and p.cmd = 'INSERT'
      and 'authenticated' = any(p.roles)
      and p.with_check ilike '%storage.foldername(name)%'
      and p.with_check ilike '%auth.uid()%'
  ) then
    raise exception 'Avatar uploads must remain restricted to the authenticated owner folder';
  end if;

  if not exists (
    select 1 from pg_policies p
    where p.schemaname = 'storage' and p.tablename = 'objects'
      and p.policyname = 'profile_avatars_owner_update' and p.cmd = 'UPDATE'
      and 'authenticated' = any(p.roles)
      and p.qual ilike '%storage.foldername(name)%'
      and p.qual ilike '%auth.uid()%'
      and p.with_check ilike '%storage.foldername(name)%'
      and p.with_check ilike '%auth.uid()%'
  ) then
    raise exception 'Avatar replacement must remain restricted to the authenticated owner folder';
  end if;

  if not exists (
    select 1 from pg_policies p
    where p.schemaname = 'storage' and p.tablename = 'objects'
      and p.policyname = 'profile_avatars_owner_delete' and p.cmd = 'DELETE'
      and 'authenticated' = any(p.roles)
      and p.qual ilike '%storage.foldername(name)%'
      and p.qual ilike '%auth.uid()%'
  ) then
    raise exception 'Avatar cleanup must remain restricted to the authenticated owner folder';
  end if;

  raise notice 'Player self-service profile permission assertions passed';
end;
$profile_self_service_permissions$;

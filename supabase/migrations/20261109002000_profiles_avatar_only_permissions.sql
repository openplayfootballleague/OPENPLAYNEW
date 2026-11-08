-- Direct profile updates are limited to the avatar path.
-- Profile identity/contact fields are written through trusted server-side
-- workflows; the owner/admin RLS policy remains in place for avatar updates.

do $profile_column_privileges$
declare
  v_columns text;
begin
  select string_agg(format('%I', column_name), ', ' order by ordinal_position)
    into v_columns
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'profiles';

  if v_columns is not null then
    execute format(
      'revoke update (%s) on table public.profiles from public, anon, authenticated',
      v_columns
    );
  end if;
end;
$profile_column_privileges$;

revoke update on table public.profiles from public, anon, authenticated;
grant update (avatar_path) on table public.profiles to authenticated;

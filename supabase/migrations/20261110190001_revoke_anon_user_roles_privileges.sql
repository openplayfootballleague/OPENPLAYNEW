-- user_roles is authorization data, not a public discovery table.
-- Authenticated clients retain SELECT subject to the self/global-admin RLS policy;
-- all client write privileges and all anonymous/public table privileges are revoked.

revoke all privileges on table public.user_roles from public, anon, authenticated;
grant select on table public.user_roles to authenticated;

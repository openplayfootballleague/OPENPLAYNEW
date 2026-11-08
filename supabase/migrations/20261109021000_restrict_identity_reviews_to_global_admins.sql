-- Phase 1: identity-review evidence is visible only to global administrators.
-- League administrators retain their location-scoped operational permissions but
-- must not be able to read global player identity-review evidence directly.

drop policy if exists player_registration_reviews_admin_only
  on public.player_registration_reviews;

create policy player_registration_reviews_admin_only
  on public.player_registration_reviews
  for select
  to authenticated
  using (public.has_global_admin_role());

-- Identity-review rows are private to global administrators. Remove any
-- inherited/default grants to anonymous or PUBLIC while retaining the
-- authenticated SELECT grant required for the global-admin RLS policy.
revoke all privileges on table public.player_registration_reviews from anon, public;
grant select on table public.player_registration_reviews to authenticated;

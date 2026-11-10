-- Identity-review evidence is highly sensitive and is visible only to global administrators.
-- Location/league administrators may review ordinary registration queues, but must
-- not read cross-player identity matching evidence.

drop policy if exists player_registration_reviews_admin_only
  on public.player_registration_reviews;

create policy player_registration_reviews_admin_only
  on public.player_registration_reviews
  for select
  to authenticated
  using (public.has_global_admin_role());

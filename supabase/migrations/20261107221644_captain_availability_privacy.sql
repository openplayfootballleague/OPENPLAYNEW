-- Captains may see availability only for members of their own team in that fixture.
-- The previous fixture-level predicate exposed opponent availability to either captain.
drop policy if exists fixture_availability_select_player_captain_or_admin on public.fixture_availability;
create policy fixture_availability_select_player_captain_or_admin on public.fixture_availability
for select to authenticated
using (
  user_id = (select auth.uid())
  or public.has_platform_role()
  or exists (
    select 1
    from public.fixtures f
    join public.team_memberships captain
      on captain.user_id = (select auth.uid())
      and captain.is_captain = true
      and captain.status = 'active'
      and captain.season_team_id in (f.home_team_id, f.away_team_id)
    join public.team_memberships player_membership
      on player_membership.season_team_id = captain.season_team_id
      and player_membership.user_id = fixture_availability.user_id
      and player_membership.status = 'active'
    where f.id = fixture_availability.fixture_id
  )
);

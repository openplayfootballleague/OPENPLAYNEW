-- Location-scoped administrators must use the contextual admin RPCs.
-- RLS policies must not treat every league_admin as a global administrator.
-- Keep has_platform_role() for RPC authorization; use this narrower helper in RLS.

create or replace function public.has_global_admin_role()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.role in ('admin', 'super_admin')
  );
$$;

revoke all on function public.has_global_admin_role() from public, anon;
grant execute on function public.has_global_admin_role() to authenticated;

-- Public/member access remains unchanged. Private admin-wide access is global-only.
drop policy if exists locations_admin_manage on public.locations;
create policy locations_admin_manage on public.locations
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists locations_select_authenticated_active_or_admin on public.locations;
create policy locations_select_authenticated_active_or_admin on public.locations
for select to authenticated
using (is_active = true or (select public.has_global_admin_role()));

drop policy if exists leagues_admin_manage on public.leagues;
create policy leagues_admin_manage on public.leagues
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists leagues_select_authenticated_published_or_admin on public.leagues;
create policy leagues_select_authenticated_published_or_admin on public.leagues
for select to authenticated
using (is_published = true or (select public.has_global_admin_role()));

drop policy if exists seasons_admin_manage on public.seasons;
create policy seasons_admin_manage on public.seasons
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists seasons_select_authenticated_public_or_admin on public.seasons;
create policy seasons_select_authenticated_public_or_admin on public.seasons
for select to authenticated
using (
  (select public.has_global_admin_role())
  or (
    is_public = true
    and exists (
      select 1 from public.leagues l
      where l.id = seasons.league_id and l.is_published = true
    )
  )
);

drop policy if exists teams_admin_manage on public.teams;
create policy teams_admin_manage on public.teams
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists teams_select_authenticated_member_or_admin on public.teams;
create policy teams_select_authenticated_member_or_admin on public.teams
for select to authenticated
using (
  (select public.has_global_admin_role())
  or exists (
    select 1
    from public.season_teams st
    join public.team_memberships tm on tm.season_team_id = st.id
    where st.team_id = teams.id
      and tm.user_id = (select auth.uid())
      and tm.status = 'active'
  )
);

drop policy if exists season_teams_admin_manage on public.season_teams;
create policy season_teams_admin_manage on public.season_teams
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists season_teams_select_authenticated_public_or_member_or_admin on public.season_teams;
create policy season_teams_select_authenticated_public_or_member_or_admin on public.season_teams
for select to authenticated
using (
  (select public.has_global_admin_role())
  or (
    registration_status = 'approved'
    and exists (
      select 1
      from public.seasons s
      join public.leagues l on l.id = s.league_id
      where s.id = season_teams.season_id
        and s.is_public = true
        and l.is_published = true
    )
  )
  or public.is_active_team_member(id)
);

drop policy if exists fixtures_admin_manage on public.fixtures;
create policy fixtures_admin_manage on public.fixtures
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists fixtures_select_authenticated_public_or_member_or_admin on public.fixtures;
create policy fixtures_select_authenticated_public_or_member_or_admin on public.fixtures
for select to authenticated
using (
  (select public.has_global_admin_role())
  or exists (
    select 1
    from public.seasons s
    join public.leagues l on l.id = s.league_id
    where s.id = fixtures.season_id
      and s.is_public = true
      and l.is_published = true
  )
  or public.is_active_team_member(home_team_id)
  or public.is_active_team_member(away_team_id)
);

drop policy if exists fixture_results_admin_manage on public.fixture_results;
create policy fixture_results_admin_manage on public.fixture_results
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists fixture_results_select_authenticated_public_or_admin on public.fixture_results;
create policy fixture_results_select_authenticated_public_or_admin on public.fixture_results
for select to authenticated
using (
  (select public.has_global_admin_role())
  or exists (
    select 1
    from public.fixtures f
    join public.seasons s on s.id = f.season_id
    join public.leagues l on l.id = s.league_id
    where f.id = fixture_results.fixture_id
      and s.is_public = true
      and l.is_published = true
  )
);

drop policy if exists team_memberships_admin_manage on public.team_memberships;
create policy team_memberships_admin_manage on public.team_memberships
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists team_memberships_select_self_captain_or_admin on public.team_memberships;
create policy team_memberships_select_self_captain_or_admin on public.team_memberships
for select to authenticated
using (
  user_id = (select auth.uid())
  or public.is_active_team_captain(season_team_id)
  or (select public.has_global_admin_role())
);

drop policy if exists fixture_availability_admin_manage on public.fixture_availability;
create policy fixture_availability_admin_manage on public.fixture_availability
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists fixture_availability_select_player_captain_or_admin on public.fixture_availability;
create policy fixture_availability_select_player_captain_or_admin on public.fixture_availability
for select to authenticated
using (
  user_id = (select auth.uid())
  or (select public.has_global_admin_role())
  or exists (
    select 1
    from public.fixtures f
    join public.team_memberships captain
      on captain.user_id = (select auth.uid())
      and captain.is_captain = true
      and captain.status = 'active'
      and (
        captain.season_team_id = f.home_team_id
        or captain.season_team_id = f.away_team_id
      )
    join public.team_memberships player_membership
      on player_membership.season_team_id = captain.season_team_id
      and player_membership.user_id = fixture_availability.user_id
      and player_membership.status = 'active'
    where f.id = fixture_availability.fixture_id
  )
);

drop policy if exists fixture_team_sheets_admin_manage on public.fixture_team_sheets;
create policy fixture_team_sheets_admin_manage on public.fixture_team_sheets
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists fixture_team_sheets_select_team_or_admin on public.fixture_team_sheets;
create policy fixture_team_sheets_select_team_or_admin on public.fixture_team_sheets
for select to authenticated
using (
  (select public.has_global_admin_role())
  or public.is_active_team_member(season_team_id)
  or public.is_active_team_captain(season_team_id)
);

drop policy if exists fixture_team_sheet_players_admin_manage on public.fixture_team_sheet_players;
create policy fixture_team_sheet_players_admin_manage on public.fixture_team_sheet_players
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists fixture_team_sheet_players_select_team_or_admin on public.fixture_team_sheet_players;
create policy fixture_team_sheet_players_select_team_or_admin on public.fixture_team_sheet_players
for select to authenticated
using (
  (select public.has_global_admin_role())
  or exists (
    select 1
    from public.fixture_team_sheets ts
    where ts.id = fixture_team_sheet_players.team_sheet_id
      and public.is_active_team_member(ts.season_team_id)
  )
);

-- Personal identity, notification, review, transfer and role data are not
-- directly readable by location admins. Their scoped admin views use RPCs.
drop policy if exists notification_events_select_owner_or_admin on public.notification_events;
create policy notification_events_select_owner_or_admin on public.notification_events
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists notification_preferences_select_owner_or_admin on public.notification_preferences;
create policy notification_preferences_select_owner_or_admin on public.notification_preferences
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists player_registration_reviews_admin_only on public.player_registration_reviews;
create policy player_registration_reviews_admin_only on public.player_registration_reviews
for select to authenticated
using ((select public.has_global_admin_role()));

drop policy if exists players_select_self_or_admin on public.players;
create policy players_select_self_or_admin on public.players
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin on public.profiles
for select to authenticated
using (id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin on public.profiles
for update to authenticated
using (id = (select auth.uid()) or (select public.has_global_admin_role()))
with check (id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists season_registrations_admin_manage on public.season_registrations;
create policy season_registrations_admin_manage on public.season_registrations
for all to authenticated
using ((select public.has_global_admin_role()))
with check ((select public.has_global_admin_role()));

drop policy if exists season_registrations_select_self_or_admin on public.season_registrations;
create policy season_registrations_select_self_or_admin on public.season_registrations
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists transfer_requests_select_player_or_admin on public.transfer_requests;
create policy transfer_requests_select_player_or_admin on public.transfer_requests
for select to authenticated
using (player_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists player_transfer_requests_select_owner_or_admin on public.player_transfer_requests;
create policy player_transfer_requests_select_owner_or_admin on public.player_transfer_requests
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

drop policy if exists user_roles_select_self_or_admin on public.user_roles;
create policy user_roles_select_self_or_admin on public.user_roles
for select to authenticated
using (user_id = (select auth.uid()) or (select public.has_global_admin_role()));

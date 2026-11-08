-- Enforce location boundaries at the table-policy layer, not only in admin RPCs.
-- Location administrators must not inherit global read/write access merely because
-- has_platform_role() includes the league_admin role.

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

create or replace function public.can_administer_season(p_season_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_season_id is not null and exists (
    select 1
    from public.seasons s
    join public.leagues l on l.id = s.league_id
    where s.id = p_season_id
      and public.can_administer_location(l.location_id)
  );
$$;

create or replace function public.can_administer_season_team(p_season_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_season_team_id is not null and exists (
    select 1
    from public.season_teams st
    join public.seasons s on s.id = st.season_id
    join public.leagues l on l.id = s.league_id
    where st.id = p_season_team_id
      and public.can_administer_location(l.location_id)
  );
$$;

create or replace function public.can_administer_team(p_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_team_id is not null and exists (
    select 1
    from public.season_teams st
    join public.seasons s on s.id = st.season_id
    join public.leagues l on l.id = s.league_id
    where st.team_id = p_team_id
      and public.can_administer_location(l.location_id)
  );
$$;

create or replace function public.can_administer_fixture(p_fixture_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_fixture_id is not null and exists (
    select 1
    from public.fixtures f
    join public.seasons s on s.id = f.season_id
    join public.leagues l on l.id = s.league_id
    where f.id = p_fixture_id
      and public.can_administer_location(l.location_id)
  );
$$;

create or replace function public.can_administer_player(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and (
    exists (
      select 1
      from public.team_memberships tm
      join public.season_teams st on st.id = tm.season_team_id
      join public.seasons s on s.id = st.season_id
      join public.leagues l on l.id = s.league_id
      where tm.user_id = p_user_id
        and public.can_administer_location(l.location_id)
    )
    or exists (
      select 1
      from public.season_registrations sr
      join public.seasons s on s.id = sr.season_id
      join public.leagues l on l.id = s.league_id
      where sr.user_id = p_user_id
        and public.can_administer_location(l.location_id)
    )
  );
$$;

revoke all on function public.has_global_admin_role() from public, anon;
revoke all on function public.can_administer_season(uuid) from public, anon;
revoke all on function public.can_administer_season_team(uuid) from public, anon;
revoke all on function public.can_administer_team(uuid) from public, anon;
revoke all on function public.can_administer_fixture(uuid) from public, anon;
revoke all on function public.can_administer_player(uuid) from public, anon;
grant execute on function public.has_global_admin_role() to authenticated;
grant execute on function public.can_administer_season(uuid) to authenticated;
grant execute on function public.can_administer_season_team(uuid) to authenticated;
grant execute on function public.can_administer_team(uuid) to authenticated;
grant execute on function public.can_administer_fixture(uuid) to authenticated;
grant execute on function public.can_administer_player(uuid) to authenticated;

-- Profiles and player identities: a location admin sees only players connected
-- to a season/team at one of their assigned locations. Profile edits remain
-- self-service or global-admin only.
alter policy profiles_select_self_or_admin on public.profiles
using (
  id = (select auth.uid())
  or public.has_global_admin_role()
  or public.can_administer_player(id)
);
alter policy profiles_update_self_or_admin on public.profiles
using (id = (select auth.uid()) or public.has_global_admin_role())
with check (id = (select auth.uid()) or public.has_global_admin_role());

alter policy players_select_self_or_admin on public.players
using (
  user_id = (select auth.uid())
  or public.has_global_admin_role()
  or public.can_administer_player(user_id)
);

alter policy player_registration_reviews_admin_only on public.player_registration_reviews
using (public.has_global_admin_role());

alter policy user_roles_select_self_or_admin on public.user_roles
using (user_id = (select auth.uid()) or public.has_global_admin_role());

-- Public discovery remains public; unpublished/private competition data is
-- visible to global admins and only the location admins assigned to its venue.
alter policy locations_select_authenticated_active_or_admin on public.locations
using (
  is_active
  or public.has_global_admin_role()
  or public.can_administer_location(id)
);
alter policy locations_admin_manage on public.locations
using (public.has_global_admin_role() or public.can_administer_location(id))
with check (public.has_global_admin_role() or public.can_administer_location(id));

alter policy leagues_select_authenticated_published_or_admin on public.leagues
using (
  is_published
  or public.has_global_admin_role()
  or public.can_administer_location(location_id)
);
alter policy leagues_admin_manage on public.leagues
using (public.has_global_admin_role() or public.can_administer_location(location_id))
with check (public.has_global_admin_role() or public.can_administer_location(location_id));

alter policy seasons_select_authenticated_public_or_admin on public.seasons
using (
  public.has_global_admin_role()
  or public.can_administer_season(id)
  or (
    is_public = true
    and exists (
      select 1 from public.leagues l
      where l.id = seasons.league_id and l.is_published = true
    )
  )
);
alter policy seasons_admin_manage on public.seasons
using (public.has_global_admin_role() or public.can_administer_season(id))
with check (public.has_global_admin_role() or public.can_administer_season(id));

alter policy teams_select_authenticated_member_or_admin on public.teams
using (
  public.has_global_admin_role()
  or public.can_administer_team(id)
  or exists (
    select 1
    from public.season_teams st
    join public.team_memberships tm on tm.season_team_id = st.id
    where st.team_id = teams.id
      and tm.user_id = (select auth.uid())
      and tm.status = 'active'
  )
);
-- A teams row can be reused across seasons/locations. Only global admins may
-- mutate that cross-season identity directly; scoped team setup remains RPC-only.
alter policy teams_admin_manage on public.teams
using (public.has_global_admin_role())
with check (public.has_global_admin_role());

alter policy season_teams_select_authenticated_public_or_member_or_admin on public.season_teams
using (
  public.has_global_admin_role()
  or public.can_administer_season_team(id)
  or (
    registration_status = 'approved'
    and exists (
      select 1 from public.seasons s
      join public.leagues l on l.id = s.league_id
      where s.id = season_teams.season_id
        and s.is_public = true
        and l.is_published = true
    )
  )
  or public.is_active_team_member(id)
);
alter policy season_teams_admin_manage on public.season_teams
using (public.has_global_admin_role() or public.can_administer_season_team(id))
with check (public.has_global_admin_role() or public.can_administer_season_team(id));

alter policy season_registrations_select_self_or_admin on public.season_registrations
using (
  user_id = (select auth.uid())
  or public.has_global_admin_role()
  or public.can_administer_season(season_id)
);
alter policy season_registrations_admin_manage on public.season_registrations
using (public.has_global_admin_role() or public.can_administer_season(season_id))
with check (public.has_global_admin_role() or public.can_administer_season(season_id));

alter policy team_memberships_select_self_captain_or_admin on public.team_memberships
using (
  user_id = (select auth.uid())
  or public.is_active_team_captain(season_team_id)
  or public.has_global_admin_role()
  or public.can_administer_season_team(season_team_id)
);
alter policy team_memberships_admin_manage on public.team_memberships
using (public.has_global_admin_role() or public.can_administer_season_team(season_team_id))
with check (public.has_global_admin_role() or public.can_administer_season_team(season_team_id));

alter policy fixtures_select_authenticated_public_or_member_or_admin on public.fixtures
using (
  public.has_global_admin_role()
  or public.can_administer_fixture(id)
  or (
    exists (
      select 1 from public.seasons s
      join public.leagues l on l.id = s.league_id
      where s.id = fixtures.season_id
        and s.is_public = true
        and l.is_published = true
    )
  )
  or public.is_active_team_member(home_team_id)
  or public.is_active_team_member(away_team_id)
);
alter policy fixtures_admin_manage on public.fixtures
using (public.has_global_admin_role() or public.can_administer_fixture(id))
with check (public.has_global_admin_role() or public.can_administer_fixture(id));

alter policy fixture_results_select_authenticated_public_or_admin on public.fixture_results
using (
  public.has_global_admin_role()
  or public.can_administer_fixture(fixture_id)
  or exists (
    select 1 from public.fixtures f
    join public.seasons s on s.id = f.season_id
    join public.leagues l on l.id = s.league_id
    where f.id = fixture_results.fixture_id
      and s.is_public = true
      and l.is_published = true
  )
);
alter policy fixture_results_admin_manage on public.fixture_results
using (public.has_global_admin_role() or public.can_administer_fixture(fixture_id))
with check (public.has_global_admin_role() or public.can_administer_fixture(fixture_id));

alter policy fixture_team_sheets_select_team_or_admin on public.fixture_team_sheets
using (
  public.has_global_admin_role()
  or public.can_administer_fixture(fixture_id)
  or public.is_active_team_member(season_team_id)
  or public.is_active_team_captain(season_team_id)
);
alter policy fixture_team_sheets_admin_manage on public.fixture_team_sheets
using (public.has_global_admin_role() or public.can_administer_fixture(fixture_id))
with check (public.has_global_admin_role() or public.can_administer_fixture(fixture_id));

alter policy fixture_team_sheet_players_select_team_or_admin on public.fixture_team_sheet_players
using (
  public.has_global_admin_role()
  or exists (
    select 1
    from public.fixture_team_sheets ts
    where ts.id = fixture_team_sheet_players.team_sheet_id
      and (
        public.is_active_team_member(ts.season_team_id)
        or public.is_active_team_captain(ts.season_team_id)
        or public.can_administer_fixture(ts.fixture_id)
      )
  )
);
alter policy fixture_team_sheet_players_admin_manage on public.fixture_team_sheet_players
using (
  public.has_global_admin_role()
  or exists (
    select 1
    from public.fixture_team_sheets ts
    where ts.id = fixture_team_sheet_players.team_sheet_id
      and public.can_administer_fixture(ts.fixture_id)
  )
)
with check (
  public.has_global_admin_role()
  or exists (
    select 1
    from public.fixture_team_sheets ts
    where ts.id = fixture_team_sheet_players.team_sheet_id
      and public.can_administer_fixture(ts.fixture_id)
  )
);

-- Availability is one of the few tables with direct authenticated INSERT/UPDATE
-- grants. Keep player self-service and same-team captain reads, but scope admin
-- reads and writes to the assigned fixture location.
alter policy fixture_availability_select_player_captain_or_admin on public.fixture_availability
using (
  user_id = (select auth.uid())
  or public.has_global_admin_role()
  or public.can_administer_fixture(fixture_id)
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
alter policy fixture_availability_admin_manage on public.fixture_availability
using (public.has_global_admin_role() or public.can_administer_fixture(fixture_id))
with check (public.has_global_admin_role() or public.can_administer_fixture(fixture_id));

-- These tables contain identity-review, notification and transfer data without
-- an appropriate location context of their own. They remain owner/global-admin
-- readable; transfer requests are additionally scoped to their season teams.
alter policy notification_events_select_owner_or_admin on public.notification_events
using (user_id = (select auth.uid()) or public.has_global_admin_role());

alter policy notification_preferences_select_owner_or_admin on public.notification_preferences
using (user_id = (select auth.uid()) or public.has_global_admin_role());

alter policy player_transfer_requests_select_owner_or_admin on public.player_transfer_requests
using (
  user_id = (select auth.uid())
  or public.has_global_admin_role()
  or public.can_administer_season_team(source_season_team_id)
  or public.can_administer_season_team(destination_season_team_id)
);

alter policy transfer_requests_select_player_or_admin on public.transfer_requests
using (
  player_id = (select auth.uid())
  or public.has_global_admin_role()
  or public.can_administer_player(player_id)
  or public.can_administer_season_team(target_season_team_id)
  or exists (
    select 1
    from public.team_memberships tm
    where tm.id = transfer_requests.from_membership_id
      and public.can_administer_season_team(tm.season_team_id)
  )
);

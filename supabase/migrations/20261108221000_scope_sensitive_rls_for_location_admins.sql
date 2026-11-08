-- Tighten authenticated RLS reads so a location-scoped league_admin cannot
-- inherit platform-wide access from has_platform_role().
-- Privileged admin workspaces continue to use their location-checked RPCs.

drop policy if exists players_select_self_or_admin on public.players;
create policy players_select_self_or_global_admin on public.players
for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin'))
);

drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_global_admin on public.profiles
for select to authenticated
using (
  id = (select auth.uid())
  or exists (select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin'))
);

drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_global_admin on public.profiles
for update to authenticated
using (
  id = (select auth.uid())
  or exists (select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin'))
)
with check (
  id = (select auth.uid())
  or exists (select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin'))
);

drop policy if exists team_memberships_select_self_captain_or_admin on public.team_memberships;
create policy team_memberships_select_self_captain_or_scoped_admin on public.team_memberships
for select to authenticated
using (
  user_id = (select auth.uid())
  or public.is_active_team_captain(season_team_id)
  or exists (
    select 1 from public.season_teams st
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where st.id=team_memberships.season_team_id
      and public.can_administer_location(l.location_id)
  )
);

drop policy if exists fixture_team_sheets_select_team_or_admin on public.fixture_team_sheets;
create policy fixture_team_sheets_select_team_or_scoped_admin on public.fixture_team_sheets
for select to authenticated
using (
  public.is_active_team_member(season_team_id)
  or public.is_active_team_captain(season_team_id)
  or exists (
    select 1 from public.season_teams st
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where st.id=fixture_team_sheets.season_team_id
      and public.can_administer_location(l.location_id)
  )
);

drop policy if exists fixture_team_sheet_players_select_team_or_admin on public.fixture_team_sheet_players;
create policy fixture_team_sheet_players_select_team_or_scoped_admin on public.fixture_team_sheet_players
for select to authenticated
using (
  exists (
    select 1 from public.fixture_team_sheets ts
    where ts.id=fixture_team_sheet_players.team_sheet_id
      and (
        public.is_active_team_member(ts.season_team_id)
        or public.is_active_team_captain(ts.season_team_id)
        or exists (
          select 1 from public.season_teams st
          join public.seasons s on s.id=st.season_id
          join public.leagues l on l.id=s.league_id
          where st.id=ts.season_team_id
            and public.can_administer_location(l.location_id)
        )
      )
  )
);

drop policy if exists fixture_availability_select_player_captain_or_admin on public.fixture_availability;
create policy fixture_availability_select_player_captain_or_scoped_admin on public.fixture_availability
for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.fixtures f
    where f.id=fixture_availability.fixture_id
      and (
        public.is_active_team_captain(f.home_team_id)
        or public.is_active_team_captain(f.away_team_id)
        or exists (
          select 1 from public.seasons s
          join public.leagues l on l.id=s.league_id
          where s.id=f.season_id and public.can_administer_location(l.location_id)
        )
      )
  )
);

drop policy if exists fixture_availability_admin_manage on public.fixture_availability;
create policy fixture_availability_global_admin_manage on public.fixture_availability
for all to authenticated
using (exists (select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin')))
with check (exists (select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin')));

drop policy if exists notification_events_select_owner_or_admin on public.notification_events;
create policy notification_events_select_owner_or_global_admin on public.notification_events
for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin'))
);

drop policy if exists audit_log_admin_read on public.audit_log;
create policy audit_log_global_admin_read on public.audit_log
for select to authenticated
using (exists (select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin')));

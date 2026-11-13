-- Open Play RLS policies and authorization helpers.
-- Sensitive state changes remain server-side; these policies do not grant clients
-- direct control over roles, approvals, payments, results or audit history.

create or replace function public.has_platform_role()
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
      and ur.role in ('admin', 'super_admin', 'league_admin')
  );
$$;

create or replace function public.has_finance_access()
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
      and ur.role in ('admin', 'super_admin', 'finance_admin')
  );
$$;

create or replace function public.is_active_team_captain(p_season_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.team_memberships tm
    where tm.season_team_id = p_season_team_id
      and tm.user_id = (select auth.uid())
      and tm.is_captain = true
      and tm.status = 'active'
  );
$$;

create or replace function public.is_active_team_member(p_season_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.team_memberships tm
    where tm.season_team_id = p_season_team_id
      and tm.user_id = (select auth.uid())
      and tm.status = 'active'
  );
$$;

grant execute on function public.has_platform_role() to anon, authenticated;
grant execute on function public.has_finance_access() to authenticated;
grant execute on function public.is_active_team_captain(uuid) to anon, authenticated;
grant execute on function public.is_active_team_member(uuid) to anon, authenticated;

-- Profiles: private contact and emergency details are owner/admin only.
create policy profiles_select_self_or_admin on public.profiles
for select to authenticated
using (id = (select auth.uid()) or public.has_platform_role());

create policy profiles_insert_self on public.profiles
for insert to authenticated
with check (id = (select auth.uid()));

create policy profiles_update_self_or_admin on public.profiles
for update to authenticated
using (id = (select auth.uid()) or public.has_platform_role())
with check (id = (select auth.uid()) or public.has_platform_role());

-- Role grants are readable by the subject and administrators, never client-writable.
create policy user_roles_select_self_or_admin on public.user_roles
for select to authenticated
using (user_id = (select auth.uid()) or public.has_platform_role());

-- Public discovery is limited to active locations and published competitions.
create policy locations_select_active on public.locations
for select to anon, authenticated
using (is_active = true or public.has_platform_role());

create policy locations_admin_manage on public.locations
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

create policy leagues_select_published on public.leagues
for select to anon, authenticated
using (is_published = true or public.has_platform_role());

create policy leagues_admin_manage on public.leagues
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

create policy seasons_select_public on public.seasons
for select to anon, authenticated
using (
  public.has_platform_role()
  or (
    is_public = true
    and exists (
      select 1 from public.leagues l
      where l.id = seasons.league_id and l.is_published = true
    )
  )
);

create policy seasons_admin_manage on public.seasons
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

create policy teams_select_authenticated_member_or_admin on public.teams
for select to authenticated
using (
  public.has_platform_role()
  or exists (
    select 1
    from public.season_teams st
    join public.team_memberships tm on tm.season_team_id = st.id
    where st.team_id = teams.id
      and tm.user_id = (select auth.uid())
      and tm.status = 'active'
  )
);

create policy teams_admin_manage on public.teams
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

create policy season_teams_select_public_or_member on public.season_teams
for select to anon, authenticated
using (
  public.has_platform_role()
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

create policy season_teams_admin_manage on public.season_teams
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

-- Players can submit their own season registration; approval is admin-only.
create policy season_registrations_select_self_or_admin on public.season_registrations
for select to authenticated
using (user_id = (select auth.uid()) or public.has_platform_role());

create policy season_registrations_insert_self on public.season_registrations
for insert to authenticated
with check (user_id = (select auth.uid()) and status = 'pending');

create policy season_registrations_admin_manage on public.season_registrations
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

-- Membership details are visible to the player, their captain and administrators.
-- Roster changes are performed through trusted server-side workflows.
create policy team_memberships_select_self_captain_or_admin on public.team_memberships
for select to authenticated
using (
  user_id = (select auth.uid())
  or public.is_active_team_captain(season_team_id)
  or public.has_platform_role()
);

create policy team_memberships_admin_manage on public.team_memberships
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

-- Public fixtures/results are read-only; fixture administration is privileged.
create policy fixtures_select_public_or_member on public.fixtures
for select to anon, authenticated
using (
  public.has_platform_role()
  or exists (
    select 1 from public.seasons s
    join public.leagues l on l.id = s.league_id
    where s.id = fixtures.season_id and s.is_public = true and l.is_published = true
  )
  or public.is_active_team_member(home_team_id)
  or public.is_active_team_member(away_team_id)
);

create policy fixtures_admin_manage on public.fixtures
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

create policy fixture_results_select_public_or_member on public.fixture_results
for select to anon, authenticated
using (
  exists (
    select 1 from public.fixtures f
    join public.seasons s on s.id = f.season_id
    join public.leagues l on l.id = s.league_id
    where f.id = fixture_results.fixture_id
      and s.is_public = true and l.is_published = true
  )
  or public.has_platform_role()
);

create policy fixture_results_admin_manage on public.fixture_results
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

create policy fixture_team_sheets_select_team_or_admin on public.fixture_team_sheets
for select to authenticated
using (
  public.has_platform_role()
  or public.is_active_team_member(season_team_id)
  or public.is_active_team_captain(season_team_id)
);

create policy fixture_team_sheets_admin_manage on public.fixture_team_sheets
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

create policy fixture_team_sheet_players_select_team_or_admin on public.fixture_team_sheet_players
for select to authenticated
using (
  public.has_platform_role()
  or exists (
    select 1 from public.fixture_team_sheets ts
    where ts.id = fixture_team_sheet_players.team_sheet_id
      and public.is_active_team_member(ts.season_team_id)
  )
);

create policy fixture_team_sheet_players_admin_manage on public.fixture_team_sheet_players
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

create policy fixture_availability_select_player_captain_or_admin on public.fixture_availability
for select to authenticated
using (
  user_id = (select auth.uid())
  or public.has_platform_role()
  or exists (
    select 1 from public.fixtures f
    where f.id = fixture_availability.fixture_id
      and (
        public.is_active_team_captain(f.home_team_id)
        or public.is_active_team_captain(f.away_team_id)
      )
  )
);

create policy fixture_availability_insert_self on public.fixture_availability
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.fixtures f
    where f.id = fixture_availability.fixture_id
      and (public.is_active_team_member(f.home_team_id) or public.is_active_team_member(f.away_team_id))
  )
);

create policy fixture_availability_update_self on public.fixture_availability
for update to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.fixtures f
    where f.id = fixture_availability.fixture_id
      and (public.is_active_team_member(f.home_team_id) or public.is_active_team_member(f.away_team_id))
  )
);

create policy fixture_availability_admin_manage on public.fixture_availability
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

-- Transfers: players can request and inspect their own move; approval stays privileged.
create policy transfer_requests_select_player_or_admin on public.transfer_requests
for select to authenticated
using (player_id = (select auth.uid()) or public.has_platform_role());

create policy transfer_requests_insert_self on public.transfer_requests
for insert to authenticated
with check (player_id = (select auth.uid()) and status = 'pending');

create policy transfer_requests_admin_manage on public.transfer_requests
for all to authenticated
using (public.has_platform_role())
with check (public.has_platform_role());

-- Finance data is not public. Captains can inspect their own team's payment status.
create policy season_fee_configs_admin_only on public.season_fee_configs
for all to authenticated
using (public.has_finance_access())
with check (public.has_finance_access());

create policy payment_records_select_captain_or_admin on public.payment_records
for select to authenticated
using (
  public.has_finance_access()
  or public.is_active_team_captain(season_team_id)
);

-- Payment writes are service-side only; finance users receive read access above.

create policy notification_events_select_owner_or_admin on public.notification_events
for select to authenticated
using (user_id = (select auth.uid()) or public.has_platform_role());

create policy audit_log_admin_read on public.audit_log
for select to authenticated
using (public.has_platform_role());

-- No client insert/update/delete policies are intentionally granted for:
-- user_roles, audit_log, payment_records state transitions, notification delivery,
-- fixture results, or captain approvals. Trusted server-side code owns those actions.

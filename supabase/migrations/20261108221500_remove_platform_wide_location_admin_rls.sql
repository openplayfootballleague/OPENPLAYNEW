-- Non-recursive global-admin predicate for policies on user_roles itself.
create or replace function public.has_global_admin_role()
returns boolean language sql stable security definer set search_path=''
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin')
  );
$$;
revoke all on function public.has_global_admin_role() from public,anon;
grant execute on function public.has_global_admin_role() to authenticated;
-- Remove the implicit platform-wide access granted by has_platform_role()
-- from permissive ALL policies. These policies also participate in SELECT
-- and otherwise override the narrower read policies introduced previously.
do $global_admin_manage_policies$
declare
  v_table text;
  v_policy text;
  v_tables text[] := array[
    'fixture_results','fixture_team_sheet_players','fixture_team_sheets',
    'fixtures','leagues','locations','season_registrations','season_teams',
    'seasons','team_memberships','teams','transfer_requests'
  ];
begin
  foreach v_table in array v_tables loop
    v_policy := v_table || '_admin_manage';
    if exists (select 1 from pg_catalog.pg_policies where schemaname='public' and tablename=v_table and policyname=v_policy) then
      execute format('drop policy %I on public.%I',v_policy,v_table);
      execute format(
        'create policy %I on public.%I for all to authenticated using (exists (select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in (''admin'',''super_admin''))) with check (exists (select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in (''admin'',''super_admin'')))',
        v_policy,v_table
      );
    end if;
  end loop;
end;
$$;

-- Competition records may be read by the public when published, by active
-- team members, or by admins assigned to the record's location.
drop policy if exists fixture_results_select_authenticated_public_or_admin on public.fixture_results;
create policy fixture_results_select_authenticated_public_or_scoped_admin on public.fixture_results
for select to authenticated using (
  exists (
    select 1 from public.fixtures f
    join public.seasons s on s.id=f.season_id
    join public.leagues l on l.id=s.league_id
    where f.id=fixture_results.fixture_id and (
      (s.is_public=true and l.is_published=true)
      or public.can_administer_location(l.location_id)
      or public.is_active_team_member(f.home_team_id)
      or public.is_active_team_member(f.away_team_id)
    )
  )
);

drop policy if exists fixtures_select_authenticated_public_or_member_or_admin on public.fixtures;
create policy fixtures_select_authenticated_public_or_member_or_scoped_admin on public.fixtures
for select to authenticated using (
  public.is_active_team_member(home_team_id)
  or public.is_active_team_member(away_team_id)
  or exists (
    select 1 from public.seasons s join public.leagues l on l.id=s.league_id
    where s.id=fixtures.season_id and (
      (s.is_public=true and l.is_published=true)
      or public.can_administer_location(l.location_id)
    )
  )
);

drop policy if exists leagues_select_authenticated_published_or_admin on public.leagues;
create policy leagues_select_authenticated_published_or_scoped_admin on public.leagues
for select to authenticated using (is_published=true or public.can_administer_location(location_id));

drop policy if exists locations_select_authenticated_active_or_admin on public.locations;
create policy locations_select_authenticated_active_or_scoped_admin on public.locations
for select to authenticated using (is_active=true or public.can_administer_location(id));

drop policy if exists season_teams_select_authenticated_public_or_member_or_admin on public.season_teams;
create policy season_teams_select_authenticated_public_or_member_or_scoped_admin on public.season_teams
for select to authenticated using (
  public.is_active_team_member(id)
  or (registration_status='approved' and exists (
    select 1 from public.seasons s join public.leagues l on l.id=s.league_id
    where s.id=season_teams.season_id and (
      (s.is_public=true and l.is_published=true)
      or public.can_administer_location(l.location_id)
    )
  ))
);

drop policy if exists seasons_select_authenticated_public_or_admin on public.seasons;
create policy seasons_select_authenticated_public_or_scoped_admin on public.seasons
for select to authenticated using (
  (is_public=true and exists(select 1 from public.leagues l where l.id=seasons.league_id and l.is_published=true))
  or exists(select 1 from public.leagues l where l.id=seasons.league_id and public.can_administer_location(l.location_id))
);

drop policy if exists teams_select_authenticated_member_or_admin on public.teams;
create policy teams_select_authenticated_member_or_scoped_admin on public.teams
for select to authenticated using (
  exists (
    select 1 from public.season_teams st
    join public.team_memberships tm on tm.season_team_id=st.id
    where st.team_id=teams.id and tm.user_id=(select auth.uid()) and tm.status='active'
  )
  or exists (
    select 1 from public.season_teams st
    join public.seasons s on s.id=st.season_id
    join public.leagues l on l.id=s.league_id
    where st.team_id=teams.id and public.can_administer_location(l.location_id)
  )
);

-- Personal workflow/role tables are self-visible or global-admin-only.
drop policy if exists notification_preferences_select_owner_or_admin on public.notification_preferences;
create policy notification_preferences_select_owner_or_global_admin on public.notification_preferences
for select to authenticated using (
  user_id=(select auth.uid())
  or exists(select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin'))
);

drop policy if exists player_registration_reviews_admin_only on public.player_registration_reviews;
create policy player_registration_reviews_global_admin_only on public.player_registration_reviews
for select to authenticated using (
  exists(select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin'))
);

drop policy if exists player_transfer_requests_select_owner_or_admin on public.player_transfer_requests;
create policy player_transfer_requests_select_owner_or_global_admin on public.player_transfer_requests
for select to authenticated using (
  user_id=(select auth.uid())
  or exists(select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin'))
);

drop policy if exists transfer_requests_select_player_or_admin on public.transfer_requests;
create policy transfer_requests_select_player_or_global_admin on public.transfer_requests
for select to authenticated using (
  player_id=(select auth.uid())
  or exists(select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin'))
);

drop policy if exists user_roles_select_self_or_admin on public.user_roles;
create policy user_roles_select_self_or_global_admin on public.user_roles
for select to authenticated using (
  user_id=(select auth.uid()) or public.has_global_admin_role()
);

drop policy if exists season_registrations_select_self_or_admin on public.season_registrations;
create policy season_registrations_select_self_or_global_admin on public.season_registrations
for select to authenticated using (
  user_id=(select auth.uid())
  or exists(select 1 from public.user_roles ur where ur.user_id=(select auth.uid()) and ur.role in ('admin','super_admin'))
);

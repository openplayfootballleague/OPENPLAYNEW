-- Open Play integrity and query-performance hardening.
-- Rejected join requests remain distinct from players who voluntarily leave.
alter type public.membership_status add value if not exists 'rejected';

-- Cover every foreign key reported by the Supabase performance advisor.
create index if not exists audit_log_actor_user_id_idx on public.audit_log(actor_user_id);
create index if not exists fixture_availability_user_id_idx on public.fixture_availability(user_id);
create index if not exists fixture_results_confirmed_by_idx on public.fixture_results(confirmed_by);
create index if not exists fixture_team_sheet_players_user_id_idx on public.fixture_team_sheet_players(user_id);
create index if not exists fixture_team_sheets_season_team_id_idx on public.fixture_team_sheets(season_team_id);
create index if not exists fixture_team_sheets_submitted_by_idx on public.fixture_team_sheets(submitted_by);
create index if not exists fixtures_away_team_id_idx on public.fixtures(away_team_id);
create index if not exists fixtures_home_team_id_idx on public.fixtures(home_team_id);
create index if not exists fixtures_venue_id_idx on public.fixtures(venue_id);
create index if not exists leagues_location_id_idx on public.leagues(location_id);
create index if not exists notification_events_user_id_idx on public.notification_events(user_id);
create index if not exists payment_records_fixture_id_idx on public.payment_records(fixture_id);
create index if not exists player_registration_reviews_reviewed_by_idx on public.player_registration_reviews(reviewed_by);
create index if not exists season_fee_configs_changed_by_idx on public.season_fee_configs(changed_by);
create index if not exists season_registrations_reviewed_by_idx on public.season_registrations(reviewed_by);
create index if not exists season_registrations_user_id_idx on public.season_registrations(user_id);
create index if not exists season_teams_approved_by_idx on public.season_teams(approved_by);
create index if not exists teams_created_by_idx on public.teams(created_by);
create index if not exists transfer_requests_from_membership_id_idx on public.transfer_requests(from_membership_id);
create index if not exists transfer_requests_player_id_idx on public.transfer_requests(player_id);
create index if not exists transfer_requests_reviewed_by_idx on public.transfer_requests(reviewed_by);
create index if not exists transfer_requests_target_season_team_id_idx on public.transfer_requests(target_season_team_id);
create index if not exists user_roles_granted_by_idx on public.user_roles(granted_by);

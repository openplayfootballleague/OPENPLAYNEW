-- Grant only the table privileges required by the client application.
-- RLS remains the row-level authorization boundary for every application table.
grant usage on schema public to anon, authenticated;

-- Public browsing: policies limit these reads to active locations and published
-- competitions/seasons/teams/fixtures/results.
grant select on table
  public.locations,
  public.leagues,
  public.seasons,
  public.season_teams,
  public.fixtures,
  public.fixture_results
to anon;

-- Signed-in screens read private records through RLS-scoped policies.
-- Tables without a matching SELECT policy remain invisible under RLS.
grant select on all tables in schema public to authenticated;

-- Direct client writes are limited to the two profile/availability workflows
-- which have explicit self-only RLS policies.
grant update on table public.profiles to authenticated;
grant insert, update on table public.fixture_availability to authenticated;
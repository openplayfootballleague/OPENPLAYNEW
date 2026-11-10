export type AnalyticsLocation = { id: string; name: string; town: string };
export type AnalyticsSeason = { id: string; league_id: string; location_id?: string; name: string; status: string };
export type AnalyticsTeam = { id: string; season_id: string; name: string; registration_status: string; member_count: number };
export type AnalyticsFixture = {
  id: string;
  season_id: string;
  gameweek: number;
  status: string;
  home_score: number | null;
  away_score: number | null;
};
export type AnalyticsSetup = {
  locations: AnalyticsLocation[];
  leagues: Array<{ id: string; location_id: string; name: string }>;
  seasons: AnalyticsSeason[];
  season_teams: AnalyticsTeam[];
  fixtures: AnalyticsFixture[];
};
export type AnalyticsDashboardCounts = {
  pending_player_reviews: number;
  pending_team_applications: number;
  pending_membership_requests: number;
  open_seasons: number;
};
export type AnalyticsFilters = { locationId: string; leagueId: string; seasonId: string };
export type AnalyticsOverview = {
  locations: number;
  leagues: number;
  seasons: number;
  openSeasons: number;
  approvedTeams: number;
  squadMemberships: number;
  fixtures: number;
  publishedResults: number;
  goals: number;
  pendingPlayerReviews: number;
  pendingTeamApplications: number;
  pendingMembershipRequests: number;
};
export type AnalyticsLocationComparison = {
  locationId: string;
  locationName: string;
  seasons: number;
  approvedTeams: number;
  squadMemberships: number;
  fixtures: number;
  publishedResults: number;
  goals: number;
};
export type FinanceSummaryRow = {
  charges_pence: number | string;
  payments_pence: number | string;
  refunds_pence: number | string;
  credits_pence: number | string;
  fines_pence: number | string;
  outstanding_pence: number | string;
};
export type FinanceTotals = {
  chargesPence: number;
  paymentsPence: number;
  refundsPence: number;
  creditsPence: number;
  finesPence: number;
  outstandingPence: number;
};

function matchesFilters(season: AnalyticsSeason, filters: AnalyticsFilters, locationByLeague: Map<string, string>): boolean {
  const locationId = season.location_id ?? locationByLeague.get(season.league_id);
  return (!filters.locationId || locationId === filters.locationId)
    && (!filters.leagueId || season.league_id === filters.leagueId)
    && (!filters.seasonId || season.id === filters.seasonId);
}

function isPublishedResult(fixture: AnalyticsFixture): boolean {
  return fixture.status === "completed" && fixture.home_score !== null && fixture.away_score !== null;
}

export function buildAnalyticsOverview(
  setup: AnalyticsSetup,
  dashboard: AnalyticsDashboardCounts,
  contextualFixtures: AnalyticsFixture[],
  filters: AnalyticsFilters,
): AnalyticsOverview {
  const locationByLeague = new Map(setup.leagues.map((league) => [league.id, league.location_id]));
  const seasons = setup.seasons.filter((season) => matchesFilters(season, filters, locationByLeague));
  const seasonIds = new Set(seasons.map((season) => season.id));
  const teams = setup.season_teams.filter((team) => seasonIds.has(team.season_id) && team.registration_status === "approved");
  const results = contextualFixtures.filter(isPublishedResult);
  return {
    locations: filters.locationId ? 1 : setup.locations.length,
    leagues: setup.leagues.filter((league) => (!filters.locationId || league.location_id === filters.locationId) && (!filters.leagueId || league.id === filters.leagueId)).length,
    seasons: seasons.length,
    openSeasons: Number(dashboard.open_seasons ?? 0),
    approvedTeams: teams.length,
    squadMemberships: teams.reduce((total, team) => total + Math.max(0, Number(team.member_count) || 0), 0),
    fixtures: contextualFixtures.length,
    publishedResults: results.length,
    goals: results.reduce((total, fixture) => total + Number(fixture.home_score ?? 0) + Number(fixture.away_score ?? 0), 0),
    pendingPlayerReviews: Number(dashboard.pending_player_reviews ?? 0),
    pendingTeamApplications: Number(dashboard.pending_team_applications ?? 0),
    pendingMembershipRequests: Number(dashboard.pending_membership_requests ?? 0),
  };
}

export function buildLocationComparisons(
  setup: AnalyticsSetup,
  filters: Pick<AnalyticsFilters, "leagueId" | "seasonId"> = { leagueId: "", seasonId: "" },
): AnalyticsLocationComparison[] {
  return setup.locations.flatMap((location) => {
    const seasons = setup.seasons.filter((season) =>
      season.location_id === location.id
      && (!filters.leagueId || season.league_id === filters.leagueId)
      && (!filters.seasonId || season.id === filters.seasonId),
    );
    // A location outside the selected league/season is not a zero-performance
    // location; exclude it from this comparison rather than implying it had no activity.
    if (seasons.length === 0) return [];
    const seasonIds = new Set(seasons.map((season) => season.id));
    const teams = setup.season_teams.filter((team) =>
      seasonIds.has(team.season_id) && team.registration_status === "approved",
    );
    const fixtures = setup.fixtures.filter((fixture) => seasonIds.has(fixture.season_id));
    const results = fixtures.filter(isPublishedResult);
    return [{
      locationId: location.id,
      locationName: location.name,
      seasons: seasons.length,
      approvedTeams: teams.length,
      squadMemberships: teams.reduce((total, team) => total + Math.max(0, Number(team.member_count) || 0), 0),
      fixtures: fixtures.length,
      publishedResults: results.length,
      goals: results.reduce((total, fixture) => total + Number(fixture.home_score ?? 0) + Number(fixture.away_score ?? 0), 0),
    }];
  });
}

export function aggregateFinanceTotals(rows: FinanceSummaryRow[]): FinanceTotals {
  const sum = (key: keyof FinanceSummaryRow) => rows.reduce((total, row) => total + (Number(row[key]) || 0), 0);
  return {
    chargesPence: sum("charges_pence"),
    paymentsPence: sum("payments_pence"),
    refundsPence: sum("refunds_pence"),
    creditsPence: sum("credits_pence"),
    finesPence: sum("fines_pence"),
    outstandingPence: sum("outstanding_pence"),
  };
}

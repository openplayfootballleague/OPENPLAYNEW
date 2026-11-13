export type AnalyticsLocation = { id: string; name: string; town: string };
export type AnalyticsSeason = { id: string; league_id: string; location_id: string; name: string; status: string };
export type AnalyticsTeam = { id: string; season_id: string; name: string; registration_status: string; member_count: number };
export type AnalyticsFixture = {
  id: string;
  season_id: string;
  gameweek: number;
  status: string;
  home_score: number | null;
  away_score: number | null;
  scheduled_at?: string | null;
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
export type AnalyticsFilters = { locationId: string; leagueId: string; seasonId: string; fromDate: string; toDate: string };
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

function matchesFilters(season: AnalyticsSeason, filters: AnalyticsFilters): boolean {
  return (!filters.locationId || season.location_id === filters.locationId)
    && (!filters.leagueId || season.league_id === filters.leagueId)
    && (!filters.seasonId || season.id === filters.seasonId);
}

function isWithinDateRange(fixture: AnalyticsFixture, filters: Pick<AnalyticsFilters, "fromDate" | "toDate">): boolean {
  if (!filters.fromDate && !filters.toDate) return true;
  if (!fixture.scheduled_at) return false;
  const scheduledAt = new Date(fixture.scheduled_at);
  if (Number.isNaN(scheduledAt.getTime())) return false;
  if (filters.fromDate) {
    const from = new Date(`${filters.fromDate}T00:00:00`);
    if (Number.isNaN(from.getTime()) || scheduledAt < from) return false;
  }
  if (filters.toDate) {
    const to = new Date(`${filters.toDate}T23:59:59.999`);
    if (Number.isNaN(to.getTime()) || scheduledAt > to) return false;
  }
  return true;
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
  const seasons = setup.seasons.filter((season) => matchesFilters(season, filters));
  const seasonIds = new Set(seasons.map((season) => season.id));
  const teams = setup.season_teams.filter((team) => seasonIds.has(team.season_id) && team.registration_status === "approved");
  const fixtures = contextualFixtures.filter((fixture) => isWithinDateRange(fixture, filters));
  const results = fixtures.filter(isPublishedResult);
  return {
    locations: filters.locationId ? 1 : setup.locations.length,
    leagues: setup.leagues.filter((league) => (!filters.locationId || league.location_id === filters.locationId) && (!filters.leagueId || league.id === filters.leagueId)).length,
    seasons: seasons.length,
    openSeasons: Number(dashboard.open_seasons ?? 0),
    approvedTeams: teams.length,
    squadMemberships: teams.reduce((total, team) => total + Math.max(0, Number(team.member_count) || 0), 0),
    fixtures: fixtures.length,
    publishedResults: results.length,
    goals: results.reduce((total, fixture) => total + Number(fixture.home_score ?? 0) + Number(fixture.away_score ?? 0), 0),
    pendingPlayerReviews: Number(dashboard.pending_player_reviews ?? 0),
    pendingTeamApplications: Number(dashboard.pending_team_applications ?? 0),
    pendingMembershipRequests: Number(dashboard.pending_membership_requests ?? 0),
  };
}

export function buildLocationComparisons(
  setup: AnalyticsSetup,
  filters: Partial<AnalyticsFilters> = {},
): AnalyticsLocationComparison[] {
  return setup.locations.flatMap((location) => {
    const seasons = setup.seasons.filter((season) =>
      season.location_id === location.id
      && (!filters.locationId || location.id === filters.locationId)
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
    const fixtures = setup.fixtures.filter((fixture) => seasonIds.has(fixture.season_id) && isWithinDateRange(fixture, { fromDate: filters.fromDate ?? "", toDate: filters.toDate ?? "" }));
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

/** Quote CSV values and neutralise spreadsheet formula prefixes in user-controlled text. */
export function safeCsvCell(value: string | number): string {
  const text = String(value);
  // Numeric values are trusted data, not formulas. Preserve negative numbers
  // as numbers in spreadsheet imports; neutralise formula-like text only.
  const formulaLikeText = typeof value === "string"
    && /^[\s\uFEFF]*[=+\-@]/u.test(text);
  // Strip a leading UTF-8 BOM before adding the spreadsheet text marker. A BOM
  // between the marker and formula can otherwise survive round-tripping.
  const normalised = text.replace(/^\uFEFF+/u, "");
  const safe = formulaLikeText ? "'" + normalised : text;
  return '"' + safe.replaceAll('"', '""') + '"';
}

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
  completedFixtures: number;
  publishedResults: number;
  resultsCoveragePercent: number | null;
  goals: number;
  goalsPerResult: number | null;
};
export type CompetitionTeamRow = {
  position: number;
  team_id: string;
  name: string;
  played: number;
  wins: number;
  draws: number;
  losses: number;
  goals_for: number;
  goals_against: number;
  goal_difference: number;
  points: number;
  clean_sheets: number;
};
export type CompetitionTeamPerformance = CompetitionTeamRow & {
  winRatePercent: number | null;
  pointsPerGame: number | null;
};

export function buildCompetitionTeamPerformance(
  teams: CompetitionTeamRow[],
): CompetitionTeamPerformance[] {
  return teams.map((team) => ({
    ...team,
    winRatePercent: team.played > 0
      ? Math.round(team.wins / team.played * 1000) / 10
      : null,
    pointsPerGame: team.played > 0
      ? Math.round(team.points / team.played * 100) / 100
      : null,
  }));
}

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
  // Enforce the selected season scope in the pure aggregation layer as well as
  // in the RPC. This prevents an over-broad or stale fixture response leaking
  // activity from another season into the report.
  const fixtures = contextualFixtures.filter((fixture) =>
    seasonIds.has(fixture.season_id) && isWithinDateRange(fixture, filters),
  );
  const results = fixtures.filter(isPublishedResult);
  const scopedLocationIds = new Set(seasons.map((season) => season.location_id));
  const scopedLeagueIds = new Set(seasons.map((season) => season.league_id));
  return {
    locations: filters.locationId ? (scopedLocationIds.has(filters.locationId) ? 1 : 0) : scopedLocationIds.size,
    leagues: scopedLeagueIds.size,
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
    const completedFixtures = fixtures.filter((fixture) => fixture.status === "completed");
    const results = completedFixtures.filter(isPublishedResult);
    const goals = results.reduce((total, fixture) => total + Number(fixture.home_score ?? 0) + Number(fixture.away_score ?? 0), 0);
    return [{
      locationId: location.id,
      locationName: location.name,
      seasons: seasons.length,
      approvedTeams: teams.length,
      squadMemberships: teams.reduce((total, team) => total + Math.max(0, Number(team.member_count) || 0), 0),
      fixtures: fixtures.length,
      completedFixtures: completedFixtures.length,
      publishedResults: results.length,
      resultsCoveragePercent: completedFixtures.length > 0
        ? Math.round(results.length / completedFixtures.length * 1000) / 10
        : null,
      goals,
      goalsPerResult: results.length > 0 ? Math.round(goals / results.length * 100) / 100 : null,
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



export type RegistrationConversionExportRow = {
  bucket_date: string;
  player_registered: number | string | null;
  player_pending_review: number | string | null;
  player_rejected: number | string | null;
  team_applications: number | string;
  team_approved: number | string;
  team_rejected: number | string;
  team_pending: number | string;
  membership_requests: number | string;
  membership_accepted: number | string;
  membership_rejected: number | string;
  membership_pending: number | string;
};

/** Build a privacy-safe, complete registration conversion CSV section from aggregate cohort rows. */
export function buildRegistrationConversionExportRows(
  rows: RegistrationConversionExportRow[],
): Array<Array<string | number>> {
  if (rows.length === 0) return [];
  return [
    [
      "Created date",
      "Player registrations",
      "Player pending review",
      "Player rejected",
      "Team applications",
      "Teams approved",
      "Teams rejected",
      "Teams pending",
      "Membership requests",
      "Memberships accepted",
      "Memberships rejected",
      "Memberships pending",
    ],
    ...rows.map((row) => [
      row.bucket_date,
      row.player_registered === null ? "" : Number(row.player_registered),
      row.player_pending_review === null ? "" : Number(row.player_pending_review),
      row.player_rejected === null ? "" : Number(row.player_rejected),
      Number(row.team_applications),
      Number(row.team_approved),
      Number(row.team_rejected),
      Number(row.team_pending),
      Number(row.membership_requests),
      Number(row.membership_accepted),
      Number(row.membership_rejected),
      Number(row.membership_pending),
    ]),
  ];
}

/** Quote CSV values and neutralise spreadsheet formula prefixes in user-controlled text. */
export function safeCsvCell(value: string | number): string {
  const text = String(value);
  // Numeric values are trusted data, not formulas. Preserve negative numbers
  // as numbers in spreadsheet imports; neutralise formula-like text only.
  const formulaLikeText = typeof value === "string"
    && /^[\s\uFEFF]*[=+@\x2D]/u.test(text);
  const normalised = text.replace(/^\uFEFF+/u, "");
  const safe = formulaLikeText ? "'" + normalised : text;
  return '"' + safe.replaceAll('"', '""') + '"';
}

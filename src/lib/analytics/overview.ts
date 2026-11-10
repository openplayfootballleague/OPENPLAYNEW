export type AnalyticsLocation = { id: string; name: string; town: string };
export type AnalyticsSeason = { id: string; league_id: string; location_id?: string; name: string; status: string; starts_on?: string | null; season_number?: number | null };
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
  verifiedSeasons: number;
  openSeasons: number;
  approvedTeams: number;
  totalTeamApplications: number;
  rejectedTeamApplications: number;
  withdrawnTeamApplications: number;
  teamApprovalRate: number | null;
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
export type SeasonStatsSnapshot = {
  seasonId: string;
  stats: {
    season: { id: string; name: string };
    summary: { fixtures: number; published_results: number; goals: number; goals_per_match: number };
    teams: Array<{ team_id: string }>;
    players: Array<{ competition_player_id: string; apps: number }>;
  };
};
export type SeasonTrend = {
  seasonId: string;
  seasonName: string;
  startsOn: string | null;
  approvedTeams: number;
  playersWithAppearances: number;
  fixtures: number;
  publishedResults: number;
  goals: number;
  returningPlayers: number | null;
  returnRate: number | null;
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

export function buildAnalyticsOverview(
  setup: AnalyticsSetup,
  dashboard: AnalyticsDashboardCounts,
  verifiedStats: SeasonStatsSnapshot[],
  filters: AnalyticsFilters,
): AnalyticsOverview {
  const locationByLeague = new Map(setup.leagues.map((league) => [league.id, league.location_id]));
  const availableSeasons = setup.seasons.filter((season) => matchesFilters(season, filters, locationByLeague));
  const availableSeasonIds = new Set(availableSeasons.map((season) => season.id));
  const scopedStats = verifiedStats.filter((snapshot) => availableSeasonIds.has(snapshot.seasonId));
  const verifiedSeasonIds = new Set(scopedStats.map((snapshot) => snapshot.seasonId));
  const teamApplications = setup.season_teams.filter((team) => verifiedSeasonIds.has(team.season_id));
  const teams = teamApplications.filter((team) => team.registration_status === "approved");
  const summary = scopedStats.reduce((total, snapshot) => ({
    fixtures: total.fixtures + Number(snapshot.stats.summary.fixtures ?? 0),
    publishedResults: total.publishedResults + Number(snapshot.stats.summary.published_results ?? 0),
    goals: total.goals + Number(snapshot.stats.summary.goals ?? 0),
  }), { fixtures: 0, publishedResults: 0, goals: 0 });

  return {
    locations: filters.locationId ? 1 : setup.locations.length,
    leagues: setup.leagues.filter((league) => (!filters.locationId || league.location_id === filters.locationId) && (!filters.leagueId || league.id === filters.leagueId)).length,
    seasons: availableSeasons.length,
    verifiedSeasons: scopedStats.length,
    openSeasons: Number(dashboard.open_seasons ?? 0),
    approvedTeams: teams.length,
    totalTeamApplications: teamApplications.length,
    rejectedTeamApplications: teamApplications.filter((team) => team.registration_status === "rejected").length,
    withdrawnTeamApplications: teamApplications.filter((team) => team.registration_status === "withdrawn").length,
    teamApprovalRate: teamApplications.length > 0 ? (teams.length / teamApplications.length) * 100 : null,
    squadMemberships: teams.reduce((total, team) => total + Math.max(0, Number(team.member_count) || 0), 0),
    fixtures: summary.fixtures,
    publishedResults: summary.publishedResults,
    goals: summary.goals,
    pendingPlayerReviews: Number(dashboard.pending_player_reviews ?? 0),
    pendingTeamApplications: Number(dashboard.pending_team_applications ?? 0),
    pendingMembershipRequests: Number(dashboard.pending_membership_requests ?? 0),
  };
}

export function buildLocationComparisons(
  setup: AnalyticsSetup,
  filters: Pick<AnalyticsFilters, "leagueId" | "seasonId"> = { leagueId: "", seasonId: "" },
  verifiedStats: SeasonStatsSnapshot[] = [],
): AnalyticsLocationComparison[] {
  const locationByLeague = new Map(setup.leagues.map((league) => [league.id, league.location_id]));
  const statsBySeason = new Map(verifiedStats.map((snapshot) => [snapshot.seasonId, snapshot.stats]));
  return setup.locations.map((location) => {
    const seasons = setup.seasons.filter((season) =>
      (season.location_id ?? locationByLeague.get(season.league_id)) === location.id
      && (!filters.leagueId || season.league_id === filters.leagueId)
      && (!filters.seasonId || season.id === filters.seasonId),
    );
    const snapshots = seasons
      .map((season) => statsBySeason.get(season.id))
      .filter((stats): stats is SeasonStatsSnapshot["stats"] => Boolean(stats));
    const seasonIds = new Set(seasons.filter((season) => statsBySeason.has(season.id)).map((season) => season.id));
    const teams = setup.season_teams.filter((team) =>
      seasonIds.has(team.season_id) && team.registration_status === "approved",
    );
    return {
      locationId: location.id,
      locationName: location.name,
      seasons: snapshots.length,
      approvedTeams: teams.length,
      squadMemberships: teams.reduce((total, team) => total + Math.max(0, Number(team.member_count) || 0), 0),
      fixtures: snapshots.reduce((total, stats) => total + Number(stats.summary.fixtures ?? 0), 0),
      publishedResults: snapshots.reduce((total, stats) => total + Number(stats.summary.published_results ?? 0), 0),
      goals: snapshots.reduce((total, stats) => total + Number(stats.summary.goals ?? 0), 0),
    };
  });
}

export function buildSeasonTrends(
  seasons: AnalyticsSeason[],
  snapshots: SeasonStatsSnapshot[],
): SeasonTrend[] {
  const seasonById = new Map(seasons.map((season) => [season.id, season]));
  const ordered = snapshots
    .filter((snapshot) => seasonById.has(snapshot.seasonId))
    .sort((a, b) => {
      const aDate = seasonById.get(a.seasonId)?.starts_on ?? "";
      const bDate = seasonById.get(b.seasonId)?.starts_on ?? "";
      return aDate.localeCompare(bDate) || a.stats.season.name.localeCompare(b.stats.season.name);
    });

  return ordered.map((snapshot, index) => {
    const season = seasonById.get(snapshot.seasonId)!;
    const currentPlayers = new Set(snapshot.stats.players
      .filter((player) => Number(player.apps) > 0)
      .map((player) => player.competition_player_id));
    const previous = ordered[index - 1];
    const previousPlayers = previous
      ? new Set(previous.stats.players.filter((player) => Number(player.apps) > 0).map((player) => player.competition_player_id))
      : null;
    const returningPlayers = previousPlayers
      ? [...currentPlayers].filter((playerId) => previousPlayers.has(playerId)).length
      : null;

    return {
      seasonId: snapshot.seasonId,
      seasonName: snapshot.stats.season.name,
      startsOn: season.starts_on ?? null,
      approvedTeams: snapshot.stats.teams.length,
      playersWithAppearances: currentPlayers.size,
      fixtures: snapshot.stats.summary.fixtures,
      publishedResults: snapshot.stats.summary.published_results,
      goals: snapshot.stats.summary.goals,
      returningPlayers,
      returnRate: previousPlayers && previousPlayers.size > 0 && returningPlayers !== null
        ? (returningPlayers / previousPlayers.size) * 100
        : null,
    };
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

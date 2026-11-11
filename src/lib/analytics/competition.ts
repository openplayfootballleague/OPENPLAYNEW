export type AnalyticsFixture = {
  status: "scheduled" | "in_progress" | "completed" | "postponed" | "cancelled";
  hasConfirmedResult: boolean;
};

export type FixtureAnalyticsSummary = {
  fixturesScheduled: number;
  fixturesCompleted: number;
  fixturesPostponed: number;
  fixturesCancelled: number;
  resultsAwaitingPublication: number;
  completionRate: number | null;
};

/** A completed fixture counts only when its result is confirmed/published. */
export function summarizeFixturesForAnalytics(
  fixtures: readonly AnalyticsFixture[],
): FixtureAnalyticsSummary {
  const fixturesScheduled = fixtures.filter((fixture) => fixture.status === "scheduled" || fixture.status === "in_progress").length;
  const fixturesCompleted = fixtures.filter((fixture) => fixture.status === "completed" && fixture.hasConfirmedResult).length;
  const fixturesPostponed = fixtures.filter((fixture) => fixture.status === "postponed").length;
  const fixturesCancelled = fixtures.filter((fixture) => fixture.status === "cancelled").length;
  const resultsAwaitingPublication = fixtures.filter((fixture) => fixture.status === "completed" && !fixture.hasConfirmedResult).length;
  const eligible = fixtures.length - fixturesCancelled;

  return {
    fixturesScheduled,
    fixturesCompleted,
    fixturesPostponed,
    fixturesCancelled,
    resultsAwaitingPublication,
    completionRate: eligible === 0 ? null : fixturesCompleted / eligible,
  };
}

/**
 * Counts participants only from the eligible registered-player cohort supplied
 * by the authorised database query. Account or page activity is not participation.
 */
export function calculatePlayerParticipation(
  eligibleRegisteredPlayerIds: readonly string[],
  appearedPlayerIds: readonly string[],
): { activePlayers: number; eligiblePlayers: number; participationRate: number | null } {
  const eligible = new Set(eligibleRegisteredPlayerIds);
  const appeared = new Set(appearedPlayerIds);
  let activePlayers = 0;
  for (const id of eligible) if (appeared.has(id)) activePlayers += 1;

  return {
    activePlayers,
    eligiblePlayers: eligible.size,
    participationRate: eligible.size === 0 ? null : activePlayers / eligible.size,
  };
}

import { describe, expect, it } from "vitest";
import {
  safeCsvCell,
  aggregateFinanceTotals,
  buildAnalyticsOverview,
  buildCompetitionTeamPerformance,
  buildLocationComparisons,
  type AnalyticsSetup,
} from "./overview";

const setup: AnalyticsSetup = {
  locations: [
    { id: "loc-a", name: "Bideford", town: "Bideford" },
    { id: "loc-b", name: "Barnstaple", town: "Barnstaple" },
  ],
  leagues: [
    { id: "league-a", location_id: "loc-a", name: "Bideford 6s" },
    { id: "league-b", location_id: "loc-b", name: "Barnstaple 6s" },
  ],
  seasons: [
    { id: "season-a", league_id: "league-a", location_id: "loc-a", name: "A", status: "active" },
    { id: "season-b", league_id: "league-b", location_id: "loc-b", name: "B", status: "completed" },
  ],
  season_teams: [
    { id: "team-a", season_id: "season-a", name: "A team", registration_status: "approved", member_count: 6 },
    { id: "team-a-pending", season_id: "season-a", name: "Pending", registration_status: "pending", member_count: 4 },
    { id: "team-b", season_id: "season-b", name: "B team", registration_status: "approved", member_count: 5 },
  ],
  fixtures: [
    { id: "fixture-a", season_id: "season-a", gameweek: 1, status: "completed", home_score: 3, away_score: 2, scheduled_at: "2026-10-01T20:00:00Z" },
    { id: "fixture-b", season_id: "season-b", gameweek: 1, status: "scheduled", home_score: null, away_score: null, scheduled_at: "2026-10-08T20:00:00Z" },
  ],
};

describe("admin analytics aggregation", () => {
  it("counts only locations and leagues represented by the selected season scope", () => {
    const result = buildAnalyticsOverview(
      setup,
      { pending_player_reviews: 0, pending_team_applications: 0, pending_membership_requests: 0, open_seasons: 0 },
      setup.fixtures,
      { locationId: "", leagueId: "", seasonId: "season-b", fromDate: "", toDate: "" },
    );
    expect(result.locations).toBe(1);
    expect(result.leagues).toBe(1);
    expect(result.seasons).toBe(1);
  });

  it("does not count a selected location with no seasons in the current scoped setup", () => {
    const emptySetup: AnalyticsSetup = { ...setup, seasons: [] };
    const result = buildAnalyticsOverview(
      emptySetup,
      { pending_player_reviews: 0, pending_team_applications: 0, pending_membership_requests: 0, open_seasons: 0 },
      [],
      { locationId: "loc-a", leagueId: "", seasonId: "", fromDate: "", toDate: "" },
    );
    expect(result.locations).toBe(0);
    expect(result.leagues).toBe(0);
  });

  it("counts only approved teams and verified completed results in the selected context", () => {
    const result = buildAnalyticsOverview(setup, {
      pending_player_reviews: 2,
      pending_team_applications: 1,
      pending_membership_requests: 3,
      open_seasons: 1,
    }, [setup.fixtures[0]], { locationId: "loc-a", leagueId: "league-a", seasonId: "season-a", fromDate: "", toDate: "" });

    expect(result).toMatchObject({
      locations: 1,
      leagues: 1,
      seasons: 1,
      openSeasons: 1,
      approvedTeams: 1,
      squadMemberships: 6,
      fixtures: 1,
      publishedResults: 1,
      goals: 5,
      pendingPlayerReviews: 2,
      pendingTeamApplications: 1,
      pendingMembershipRequests: 3,
    });
  });

  it("excludes fixtures returned outside the selected season scope", () => {
    const result = buildAnalyticsOverview(
      setup,
      { pending_player_reviews: 0, pending_team_applications: 0, pending_membership_requests: 0, open_seasons: 1 },
      setup.fixtures,
      { locationId: "loc-a", leagueId: "league-a", seasonId: "season-a", fromDate: "", toDate: "" },
    );
    expect(result.fixtures).toBe(1);
    expect(result.publishedResults).toBe(1);
    expect(result.goals).toBe(5);
  });

  it("compares only locations visible in the scoped admin setup", () => {
    const result = buildLocationComparisons(setup);
    expect(result).toEqual([
      { locationId: "loc-a", locationName: "Bideford", seasons: 1, approvedTeams: 1, squadMemberships: 6, fixtures: 1, completedFixtures: 1, publishedResults: 1, resultsCoveragePercent: 100, goals: 5, goalsPerResult: 5 },
      { locationId: "loc-b", locationName: "Barnstaple", seasons: 1, approvedTeams: 1, squadMemberships: 5, fixtures: 1, completedFixtures: 0, publishedResults: 0, resultsCoveragePercent: null, goals: 0, goalsPerResult: null },
    ]);
  });

  it("calculates team win rate and points per game without dividing by zero", () => {
    expect(buildCompetitionTeamPerformance([
      { position: 1, team_id: "team-a", name: "A", played: 4, wins: 3, draws: 1, losses: 0, goals_for: 12, goals_against: 5, goal_difference: 7, points: 10, clean_sheets: 2 },
      { position: 2, team_id: "team-b", name: "B", played: 0, wins: 0, draws: 0, losses: 0, goals_for: 0, goals_against: 0, goal_difference: 0, points: 0, clean_sheets: 0 },
    ])).toEqual([
      { position: 1, team_id: "team-a", name: "A", played: 4, wins: 3, draws: 1, losses: 0, goals_for: 12, goals_against: 5, goal_difference: 7, points: 10, clean_sheets: 2, winRatePercent: 75, pointsPerGame: 2.5 },
      { position: 2, team_id: "team-b", name: "B", played: 0, wins: 0, draws: 0, losses: 0, goals_for: 0, goals_against: 0, goal_difference: 0, points: 0, clean_sheets: 0, winRatePercent: null, pointsPerGame: null },
    ]);
  });

  it("calculates result publication coverage from completed fixtures only", () => {
    const setupWithUnpublishedCompleted: AnalyticsSetup = {
      ...setup,
      fixtures: [...setup.fixtures, {
        id: "fixture-completed-without-result",
        season_id: "season-a",
        gameweek: 2,
        status: "completed",
        home_score: null,
        away_score: null,
        scheduled_at: "2026-10-08T20:00:00Z",
      }],
    };
    const row = buildLocationComparisons(setupWithUnpublishedCompleted).find((item) => item.locationId === "loc-a");
    expect(row).toMatchObject({
      fixtures: 2,
      completedFixtures: 2,
      publishedResults: 1,
      resultsCoveragePercent: 50,
      goals: 5,
      goalsPerResult: 5,
    });
  });

  it("filters location comparisons by the selected league or season", () => {
    expect(buildLocationComparisons(setup, { locationId: "", leagueId: "league-b", seasonId: "" })).toHaveLength(1);
    expect(buildLocationComparisons(setup, { locationId: "loc-a", leagueId: "", seasonId: "" })).toHaveLength(1);
    expect(buildLocationComparisons(setup, { locationId: "loc-a", leagueId: "", seasonId: "season-a" })[0].locationName).toBe("Bideford");
  });

  it("applies inclusive date boundaries and excludes fixtures without a scheduled date", () => {
    const withUndatedFixture: AnalyticsSetup = {
      ...setup,
      fixtures: [...setup.fixtures, {
        id: "fixture-undated",
        season_id: "season-a",
        gameweek: 2,
        status: "completed",
        home_score: 1,
        away_score: 0,
        scheduled_at: null,
      }],
    };
    const dashboard = { pending_player_reviews: 0, pending_team_applications: 0, pending_membership_requests: 0, open_seasons: 1 };
    const result = buildAnalyticsOverview(
      withUndatedFixture,
      dashboard,
      withUndatedFixture.fixtures,
      { locationId: "loc-a", leagueId: "league-a", seasonId: "season-a", fromDate: "2026-10-01", toDate: "2026-10-01" },
    );
    expect(result.fixtures).toBe(1);
    expect(result.publishedResults).toBe(1);
    expect(result.goals).toBe(5);
    expect(buildLocationComparisons(withUndatedFixture, {
      locationId: "loc-a", leagueId: "league-a", seasonId: "season-a", fromDate: "2026-10-02", toDate: "2026-10-09",
    })).toMatchObject([{ locationName: "Bideford", fixtures: 0, publishedResults: 0, goals: 0 }]);
  });

  it("neutralises spreadsheet formula prefixes in text while preserving numeric values", () => {
    expect(safeCsvCell("=1+1")).toBe("\"'=1+1\"");
    expect(safeCsvCell("  @SUM(A1:A2)")).toBe("\"'  @SUM(A1:A2)\"");
    expect(safeCsvCell("\\uFEFF=1+1")).toBe("\"'=1+1\"");
    expect(safeCsvCell("-125")).toBe("\"'-125\"");
    expect(safeCsvCell(-125)).toBe("\"-125\"");
    expect(safeCsvCell('Open "Play"')).toBe("\"Open \"\"Play\"\"\"");
  });

  it("aggregates integer-pence finance totals without converting to floating point", () => {
    expect(aggregateFinanceTotals([
      { charges_pence: 3000, payments_pence: "2000", refunds_pence: 0, credits_pence: 0, fines_pence: 500, outstanding_pence: 1500 },
      { charges_pence: 1500, payments_pence: 1000, refunds_pence: 250, credits_pence: 50, fines_pence: 0, outstanding_pence: 200 },
    ])).toEqual({
      chargesPence: 4500,
      paymentsPence: 3000,
      refundsPence: 250,
      creditsPence: 50,
      finesPence: 500,
      outstandingPence: 1700,
    });
  });
});

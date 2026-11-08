import { describe, expect, it } from "vitest";
import { calculatePlayerParticipation, summarizeFixturesForAnalytics } from "./competition";

describe("competition analytics calculations", () => {
  it("counts only completed fixtures with confirmed results as completed", () => {
    expect(summarizeFixturesForAnalytics([
      { status: "scheduled", hasConfirmedResult: false },
      { status: "in_progress", hasConfirmedResult: false },
      { status: "completed", hasConfirmedResult: true },
      { status: "completed", hasConfirmedResult: false },
      { status: "postponed", hasConfirmedResult: false },
      { status: "cancelled", hasConfirmedResult: false },
    ])).toEqual({
      fixturesScheduled: 2,
      fixturesCompleted: 1,
      fixturesPostponed: 1,
      fixturesCancelled: 1,
      resultsAwaitingPublication: 1,
      completionRate: 1 / 5,
    });
  });

  it("returns unavailable completion when there are no eligible fixtures", () => {
    expect(summarizeFixturesForAnalytics([
      { status: "cancelled", hasConfirmedResult: false },
    ]).completionRate).toBeNull();
  });

  it("counts distinct eligible players who appeared, not all accounts", () => {
    expect(calculatePlayerParticipation(
      ["a", "a", "b", "c"],
      ["a", "a", "c", "unregistered"],
    )).toEqual({ activePlayers: 2, eligiblePlayers: 3, participationRate: 2 / 3 });
  });

  it("returns unavailable participation when the eligible cohort is empty", () => {
    expect(calculatePlayerParticipation([], ["a"])).toEqual({
      activePlayers: 0,
      eligiblePlayers: 0,
      participationRate: null,
    });
  });
});

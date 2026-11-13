import { describe, expect, it } from "vitest";
import { completedMatches, paginate, teamOutcome, upcomingFixtures, type MatchFixture, type MatchResult } from "./player-matches";

const f = (id: string, gameweek: number, at: string | null, status: MatchFixture["status"], home = "us", away = "them"): MatchFixture =>
  ({ id, gameweek, scheduled_at: at, status, home_team_id: home, away_team_id: away });

describe("My Results", () => {
  it("calculates the outcome from the player's team perspective", () => {
    const away = f("1", 1, null, "completed", "them", "us");
    expect(teamOutcome("us", away, { fixture_id: "1", home_score: 1, away_score: 3, confirmed_at: "x" })).toBe("win");
    expect(teamOutcome("them", away, { fixture_id: "1", home_score: 1, away_score: 3, confirmed_at: "x" })).toBe("loss");
    expect(teamOutcome("us", away, { fixture_id: "1", home_score: 2, away_score: 2, confirmed_at: "x" })).toBe("draw");
  });

  it("shows only published results, newest first, for the player's team", () => {
    const fixtures = [
      f("a", 1, "2027-01-06T19:00:00Z", "completed"),
      f("b", 2, "2027-01-13T19:00:00Z", "completed"),
      f("c", 3, "2027-01-20T19:00:00Z", "completed"),
      f("d", 3, "2027-01-20T19:00:00Z", "completed", "x", "y"),
    ];
    const results: MatchResult[] = [
      { fixture_id: "a", home_score: 1, away_score: 0, confirmed_at: "x" },
      { fixture_id: "b", home_score: 0, away_score: 0, confirmed_at: null },
      { fixture_id: "c", home_score: 0, away_score: 2, confirmed_at: "x" },
      { fixture_id: "d", home_score: 5, away_score: 0, confirmed_at: "x" },
    ];
    expect(completedMatches(fixtures, results, "us").map((m) => [m.fixture.id, m.outcome])).toEqual([["c", "loss"], ["a", "win"]]);
  });
});

describe("My Fixtures", () => {
  it("lists non-completed fixtures chronologically, undated last, keeping cancelled visible", () => {
    const fixtures = [
      f("late", 4, "2027-02-03T19:00:00Z", "scheduled"),
      f("tbc", 2, null, "postponed"),
      f("done", 1, "2027-01-06T19:00:00Z", "completed"),
      f("soon", 3, "2027-01-27T19:00:00Z", "cancelled"),
      f("other", 3, "2027-01-27T19:00:00Z", "scheduled", "x", "y"),
    ];
    expect(upcomingFixtures(fixtures, "us").map((x) => x.id)).toEqual(["soon", "late", "tbc"]);
  });
});

describe("pagination", () => {
  it("reports range, total and boundaries, and clamps out-of-range pages", () => {
    const items = Array.from({ length: 10 }, (_, i) => i);
    expect(paginate(items, 1, 4)).toMatchObject({ items: [0, 1, 2, 3], from: 1, to: 4, total: 10, pages: 3, hasPrevious: false, hasNext: true });
    expect(paginate(items, 3, 4)).toMatchObject({ items: [8, 9], from: 9, to: 10, hasPrevious: true, hasNext: false });
    expect(paginate(items, 99, 4).page).toBe(3);
    expect(paginate([], 1, 4)).toMatchObject({ from: 0, to: 0, total: 0, pages: 1, hasNext: false });
  });
});

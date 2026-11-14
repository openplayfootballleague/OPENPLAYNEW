import { describe, expect, it } from "vitest";
import { eligibleAssisters, eligibleScorers, toGoalEventPayload, validateGoalEvents, type FixtureSheets } from "./goal-events";

const sheets: FixtureSheets = {
  home: [
    { competition_player_id: "h1", full_name: "Home One", did_appear: true },
    { competition_player_id: "h2", full_name: "Home Two", did_appear: true },
    { competition_player_id: "h3", full_name: "Home Unused Sub", did_appear: false },
  ],
  away: [
    { competition_player_id: "a1", full_name: "Away One", did_appear: true },
    { competition_player_id: "a2", full_name: "Away Two", did_appear: true },
  ],
};

describe("goal event eligibility", () => {
  it("draws normal-goal scorers from the credited team and own-goal scorers from the opponent", () => {
    expect(eligibleScorers(sheets, "home", false).map((p) => p.competition_player_id)).toEqual(["h1", "h2"]);
    expect(eligibleScorers(sheets, "home", true).map((p) => p.competition_player_id)).toEqual(["a1", "a2"]);
  });

  it("excludes players who did not appear", () => {
    expect(eligibleScorers(sheets, "home", false).some((p) => p.competition_player_id === "h3")).toBe(false);
  });

  it("offers no assisters for an own goal and never the scorer", () => {
    expect(eligibleAssisters(sheets, { teamSide: "home", isOwnGoal: true, scorerId: "a1" })).toEqual([]);
    expect(eligibleAssisters(sheets, { teamSide: "home", isOwnGoal: false, scorerId: "h1" }).map((p) => p.competition_player_id)).toEqual(["h2"]);
  });
});

describe("goal event validation", () => {
  it("accepts a valid set including an own goal", () => {
    expect(validateGoalEvents([
      { teamSide: "home", scorerId: "h1", isOwnGoal: false, assistId: "h2" },
      { teamSide: "home", scorerId: "a2", isOwnGoal: true, assistId: null },
      { teamSide: "away", scorerId: "a1", isOwnGoal: false, assistId: null },
    ], sheets, { home: 2, away: 1 })).toEqual([]);
  });

  it("rejects too many events, wrong-team scorers, own-goal assists and self-assists", () => {
    const errors = validateGoalEvents([
      { teamSide: "away", scorerId: "a1", isOwnGoal: false, assistId: null },
      { teamSide: "away", scorerId: "a2", isOwnGoal: false, assistId: null },
      { teamSide: "home", scorerId: "a1", isOwnGoal: false, assistId: null },
      { teamSide: "home", scorerId: "a2", isOwnGoal: true, assistId: "h1" },
      { teamSide: "home", scorerId: "h1", isOwnGoal: false, assistId: "h1" },
    ], sheets, { home: 3, away: 1 });
    expect(errors).toHaveLength(4);
    expect(errors[0]).toMatch(/Away goal events \(2\) exceed/);
    expect(errors.join(" ")).toMatch(/opposing|credited/);
    expect(errors.join(" ")).toMatch(/own goal cannot have an assist/);
    expect(errors.join(" ")).toMatch(/different player/);
  });

  it("never sends an assist for an own goal", () => {
    expect(toGoalEventPayload([{ teamSide: "home", scorerId: "a1", isOwnGoal: true, assistId: "h1" }])[0].assist_competition_player_id).toBeNull();
  });
});

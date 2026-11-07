import { describe, expect, it } from "vitest";
import { canTransitionFixtureStatus, getTeamSheetLimits, hasOneScorerPerGoal, hasOnlyAppearedScorers, isValidFixtureScore, validateTeamSheet, type TeamSheetPlayer } from "./rules";

function starters(count: number): TeamSheetPlayer[] {
  return Array.from({ length: count }, (_, index) => ({
    playerId: `p${index + 1}`,
    role: "starter" as const,
    isGoalkeeper: index === 0,
  }));
}

describe("team sheet competition rules", () => {
  it("uses the correct 6-a-side and 7-a-side limits", () => {
    expect(getTeamSheetLimits("six_a_side")).toEqual({ starters: 6, substitutes: 3 });
    expect(getTeamSheetLimits("seven_a_side")).toEqual({ starters: 7, substitutes: 4 });
  });

  it("accepts exactly six starters and up to three substitutes with one goalkeeper", () => {
    const players = [
      ...starters(6),
      ...Array.from({ length: 3 }, (_, i) => ({ playerId: `s${i}`, role: "substitute" as const })),
    ];
    expect(validateTeamSheet("six_a_side", players).valid).toBe(true);
  });

  it("rejects the wrong starter count and too many substitutes", () => {
    const result = validateTeamSheet("seven_a_side", [
      ...starters(6),
      ...Array.from({ length: 5 }, (_, i) => ({ playerId: `s${i}`, role: "substitute" as const })),
    ]);
    expect(result.valid).toBe(false);
    expect(result.errors).toHaveLength(2);
  });

  it("requires exactly one goalkeeper", () => {
    const players = starters(6).map((player) => ({ ...player, isGoalkeeper: false }));
    expect(validateTeamSheet("six_a_side", players).errors).toContain(
      "Select exactly one goalkeeper from the starting players.",
    );
  });

  it("rejects a goalkeeper who is selected as a substitute", () => {
    const players = starters(6).map((player) => ({ ...player, isGoalkeeper: false }));
    players.push({ playerId: "sub-keeper", role: "substitute", isGoalkeeper: true });
    expect(validateTeamSheet("six_a_side", players).errors).toContain(
      "The goalkeeper must be one of the starting players.",
    );
  });

  it("rejects duplicate player IDs", () => {
    const players = starters(6);
    players[5] = { ...players[0] };
    expect(validateTeamSheet("six_a_side", players).errors).toContain(
      "A player can only appear once on a team sheet.",
    );
  });

  it("allows omitted squad numbers but rejects invalid or duplicate numbers", () => {
    const players = starters(6);
    players[0] = { ...players[0], squadNumber: 0 };
    players[1] = { ...players[1], squadNumber: 0 };
    const errors = validateTeamSheet("six_a_side", players).errors;
    expect(errors).toContain("Squad numbers must be whole numbers from 1 to 99.");
    expect(errors).toContain("Squad numbers must be unique within the team sheet.");
    expect(validateTeamSheet("six_a_side", starters(6)).valid).toBe(true);
  });
});

describe("fixture lifecycle rules", () => {
  it("allows only the supported fixture status transitions", () => {
    expect(canTransitionFixtureStatus("scheduled", "in_progress")).toBe(true);
    expect(canTransitionFixtureStatus("scheduled", "postponed")).toBe(true);
    expect(canTransitionFixtureStatus("postponed", "scheduled")).toBe(true);
    expect(canTransitionFixtureStatus("in_progress", "completed")).toBe(false);
    expect(canTransitionFixtureStatus("completed", "scheduled")).toBe(false);
    expect(canTransitionFixtureStatus("cancelled", "in_progress")).toBe(false);
  });

  it("accepts non-negative integer scores within the database SMALLINT range", () => {
    expect(isValidFixtureScore(0)).toBe(true);
    expect(isValidFixtureScore(12)).toBe(true);
    expect(isValidFixtureScore(-1)).toBe(false);
    expect(isValidFixtureScore(1.5)).toBe(false);
    expect(isValidFixtureScore(32768)).toBe(false);
  });
});

describe("fixture goalscorer validation", () => {
  it("requires exactly one selected scorer per goal", () => {
    expect(hasOneScorerPerGoal(0, [])).toBe(true);
    expect(hasOneScorerPerGoal(2, ["player-a"])).toBe(false);
    expect(hasOneScorerPerGoal(2, ["player-a", "player-b"])).toBe(true);
  });

  it("allows the same player to score multiple goals", () => {
    expect(hasOneScorerPerGoal(3, ["player-a", "player-a", "player-a"])).toBe(true);
  });

  it("rejects blank scorer selections and invalid score counts", () => {
    expect(hasOneScorerPerGoal(1, [""])).toBe(false);
    expect(hasOneScorerPerGoal(-1, [])).toBe(false);
    expect(hasOneScorerPerGoal(1.5, ["player-a"])).toBe(false);
  });
});

describe("match appearance validation", () => {
  it("allows goalscorers who started or came on as substitutes", () => {
    expect(hasOnlyAppearedScorers(
      ["starter-a", "sub-a", "starter-a"],
      ["starter-a", "starter-b"],
      ["sub-a"],
    )).toBe(true);
  });

  it("rejects substitutes who did not appear and players outside the team sheet", () => {
    expect(hasOnlyAppearedScorers(
      ["starter-a", "unused-sub"],
      ["starter-a"],
      [],
    )).toBe(false);
    expect(hasOnlyAppearedScorers(["unknown"], ["starter-a"], ["sub-a"])).toBe(false);
  });

  it("rejects blank scorer IDs", () => {
    expect(hasOnlyAppearedScorers([""], ["starter-a"], [])).toBe(false);
  });
});

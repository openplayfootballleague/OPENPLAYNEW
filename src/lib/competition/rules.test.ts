import { describe, expect, it } from "vitest";
import { getTeamSheetLimits, validateTeamSheet, type TeamSheetPlayer } from "./rules";

function starters(count: number): TeamSheetPlayer[] {
  return Array.from({ length: count }, (_, index) => ({ playerId: `p${index + 1}`, role: "starter" as const }));
}

describe("team sheet competition rules", () => {
  it("uses the correct 6-a-side and 7-a-side limits", () => {
    expect(getTeamSheetLimits("six_a_side")).toEqual({ starters: 6, substitutes: 3 });
    expect(getTeamSheetLimits("seven_a_side")).toEqual({ starters: 7, substitutes: 4 });
  });
  it("accepts exactly six starters and up to three substitutes", () => {
    const players = [...starters(6), ...Array.from({ length: 3 }, (_, i) => ({ playerId: `s${i}`, role: "substitute" as const }))];
    expect(validateTeamSheet("six_a_side", players).valid).toBe(true);
  });
  it("rejects the wrong starter count and too many substitutes", () => {
    const result = validateTeamSheet("seven_a_side", [...starters(6), ...Array.from({ length: 5 }, (_, i) => ({ playerId: `s${i}`, role: "substitute" as const }))]);
    expect(result.valid).toBe(false);
    expect(result.errors).toHaveLength(2);
  });
  it("rejects duplicate player IDs", () => {
    const players = starters(6); players[5] = { ...players[0] };
    expect(validateTeamSheet("six_a_side", players).errors).toContain("A player can only appear once on a team sheet.");
  });
  it("allows omitted squad numbers but rejects invalid or duplicate numbers", () => {
    const players = starters(6); players[0] = { ...players[0], squadNumber: 0 }; players[1] = { ...players[1], squadNumber: 0 };
    const errors = validateTeamSheet("six_a_side", players).errors;
    expect(errors).toContain("Squad numbers must be whole numbers from 1 to 99.");
    expect(errors).toContain("Squad numbers must be unique within the team sheet.");
    expect(validateTeamSheet("six_a_side", starters(6)).valid).toBe(true);
  });
});

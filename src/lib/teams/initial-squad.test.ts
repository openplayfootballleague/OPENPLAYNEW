import { describe, expect, it } from "vitest";
import { validateInitialSquad, type InitialSquadMember } from "./initial-squad";

function squad(format: 6 | 7): InitialSquadMember[] {
  return Array.from({ length: format + (format === 6 ? 2 : 3) }, (_, index) => ({
    playerId: `player-${index + 1}`,
    registrationStatus: "registered",
    isBanned: false,
    isStarter: index < format,
    isCaptain: index === 0,
  }));
}

describe("initial team squad validation", () => {
  it.each([6, 7] as const)("accepts a complete %s-a-side starting group and permitted substitutes", (format) => {
    const result = validateInitialSquad(format, "player-1", squad(format));
    expect(result).toEqual({
      valid: true,
      starters: format,
      substitutes: format === 6 ? 2 : 3,
    });
  });

  it.each([6, 7] as const)("rejects a %s-a-side squad without the required starters", (format) => {
    const members = squad(format);
    members[0].isStarter = false;
    expect(validateInitialSquad(format, "player-1", members)).toMatchObject({
      valid: false,
      errors: expect.arrayContaining([expect.stringContaining("starters")]),
    });
  });

  it("rejects more than the permitted substitute limit", () => {
    const members = squad(6);
    for (const playerId of ["extra-player-1", "extra-player-2"]) {
      members.push({
        playerId,
        registrationStatus: "registered",
        isBanned: false,
        isStarter: false,
        isCaptain: false,
      });
    }
    expect(validateInitialSquad(6, "player-1", members)).toMatchObject({
      valid: false,
      errors: expect.arrayContaining([expect.stringContaining("no more than 9")]),
    });
  });

  it("rejects duplicate player identities", () => {
    const members = squad(6);
    members[1].playerId = members[0].playerId;
    expect(validateInitialSquad(6, "player-1", members)).toMatchObject({
      valid: false,
      errors: expect.arrayContaining([expect.stringContaining("once")]),
    });
  });

  it("requires the applicant to be the sole nominated captain", () => {
    const members = squad(6);
    members[0].isCaptain = false;
    members[1].isCaptain = true;
    expect(validateInitialSquad(6, "player-1", members)).toMatchObject({
      valid: false,
      errors: expect.arrayContaining([expect.stringContaining("applicant must be the nominated captain")]),
    });
  });

  it("rejects pending-review and banned players", () => {
    const members = squad(7);
    members[2].registrationStatus = "pending_review";
    members[3].isBanned = true;
    const result = validateInitialSquad(7, "player-1", members);
    expect(result).toMatchObject({
      valid: false,
      errors: expect.arrayContaining([
        expect.stringContaining("approved player registration"),
        expect.stringContaining("banned player"),
      ]),
    });
  });
});

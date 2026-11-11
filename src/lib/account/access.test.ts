import { describe, expect, it } from "vitest";
import { deriveAccountAccess } from "./access";

describe("account navigation access presentation", () => {
  it("does not treat a missing player registration as an approved player", () => {
    expect(deriveAccountAccess(null, true, [])).toEqual({
      approvedPlayer: false, captain: false, admin: false, finance: false,
    });
  });

  it.each(["pending_review", "rejected"])(
    "does not grant player or captain presentation for %s registration",
    (registration_status) => {
      const result = deriveAccountAccess(
        { registration_status, is_banned: false }, true, [],
      );
      expect(result.approvedPlayer).toBe(false);
      expect(result.captain).toBe(false);
    },
  );

  it("does not grant player or captain presentation to a banned registered player", () => {
    const result = deriveAccountAccess(
      { registration_status: "registered", is_banned: true }, true, [],
    );
    expect(result.approvedPlayer).toBe(false);
    expect(result.captain).toBe(false);
  });

  it("grants captain presentation only to an approved player with active captain membership", () => {
    const player = { registration_status: "registered", is_banned: false };
    expect(deriveAccountAccess(player, false, []).captain).toBe(false);
    expect(deriveAccountAccess(player, true, []).captain).toBe(true);
  });

  it("keeps platform and finance role scopes distinct", () => {
    const player = { registration_status: "registered", is_banned: false };
    expect(deriveAccountAccess(player, false, ["league_admin"])).toMatchObject({
      admin: true, finance: false,
    });
    expect(deriveAccountAccess(player, false, ["finance_admin"])).toMatchObject({
      admin: false, finance: true,
    });
    expect(deriveAccountAccess(player, false, ["super_admin"])).toMatchObject({
      admin: true, finance: true,
    });
  });
});

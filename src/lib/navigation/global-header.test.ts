import { describe, expect, it } from "vitest";
import { formatUnreadCount, showsGlobalHeader } from "./global-header";

describe("global header placement", () => {
  it("appears on player-facing routes", () => {
    for (const path of ["/join", "/leagues", "/teams", "/teams/abc", "/match-centre", "/player", "/player/profile", "/inbox", "/more", "/sign-in"]) {
      expect(showsGlobalHeader(path)).toBe(true);
    }
  });
  it("is omitted where a workspace has its own header", () => {
    for (const path of ["/", "/admin", "/admin/analytics", "/admin-messages", "/admin-help", "/admin.retention", "/finance", "/referee", "/referee/matchday"]) {
      expect(showsGlobalHeader(path)).toBe(false);
    }
  });
  it("caps the unread badge", () => {
    expect([formatUnreadCount(1), formatUnreadCount(9), formatUnreadCount(12)]).toEqual(["1", "9", "9+"]);
  });
});

import { describe, expect, it } from "vitest";
import { getPlayerSessionTransition } from "./player-session";

describe("Player Hub session transitions", () => {
  it("keeps the current account state for token refreshes", () => {
    expect(getPlayerSessionTransition("user-a", "user-a")).toBe("same-user");
  });

  it("detects an account switch and requires a fresh data load", () => {
    expect(getPlayerSessionTransition("user-a", "user-b")).toBe("user-changed");
  });

  it("treats sign-out as a state-clearing transition", () => {
    expect(getPlayerSessionTransition("user-a", null)).toBe("signed-out");
  });

  it("treats the initial signed-out session as signed out", () => {
    expect(getPlayerSessionTransition(undefined, null)).toBe("signed-out");
  });

  it("loads an initially authenticated account", () => {
    expect(getPlayerSessionTransition(undefined, "user-a")).toBe("user-changed");
  });
});

import { describe, expect, it } from "vitest";
import { isNavigationItemActive, navigationItems, resolveNavigationMode } from "./account-navigation";

const registered = { registration_status: "registered", is_banned: false };
const labels = (mode: Parameters<typeof navigationItems>[0], approved = false) => navigationItems(mode, approved).map((item) => item.label);

describe("account-state navigation", () => {
  it("resolves visitor, onboarding, player and captain states", () => {
    expect(resolveNavigationMode({ signedIn: false, player: null, activeMemberships: [] })).toBe("visitor");
    expect(resolveNavigationMode({ signedIn: true, player: null, activeMemberships: [] })).toBe("onboarding");
    expect(resolveNavigationMode({ signedIn: true, player: registered, activeMemberships: [] })).toBe("onboarding");
    expect(resolveNavigationMode({ signedIn: true, player: { ...registered, registration_status: "pending_review" }, activeMemberships: [{ is_captain: false }] })).toBe("onboarding");
    expect(resolveNavigationMode({ signedIn: true, player: { ...registered, is_banned: true }, activeMemberships: [{ is_captain: true }] })).toBe("onboarding");
    expect(resolveNavigationMode({ signedIn: true, player: registered, activeMemberships: [{ is_captain: false }] })).toBe("player");
    expect(resolveNavigationMode({ signedIn: true, player: registered, activeMemberships: [{ is_captain: false }, { is_captain: true }] })).toBe("captain");
  });

  it("matches the reference images tab for tab", () => {
    expect(labels("visitor")).toEqual(["Home", "Match Centre", "Join Open Play", "More"]); // IMG_0581
    expect(labels("onboarding")).toEqual(["Home", "Match Centre", "Teams", "Join Open Play", "More"]); // IMG_0582/0583
    expect(labels("player")).toEqual(["Player Hub", "Match Centre", "Teams", "More"]); // IMG_0572-0580
    expect(labels("captain")).toEqual(["Player Hub", "Club", "Matchday", "More"]);
  });

  it("never offers Join Open Play to a player who belongs to a team", () => {
    expect(navigationItems("player").some((item) => item.id === "join")).toBe(false);
    expect(navigationItems("captain").some((item) => item.id === "join")).toBe(false);
  });

  it("sends an approved player without a team Home to the Player Hub, otherwise to public Home", () => {
    expect(navigationItems("onboarding", true)[0].to).toBe("/player");
    expect(navigationItems("onboarding", false)[0].to).toBe("/");
  });

  it("marks the active tab, including league discovery under Join Open Play", () => {
    const join = navigationItems("visitor").find((item) => item.id === "join")!;
    expect(isNavigationItemActive(join, "/leagues", "")).toBe(true);
    const [home] = navigationItems("player");
    expect(isNavigationItemActive(home, "/player", "")).toBe(true);
    const matchday = navigationItems("captain").find((item) => item.id === "matchday")!;
    expect(isNavigationItemActive(matchday, "/captain", "#captain-matchday")).toBe(true);
    expect(isNavigationItemActive(matchday, "/captain", "")).toBe(false);
  });
});

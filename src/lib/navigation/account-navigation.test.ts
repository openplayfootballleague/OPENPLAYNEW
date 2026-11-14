import { describe, expect, it } from "vitest";
import { homeDestination, isNavigationItemActive, isRegistrationRoute, navigationItems, resolveNavigationMode } from "./account-navigation";

const registered = { registration_status: "registered", is_banned: false };
const labels = (mode: Parameters<typeof navigationItems>[0], path = "/") => navigationItems(mode, path).map((item) => item.label);
const FIVE = ["Home", "Match Centre", "Teams", "Join Open Play", "More"];

describe("bottom navigation (owner specification, section 5)", () => {
  it("resolves each account state", () => {
    expect(resolveNavigationMode({ signedIn: false, player: null, activeMemberships: [] })).toBe("visitor");
    expect(resolveNavigationMode({ signedIn: true, player: null, activeMemberships: [] })).toBe("account");
    expect(resolveNavigationMode({ signedIn: true, player: { ...registered, registration_status: "pending_review" }, activeMemberships: [] })).toBe("account");
    expect(resolveNavigationMode({ signedIn: true, player: { ...registered, is_banned: true }, activeMemberships: [{ is_captain: true }] })).toBe("account");
    expect(resolveNavigationMode({ signedIn: true, player: registered, activeMemberships: [] })).toBe("onboarding");
    expect(resolveNavigationMode({ signedIn: true, player: registered, activeMemberships: [{ is_captain: false }] })).toBe("player");
    expect(resolveNavigationMode({ signedIn: true, player: registered, activeMemberships: [{ is_captain: true }] })).toBe("captain");
  });

  it("gives every account state the same five tabs, including Join Open Play", () => {
    for (const mode of ["visitor", "account", "onboarding", "player", "captain"] as const) expect(labels(mode)).toEqual(FIVE);
  });

  it("uses the simplified four-tab bar on registration screens", () => {
    for (const path of ["/sign-up", "/register-player", "/join/team"]) {
      expect(labels("account", path)).toEqual(["Home", "Match Centre", "Join Open Play", "More"]);
      const join = navigationItems("account", path).find((item) => item.id === "join")!;
      expect(isNavigationItemActive(join, path)).toBe(true);
    }
    expect(isRegistrationRoute("/join")).toBe(false);
  });

  it("sends approved players Home to the Player Hub and others to public Home", () => {
    expect(homeDestination("visitor")).toBe("/");
    expect(homeDestination("account")).toBe("/");
    for (const mode of ["onboarding", "player", "captain"] as const) expect(navigationItems(mode)[0].to).toBe("/player");
  });

  it("never adds a captain-only tab", () => {
    expect(navigationItems("captain").map((item) => item.to)).not.toContain("/captain");
  });

  it("marks the active tab for nested routes", () => {
    const [home, , teams] = navigationItems("player");
    expect(isNavigationItemActive(home, "/player/fixtures")).toBe(true);
    expect(isNavigationItemActive(teams, "/teams/abc")).toBe(true);
    const join = navigationItems("visitor").find((item) => item.id === "join")!;
    expect(isNavigationItemActive(join, "/leagues")).toBe(true);
  });
});

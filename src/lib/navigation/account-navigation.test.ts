import { describe, expect, it } from "vitest";
import { isNavigationItemActive, navigationItems, resolveNavigationMode } from "./account-navigation";

const registered = { registration_status: "registered", is_banned: false };
const labels = (mode: Parameters<typeof navigationItems>[0], approved = false) => navigationItems(mode, approved).map((item) => item.label);

describe("account-state navigation (owner reference images)", () => {
  it("resolves each account state", () => {
    expect(resolveNavigationMode({ signedIn: false, player: null, activeMemberships: [] })).toBe("visitor");
    expect(resolveNavigationMode({ signedIn: true, player: null, activeMemberships: [] })).toBe("account");
    expect(resolveNavigationMode({ signedIn: true, player: { ...registered, registration_status: "pending_review" }, activeMemberships: [{ is_captain: false }] })).toBe("account");
    expect(resolveNavigationMode({ signedIn: true, player: { ...registered, is_banned: true }, activeMemberships: [{ is_captain: true }] })).toBe("account");
    expect(resolveNavigationMode({ signedIn: true, player: registered, activeMemberships: [] })).toBe("onboarding");
    expect(resolveNavigationMode({ signedIn: true, player: registered, activeMemberships: [{ is_captain: false }] })).toBe("player");
    expect(resolveNavigationMode({ signedIn: true, player: registered, activeMemberships: [{ is_captain: false }, { is_captain: true }] })).toBe("captain");
  });

  it("matches the reference images tab for tab", () => {
    expect(labels("visitor")).toEqual(["Home", "Match Centre", "Join Open Play", "More"]); // IMG_0581, IMG_0562
    expect(labels("account")).toEqual(["Home", "Match Centre", "Join Open Play", "More"]); // IMG_0563-0567
    expect(labels("onboarding")).toEqual(["Home", "Match Centre", "Teams", "Join Open Play", "More"]); // IMG_0582/0583
    expect(labels("player")).toEqual(["Home", "Match Centre", "Teams", "More"]); // IMG_0522, IMG_0572-0580
    expect(labels("captain")).toEqual(["Home", "Match Centre", "Teams", "Captain's Hub", "More"]); // IMG_0543
  });

  it("never offers Join Open Play to a player who belongs to a team", () => {
    expect(navigationItems("player").some((item) => item.id === "join")).toBe(false);
    expect(navigationItems("captain").some((item) => item.id === "join")).toBe(false);
  });

  it("sends players Home to the Player Hub and everyone else to public Home", () => {
    expect(navigationItems("player")[0].to).toBe("/player");
    expect(navigationItems("captain")[0].to).toBe("/player");
    expect(navigationItems("onboarding", true)[0].to).toBe("/player");
    expect(navigationItems("account")[0].to).toBe("/");
  });

  it("marks the active tab for nested routes", () => {
    const [home, , teams] = navigationItems("player");
    expect(isNavigationItemActive(home, "/player/fixtures")).toBe(true);
    expect(isNavigationItemActive(teams, "/teams/abc")).toBe(true);
    const join = navigationItems("account").find((item) => item.id === "join")!;
    expect(isNavigationItemActive(join, "/register-player")).toBe(true);
    const captain = navigationItems("captain").find((item) => item.id === "captain")!;
    expect(isNavigationItemActive(captain, "/captain")).toBe(true);
  });
});

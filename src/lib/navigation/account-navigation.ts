/**
 * Account-state bottom navigation (docs/project-knowledge/product-master-specification.md,
 * "Navigation and account states"; evidence: docs/reference-assets/visual-references).
 * Presentation only: every destination enforces its own permissions on the server.
 */
export type NavigationMode = "visitor" | "account" | "onboarding" | "player" | "captain";

export type NavigationItem = {
  id: "home" | "match-centre" | "teams" | "join" | "captain" | "more";
  to: "/" | "/player" | "/match-centre" | "/teams" | "/join" | "/captain" | "/more";
  label: string;
  icon: "home" | "match" | "teams" | "join" | "captain" | "more";
};

export type AccountFacts = {
  signedIn: boolean;
  player: { registration_status: string; is_banned: boolean } | null;
  activeMemberships: { is_captain: boolean }[];
};

export function isApprovedPlayer(player: AccountFacts["player"]): boolean {
  return Boolean(player && player.registration_status === "registered" && !player.is_banned);
}

/**
 * visitor: signed out. account: signed in but not an approved player (registering, pending, banned).
 * onboarding: approved player without an active team. player / captain: in an active team.
 */
export function resolveNavigationMode(facts: AccountFacts): NavigationMode {
  if (!facts.signedIn) return "visitor";
  if (!isApprovedPlayer(facts.player)) return "account";
  if (facts.activeMemberships.length === 0) return "onboarding";
  return facts.activeMemberships.some((membership) => membership.is_captain) ? "captain" : "player";
}

const MATCH_CENTRE: NavigationItem = { id: "match-centre", to: "/match-centre", label: "Match Centre", icon: "match" };
const TEAMS: NavigationItem = { id: "teams", to: "/teams", label: "Teams", icon: "teams" };
const JOIN: NavigationItem = { id: "join", to: "/join", label: "Join Open Play", icon: "join" };
const MORE: NavigationItem = { id: "more", to: "/more", label: "More", icon: "more" };

export function navigationItems(mode: NavigationMode, approvedPlayer = false): NavigationItem[] {
  const playerHome: NavigationItem = { id: "home", to: "/player", label: "Home", icon: "home" };
  switch (mode) {
    case "visitor":
    case "account":
      // IMG_0581, IMG_0562 (signed out); IMG_0563-0567 (signed in, player registration not yet approved).
      return [{ id: "home", to: "/", label: "Home", icon: "home" }, MATCH_CENTRE, JOIN, MORE];
    case "onboarding":
      // IMG_0582 / IMG_0583: transitional five-tab bar for an approved player without a team.
      return [{ id: "home", to: approvedPlayer ? "/player" : "/", label: "Home", icon: "home" }, MATCH_CENTRE, TEAMS, JOIN, MORE];
    case "player":
      // IMG_0522, IMG_0532-0542, IMG_0572-0580: Home is the Player Hub; never Join Open Play.
      return [playerHome, MATCH_CENTRE, TEAMS, MORE];
    case "captain":
      // IMG_0543: player tabs plus Captain's Hub.
      return [playerHome, MATCH_CENTRE, TEAMS, { id: "captain", to: "/captain", label: "Captain's Hub", icon: "captain" }, MORE];
  }
}

export function isNavigationItemActive(item: NavigationItem, pathname: string): boolean {
  if (item.id === "home") return pathname === "/" || pathname === "/player" || pathname.startsWith("/player/");
  if (item.id === "join") return pathname === "/join" || pathname === "/leagues" || pathname === "/register-player";
  if (item.id === "teams") return pathname === "/teams" || pathname.startsWith("/teams/");
  return pathname === item.to;
}

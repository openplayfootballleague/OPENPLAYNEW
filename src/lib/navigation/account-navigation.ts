/**
 * Account-state bottom navigation (docs/project-knowledge/product-master-specification.md,
 * "Navigation and account states"; evidence: docs/reference-assets/visual-references).
 * Presentation only: every destination enforces its own permissions on the server.
 */
export type NavigationMode = "visitor" | "onboarding" | "player" | "captain";

export type NavigationItem = {
  id: "home" | "match-centre" | "teams" | "join" | "club" | "matchday" | "more";
  to: "/" | "/player" | "/match-centre" | "/teams" | "/join" | "/captain" | "/more";
  hash?: "#captain-club" | "#captain-matchday";
  label: string;
  icon: "home" | "match" | "teams" | "join" | "whistle" | "more";
};

export type AccountFacts = {
  signedIn: boolean;
  player: { registration_status: string; is_banned: boolean } | null;
  activeMemberships: { is_captain: boolean }[];
};

export function isApprovedPlayer(player: AccountFacts["player"]): boolean {
  return Boolean(player && player.registration_status === "registered" && !player.is_banned);
}

/** Visitor (signed out), onboarding (signed in, no active team), player or captain (in a team). */
export function resolveNavigationMode(facts: AccountFacts): NavigationMode {
  if (!facts.signedIn) return "visitor";
  if (!isApprovedPlayer(facts.player) || facts.activeMemberships.length === 0) return "onboarding";
  return facts.activeMemberships.some((membership) => membership.is_captain) ? "captain" : "player";
}

const MATCH_CENTRE: NavigationItem = { id: "match-centre", to: "/match-centre", label: "Match Centre", icon: "match" };
const TEAMS: NavigationItem = { id: "teams", to: "/teams", label: "Teams", icon: "teams" };
const JOIN: NavigationItem = { id: "join", to: "/join", label: "Join Open Play", icon: "join" };
const MORE: NavigationItem = { id: "more", to: "/more", label: "More", icon: "more" };

export function navigationItems(mode: NavigationMode, approvedPlayer = false): NavigationItem[] {
  switch (mode) {
    case "visitor":
      // IMG_0581: four tabs for signed-out visitors.
      return [{ id: "home", to: "/", label: "Home", icon: "home" }, MATCH_CENTRE, JOIN, MORE];
    case "onboarding":
      // IMG_0582 / IMG_0583: transitional five-tab bar until the account belongs to a team.
      return [{ id: "home", to: approvedPlayer ? "/player" : "/", label: "Home", icon: "home" }, MATCH_CENTRE, TEAMS, JOIN, MORE];
    case "player":
      // IMG_0572–IMG_0576, IMG_0579, IMG_0580: four persistent tabs; no Join Open Play.
      return [{ id: "home", to: "/player", label: "Player Hub", icon: "home" }, MATCH_CENTRE, TEAMS, MORE];
    case "captain":
      // No reference image; existing captain workspace tabs retained pending owner confirmation.
      return [
        { id: "home", to: "/player", label: "Player Hub", icon: "home" },
        { id: "club", to: "/captain", hash: "#captain-club", label: "Club", icon: "teams" },
        { id: "matchday", to: "/captain", hash: "#captain-matchday", label: "Matchday", icon: "whistle" },
        MORE,
      ];
  }
}

export function isNavigationItemActive(item: NavigationItem, pathname: string, hash: string): boolean {
  if (item.id === "home") return pathname === "/" || pathname === "/player";
  if (item.id === "club") return pathname === "/captain" && hash !== "#captain-matchday";
  if (item.id === "matchday") return pathname === "/captain" && hash === "#captain-matchday";
  if (item.id === "join") return pathname === "/join" || pathname === "/leagues";
  return pathname === item.to;
}

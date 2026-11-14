/**
 * Bottom navigation (docs/project-knowledge/product-master-specification.md, "Navigation and account states").
 * Presentation only: every destination enforces its own permissions on the server.
 */
export type NavigationMode = "visitor" | "account" | "onboarding" | "player" | "captain";

export type NavigationItem = {
  id: "home" | "match-centre" | "teams" | "join" | "more";
  to: "/" | "/player" | "/match-centre" | "/teams" | "/join" | "/captain" | "/more";
  label: string;
  icon: "home" | "match" | "teams" | "join" | "more";
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
 * visitor: signed out. account: signed in but not an approved player (registering, pending, restricted).
 * onboarding: approved player without an active team. player / captain: in an active team.
 * The modes drive Home's destination and Captain Hub access; the bar itself is the agreed five tabs.
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

/** Registration screens keep the simplified four-tab bar with Join Open Play highlighted (owner spec 5). */
export const REGISTRATION_ROUTES = ["/sign-up", "/register-player"] as const;
export function isRegistrationRoute(pathname: string): boolean {
  return (REGISTRATION_ROUTES as readonly string[]).includes(pathname) || pathname.startsWith("/join/team");
}

/** Home is the Player Hub for approved players; everyone else lands on public Home. */
export function homeDestination(mode: NavigationMode): "/" | "/player" {
  return mode === "onboarding" || mode === "player" || mode === "captain" ? "/player" : "/";
}

/**
 * Owner specification (2026-11-14, section 5): every account state uses the same five tabs —
 * Home (Player Hub when signed in as an approved player), Match Centre, Teams, Join Open Play, More.
 * Captain areas (Club, Matchday) are reached from the Player Hub and More, never a second bar.
 */
export function navigationItems(mode: NavigationMode, pathname = ""): NavigationItem[] {
  const home: NavigationItem = { id: "home", to: homeDestination(mode), label: "Home", icon: "home" };
  if (isRegistrationRoute(pathname)) return [home, MATCH_CENTRE, JOIN, MORE];
  return [home, MATCH_CENTRE, TEAMS, JOIN, MORE];
}

export function isNavigationItemActive(item: NavigationItem, pathname: string): boolean {
  if (item.id === "join") return pathname === "/join" || pathname.startsWith("/join/") || pathname === "/leagues" || isRegistrationRoute(pathname);
  if (item.id === "home") return pathname === "/" || pathname === "/player" || pathname.startsWith("/player/");
  if (item.id === "teams") return pathname === "/teams" || pathname.startsWith("/teams/");
  return pathname === item.to;
}

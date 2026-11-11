import { Link, useRouterState } from "@tanstack/react-router";

type NavIconName = "home" | "match" | "join" | "more";

function NavIcon({ name }: { name: NavIconName }) {
  const common = { width: 24, height: 24, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, "aria-hidden": true as const };
  switch (name) {
    case "home": return <svg {...common}><path d="m3 10 9-7 9 7" /><path d="M5 9v11h14V9M9 20v-6h6v6" /></svg>;
    case "match": return <svg {...common}><path d="M8 21h8M12 17v4M7 4h10l2 4-7 5-7-5 2-4Z" /><path d="m5 8-2 7 4 3 5-3 5 3 4-3-2-7" /></svg>;
    case "join": return <svg {...common}><circle cx="9" cy="8" r="4" /><path d="M2 21v-2a7 7 0 0 1 7-7h1M19 8v8M15 12h8" /></svg>;
    case "more": return <svg {...common}><circle cx="5" cy="12" r="1" /><circle cx="12" cy="12" r="1" /><circle cx="19" cy="12" r="1" /></svg>;
  }
}

const items = [
  { to: "/player", label: "Home", icon: "home" },
  { to: "/match-centre", label: "Match Centre", icon: "match" },
  { to: "/join", label: "Join Open Play", icon: "join" },
  { to: "/more", label: "More", icon: "more" },
] as const;

const PLAYER_PATHS = ["/player", "/match-centre", "/teams", "/join", "/more", "/messages", "/captain", "/register-player", "/sign-in", "/sign-up", "/reset-password"];

export function BottomNavigation() {
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const isPlayerPage = PLAYER_PATHS.some((path) => pathname === path || pathname.startsWith(path + "/"));
  if (!isPlayerPage || pathname === "/sign-in" || pathname === "/sign-up" || pathname === "/reset-password" || pathname === "/register-player") return null;

  return (
    <nav className="bottom-navigation" aria-label="Primary navigation">
      {items.map((item) => (
        <Link key={item.to} to={item.to} className="bottom-navigation-item"
          activeOptions={{ exact: item.to === "/player" }}
          activeProps={{ "aria-current": "page" }}>
          <span className="bottom-navigation-icon"><NavIcon name={item.icon} /></span>
          <span>{item.label}</span>
        </Link>
      ))}
    </nav>
  );
}

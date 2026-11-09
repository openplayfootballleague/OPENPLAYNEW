import { Link, useRouterState } from "@tanstack/react-router";

const items = [
  { to: "/" as const, label: "Home", icon: "home" },
  { to: "/match-centre" as const, label: "Match Centre", icon: "trophy" },
  { to: "/join" as const, label: "Join Open Play", icon: "user-plus" },
  { to: "/more" as const, label: "More", icon: "more" },
];

function NavIcon({ name }: { name: string }) {
  const common = { fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  if (name === "home") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="m3 10 9-7 9 7"/><path d="M5 9v12h14V9M9 21v-7h6v7"/></svg>;
  if (name === "trophy") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0V4ZM7 6H3v2a4 4 0 0 0 4 4m10-6h4v2a4 4 0 0 1-4 4"/></svg>;
  if (name === "more") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></svg>;
  return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="M16 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="10" cy="7" r="4"/><path d="M19 8v6m-3-3h6"/></svg>;
}

export function PlayerBottomNavigation() {
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  return (
    <nav className="player-bottom-nav" aria-label="Main navigation">
      {items.map((item) => (
        <Link key={item.to} to={item.to} className={`player-bottom-nav-link${(item.to === "/" ? pathname === "/" || pathname === "/player" : pathname === item.to) ? " active" : ""}`}>
          <NavIcon name={item.icon} />
          <span>{item.label}</span>
        </Link>
      ))}
    </nav>
  );
}

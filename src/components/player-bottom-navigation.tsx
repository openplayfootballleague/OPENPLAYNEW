import { Link } from "@tanstack/react-router";

const items = [
  { to: "/player" as const, label: "Home", icon: "home" },
  { to: "/match-centre" as const, label: "Matches", icon: "trophy" },
  { to: "/teams" as const, label: "Teams", icon: "shield" },
  { to: "/join" as const, label: "Join", icon: "user-plus" },
];

function NavIcon({ name }: { name: string }) {
  const common = { fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  if (name === "home") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="m3 10 9-7 9 7"/><path d="M5 9v12h14V9M9 21v-7h6v7"/></svg>;
  if (name === "trophy") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0V4ZM7 6H3v2a4 4 0 0 0 4 4m10-6h4v2a4 4 0 0 1-4 4"/></svg>;
  if (name === "shield") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11Z"/><path d="m9 12 2 2 4-4"/></svg>;
  return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="M16 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="10" cy="7" r="4"/><path d="M19 8v6m-3-3h6"/></svg>;
}

export function PlayerBottomNavigation() {
  return (
    <nav className="player-bottom-nav" aria-label="Main navigation">
      {items.map((item) => (
        <Link key={item.to} to={item.to} activeOptions={{ exact: item.to === "/player" }} activeProps={{ className: "active" }} className="player-bottom-nav-link">
          <NavIcon name={item.icon} />
          <span>{item.label}</span>
        </Link>
      ))}
    </nav>
  );
}

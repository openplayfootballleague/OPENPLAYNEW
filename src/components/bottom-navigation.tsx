import { Link } from "@tanstack/react-router";

const items = [
  { to: "/", label: "Home", icon: "⌂" },
  { to: "/match-centre", label: "Match Centre", icon: "◷" },
  { to: "/join", label: "Join Open Play", icon: "+" },
  { to: "/more", label: "More", icon: "•••" },
] as const;

export function BottomNavigation() {
  return (
    <nav className="bottom-navigation" aria-label="Primary navigation">
      {items.map((item) => (
        <Link
          key={item.to}
          to={item.to}
          className="bottom-navigation-item"
          activeOptions={{ exact: item.to === "/" }}
          activeProps={{ "aria-current": "page" }}
        >
          <span className="bottom-navigation-icon" aria-hidden="true">{item.icon}</span>
          <span>{item.label}</span>
        </Link>
      ))}
    </nav>
  );
}

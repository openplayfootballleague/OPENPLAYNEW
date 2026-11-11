import {
  HeadContent,
  Link,
  Outlet,
  Scripts,
  createRootRoute,
  useRouterState,
} from "@tanstack/react-router";
import type { ReactNode } from "react";
import "../styles.css";
import "../app-visual-system.css";

export const Route = createRootRoute({
  head: () => ({
    links: [{ rel: "icon", href: "/favicon.svg", type: "image/svg+xml" }],
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { title: "Open Play | Football, organised" },
      {
        name: "description",
        content:
          "The home of Open Play — fixtures, results, teams and league management.",
      },
      { name: "theme-color", content: "#080808" },
    ],
  }),
  component: RootComponent,
});

function RootComponent() {
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const standalone =
    pathname === "/" ||
    ["/sign-in", "/sign-up", "/reset-password", "/register-player"].includes(pathname) ||
    pathname.startsWith("/admin") ||
    pathname.startsWith("/finance");

  if (standalone) {
    return (
      <RootDocument>
        <Outlet />
      </RootDocument>
    );
  }

  const captainView = pathname === "/captain" || pathname.startsWith("/captain/");
  return (
    <RootDocument>
      <div className="openplay-app-frame">
        <header className="openplay-app-header">
          <Link className="openplay-app-brand" to="/player" aria-label="Open Play Player Hub">
            <img className="openplay-app-mark" src="/open-play-logo.webp" alt="" />
            <span>OPEN PLAY</span>
          </Link>
          <div className="openplay-header-actions">
            <Link className="openplay-location" to="/teams" aria-label="Explore Open Play locations"><NavIcon name="pin" /><span>ALL LOCATIONS</span></Link>
            {(captainView || pathname === "/player") && <span className="openplay-role-badge">{captainView ? "CAPTAIN" : "PLAYER"}</span>}
            <Link className="openplay-account" to="/player" aria-label="Player account"><NavIcon name="user" /></Link>
          </div>
        </header>
        <div className="openplay-app-content"><Outlet /></div>
        {captainView ? (
          <nav className="openplay-bottom-nav captain-nav" aria-label="Captain navigation">
            <Link to="/player" className={pathname === "/player" ? "active" : ""}><NavIcon name="home" /><small>HOME</small></Link>
            <a href="/captain#club" className="active"><NavIcon name="shield" /><small>CLUB</small></a>
            <a href="/captain#matchday"><NavIcon name="trophy" /><small>MATCHDAY</small></a>
            <Link to="/more" className={pathname.startsWith("/more") ? "active" : ""}><NavIcon name="menu" /><small>MORE</small></Link>
          </nav>
        ) : (
          <nav className="openplay-bottom-nav" aria-label="Player navigation">
            <Link to="/player" className={pathname === "/player" ? "active" : ""}><NavIcon name="home" /><small>HOME</small></Link>
            <Link to="/match-centre" className={pathname.startsWith("/match-centre") ? "active" : ""}><NavIcon name="trophy" /><small>MATCH CENTRE</small></Link>
            <Link to="/teams" className={pathname.startsWith("/teams") ? "active" : ""}><NavIcon name="shield" /><small>TEAMS</small></Link>
            <Link to="/more" className={pathname.startsWith("/more") ? "active" : ""}><NavIcon name="menu" /><small>MORE</small></Link>
          </nav>
        )}
      </div>
    </RootDocument>
  );
}

function RootDocument({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <head><HeadContent /></head>
      <body>{children}<Scripts /></body>
    </html>
  );
}

function NavIcon({ name }: { name: "pin" | "user" | "home" | "trophy" | "shield" | "crown" | "menu" }) {
  const common = { viewBox: "0 0 24 24", "aria-hidden": true as const, focusable: false as const };
  switch (name) {
    case "pin": return <svg {...common}><path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></svg>;
    case "user": return <svg {...common}><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>;
    case "home": return <svg {...common}><path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z"/></svg>;
    case "trophy": return <svg {...common}><path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0Z"/><path d="M7 6H3v2a4 4 0 0 0 4 4M17 6h4v2a4 4 0 0 1-4 4"/></svg>;
    case "shield": return <svg {...common}><path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11Z"/></svg>;
    case "crown": return <svg {...common}><path d="m2 7 5 4 5-7 5 7 5-4-2 12H4Z"/><path d="M4 22h16"/></svg>;
    case "menu": return <svg {...common}><path d="M4 6h16M4 12h16M4 18h16"/></svg>;
  }
}

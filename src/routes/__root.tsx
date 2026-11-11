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
            <span className="openplay-app-mark">OP</span>
            <span>OPEN PLAY</span>
          </Link>
          <div className="openplay-header-actions">
            <span className="openplay-location"><span aria-hidden="true">⌖</span> Bideford</span>
            <Link className="openplay-account" to="/player" aria-label="Player account">♙</Link>
          </div>
        </header>
        <div className="openplay-app-content"><Outlet /></div>
        <nav className={captainView ? "openplay-bottom-nav captain-nav" : "openplay-bottom-nav"} aria-label="Player navigation">
          <Link to="/player" className={pathname === "/player" ? "active" : ""}><span aria-hidden="true">⌂</span><small>HOME</small></Link>
          <Link to="/match-centre" className={pathname.startsWith("/match-centre") ? "active" : ""}><span aria-hidden="true">♜</span><small>MATCH CENTRE</small></Link>
          <Link to="/teams" className={pathname.startsWith("/teams") ? "active" : ""}><span aria-hidden="true">♢</span><small>TEAMS</small></Link>
          {captainView && <Link to="/captain" className="active"><span aria-hidden="true">♛</span><small>CAPTAIN'S HUB</small></Link>}
          <Link to="/more" className={pathname.startsWith("/more") ? "active" : ""}><span aria-hidden="true">☰</span><small>MORE</small></Link>
        </nav>
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

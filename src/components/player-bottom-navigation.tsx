import { useEffect, useState } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

type NavigationMode = "loading" | "viewer" | "player" | "captain";
type AppPath = "/" | "/player" | "/match-centre" | "/join" | "/teams" | "/captain" | "/more";
type NavItem = { to: AppPath; hash?: string; label: string; icon: string; activePaths?: string[] };

function NavIcon({ name }: { name: string }) {
  const common = { fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  if (name === "home") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="m3 10 9-7 9 7" /><path d="M5 9v12h14V9M9 21v-7h6v7" /></svg>;
  if (name === "trophy") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0V4ZM7 6H3v2a4 4 0 0 0 4 4m10-6h4v2a4 4 0 0 1-4 4" /></svg>;
  if (name === "more") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><circle cx="5" cy="12" r="1" /><circle cx="12" cy="12" r="1" /><circle cx="19" cy="12" r="1" /></svg>;
  if (name === "club") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="M3 21h18M5 21V7l7-4 7 4v14M9 21v-6h6v6M9 9h.01M15 9h.01" /></svg>;
  return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="M16 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" /><circle cx="10" cy="7" r="4" /><path d="M19 8v6m-3-3h6" /></svg>;
}

export function PlayerBottomNavigation() {
  const location = useRouterState({ select: (state) => state.location });
  const [mode, setMode] = useState<NavigationMode>("loading");

  useEffect(() => {
    const supabase = getSupabaseClient();
    let alive = true;
    let requestSequence = 0;

    async function resolveMode() {
      const sequence = ++requestSequence;
      try {
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        if (!alive || sequence !== requestSequence) return;
        if (sessionError || !session) {
          setMode("viewer");
          return;
        }

        const [playerResult, captainResult] = await Promise.all([
          supabase.from("players").select("registration_status,is_banned").eq("user_id", session.user.id).maybeSingle(),
          supabase.from("team_memberships").select("is_captain").eq("user_id", session.user.id).eq("status", "active").eq("is_captain", true),
        ]);
        if (!alive || sequence !== requestSequence) return;
        const registeredPlayer = !playerResult.error && playerResult.data?.registration_status === "registered" && playerResult.data.is_banned !== true;
        if (!registeredPlayer) {
          setMode("viewer");
          return;
        }
        setMode(!captainResult.error && (captainResult.data ?? []).some((membership) => membership.is_captain) ? "captain" : "player");
      } catch {
        if (alive && sequence === requestSequence) setMode("viewer");
      }
    }

    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => { void resolveMode(); });
    return () => {
      alive = false;
      subscription.unsubscribe();
    };
  }, []);

  if (mode === "loading") return null;

  const items: NavItem[] = mode === "captain"
    ? [
        { to: "/player", label: "Home", icon: "home" },
        { to: "/captain", hash: "club", label: "Club", icon: "club" },
        { to: "/captain", hash: "matchday", label: "Matchday", icon: "trophy" },
        { to: "/more", label: "More", icon: "more" },
      ]
    : mode === "player"
      ? [
          { to: "/player", label: "Player Hub", icon: "home" },
          { to: "/match-centre", label: "Match Centre", icon: "trophy" },
          { to: "/teams", label: "Teams", icon: "club" },
          { to: "/more", label: "More", icon: "more" },
        ]
      : [
          { to: "/", label: "Home", icon: "home", activePaths: ["/", "/player"] },
          { to: "/match-centre", label: "Match Centre", icon: "trophy" },
          { to: "/join", label: "Join Open Play", icon: "user-plus" },
          { to: "/more", label: "More", icon: "more" },
        ];

  return (
    <nav className="player-bottom-nav" aria-label={mode === "captain" ? "Captain navigation" : "Main navigation"}>
      {items.map((item) => {
        const active = item.hash
          ? location.pathname === item.to && (location.hash === `#${item.hash}` || (!location.hash && item.hash === "club"))
          : (item.activePaths ?? [item.to]).includes(location.pathname);
        return (
          <Link
            key={item.label}
            to={item.to}
            hash={item.hash}
            className={`player-bottom-nav-link${active ? " active" : ""}`}
            aria-current={active ? "page" : undefined}
          >
            <NavIcon name={item.icon} />
            <span>{item.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}

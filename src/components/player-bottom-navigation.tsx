import { useEffect, useState } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

type NavigationMode = "viewer" | "player" | "captain";

type NavigationItem = {
  id: "home" | "match-centre" | "teams" | "join" | "club" | "matchday" | "more";
  to: "/" | "/player" | "/match-centre" | "/teams" | "/join" | "/captain" | "/more";
  hash?: "#captain-club" | "#captain-matchday";
  label: string;
  icon: "home" | "match" | "teams" | "whistle" | "more";
};

function NavIcon({ name }: { name: NavigationItem["icon"] }) {
  const common = { fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  if (name === "home") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="m3 10 9-7 9 7" /><path d="M5 9v12h14V9M9 21v-7h6v7" /></svg>;
  if (name === "match") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><circle cx="12" cy="12" r="9" /><path d="m12 7 3 2v4l-3 2-3-2V9l3-2ZM9 9l-4-2m10 2 4-2M9 13l-2 5m8-5 2 5" /></svg>;
  if (name === "teams") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><circle cx="9" cy="8" r="3" /><circle cx="17" cy="9" r="2.5" /><path d="M3 20v-2a6 6 0 0 1 12 0v2M16 15a5 5 0 0 1 5 5" /></svg>;
  if (name === "whistle") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="M4 11h10a6 6 0 1 1-6 6v-2H4a2 2 0 0 1 0-4Z" /><path d="M14 11V7h4l3 4M8 15h3" /></svg>;
  return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><circle cx="5" cy="12" r="1" /><circle cx="12" cy="12" r="1" /><circle cx="19" cy="12" r="1" /></svg>;
}

/** Account-aware four-tab navigation. Only active captains receive Club and Matchday tabs. */
export function PlayerBottomNavigation({ variant = "account" }: { variant?: "account" | "join" }) {
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const hash = useRouterState({ select: (state) => state.location.hash });
  const [mode, setMode] = useState<NavigationMode>("viewer");

  useEffect(() => {
    if (variant === "join") {
      setMode("player");
      return;
    }
    let alive = true;
    let requestSequence = 0;
    const supabase = getSupabaseClient();

    async function resolveMode() {
      const sequence = ++requestSequence;
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      if (!alive || sequence !== requestSequence) return;
      if (sessionError || !session) {
        setMode("viewer");
        return;
      }

      const [{ data: player, error: playerError }, { data: captainRows, error: captainError }] = await Promise.all([
        supabase.from("players").select("registration_status,is_banned").eq("user_id", session.user.id).maybeSingle(),
        supabase.from("team_memberships").select("season_team_id").eq("user_id", session.user.id).eq("status", "active").eq("is_captain", true).limit(1),
      ]);
      if (!alive || sequence !== requestSequence) return;
      if (playerError || captainError || !player || player.registration_status !== "registered" || player.is_banned) {
        setMode("viewer");
        return;
      }
      setMode((captainRows ?? []).length > 0 ? "captain" : "player");
    }

    void resolveMode();
    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => {
      void resolveMode();
    });
    return () => {
      alive = false;
      requestSequence += 1;
      subscription.unsubscribe();
    };
  }, [variant]);

  const items: NavigationItem[] = variant === "join"
    ? [
        { id: "home", to: "/player", label: "Home", icon: "home" },
        { id: "match-centre", to: "/match-centre", label: "Match Centre", icon: "match" },
        { id: "join", to: "/join", label: "Join Open Play", icon: "teams" },
        { id: "more", to: "/more", label: "More", icon: "more" },
      ]
    : mode === "captain"
    ? [
        { id: "home", to: "/player", label: "Home", icon: "home" },
        { id: "club", to: "/captain", hash: "#captain-club", label: "Club", icon: "teams" },
        { id: "matchday", to: "/captain", hash: "#captain-matchday", label: "Matchday", icon: "whistle" },
        { id: "more", to: "/more", label: "More", icon: "more" },
      ]
    : [
        { id: "home", to: mode === "player" ? "/player" : "/", label: "Home", icon: "home" },
        { id: "match-centre", to: "/match-centre", label: "Match Centre", icon: "match" },
        { id: "teams", to: "/teams", label: "Teams", icon: "teams" },
        { id: "more", to: "/more", label: "More", icon: "more" },
      ];

  function isActive(item: NavigationItem) {
    if (variant === "join") return pathname === item.to;
    if (item.id === "home") return pathname === "/" || pathname === "/player";
    if (item.id === "club") return pathname === "/captain" && hash !== "#captain-matchday";
    if (item.id === "matchday") return pathname === "/captain" && hash === "#captain-matchday";
    return pathname === item.to;
  }

  return (
    <nav className="player-bottom-nav" aria-label={variant === "join" ? "Join Open Play navigation" : mode === "captain" ? "Captain navigation" : "Main navigation"}>
      {items.map((item) => (
        <Link key={item.id} to={item.to} hash={item.hash} className={"player-bottom-nav-link" + (isActive(item) ? " active" : "")}>
          <NavIcon name={item.icon} />
          <span>{item.label}</span>
        </Link>
      ))}
    </nav>
  );
}

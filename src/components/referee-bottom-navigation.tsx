import { useEffect, useState } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";
import { PlayerBottomNavigation } from "./player-bottom-navigation";

type RpcClient = {
  rpc(name: string): Promise<{ data: unknown; error: { message: string } | null }>;
};

type PortalState = {
  membership?: { status?: "active" | "suspended" } | null;
};

const items = [
  { to: "/referee" as const, label: "Home", icon: "home" },
  { to: "/match-centre" as const, label: "Match Centre", icon: "match" },
  { to: "/referee/matchday" as const, label: "Matchday", icon: "whistle" },
  { to: "/more" as const, label: "More", icon: "more" },
];

function RefereeIcon({ name }: { name: string }) {
  const common = { fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  if (name === "home") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="m3 10 9-7 9 7" /><path d="M5 9v12h14V9M9 21v-7h6v7" /></svg>;
  if (name === "match") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><circle cx="12" cy="12" r="9" /><path d="m12 7 3 2v4l-3 2-3-2V9l3-2ZM9 9l-4-2m10 2 4-2M9 13l-2 5m8-5 2 5" /></svg>;
  if (name === "teams") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><circle cx="9" cy="8" r="3" /><circle cx="17" cy="9" r="2.5" /><path d="M3 20v-2a6 6 0 0 1 12 0v2M16 15a5 5 0 0 1 5 5" /></svg>;
  if (name === "whistle") return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><path d="M4 11h10a6 6 0 1 1-6 6v-2H4a2 2 0 0 1 0-4Z" /><path d="M14 11V7h4l3 4M8 15h3" /></svg>;
  return <svg viewBox="0 0 24 24" aria-hidden="true" {...common}><circle cx="5" cy="12" r="1" /><circle cx="12" cy="12" r="1" /><circle cx="19" cy="12" r="1" /></svg>;
}

/** Only an active, server-approved referee membership switches the navigation. */
export function RefereeBottomNavigation() {
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const [membership, setMembership] = useState<"loading" | "active" | "other">("loading");

  useEffect(() => {
    let alive = true;
    async function load() {
      const supabase = getSupabaseClient();
      const { data: { session } } = await supabase.auth.getSession();
      if (!alive) return;
      if (!session) {
        setMembership("other");
        return;
      }
      const rpc = supabase as unknown as RpcClient;
      const result = await rpc.rpc("get_my_referee_portal_state");
      if (!alive) return;
      if (result.error || !result.data || typeof result.data !== "object") {
        setMembership("other");
        return;
      }
      const portal = result.data as PortalState;
      setMembership(portal.membership?.status === "active" ? "active" : "other");
    }
    void load();
    return () => { alive = false; };
  }, []);

  if (membership !== "active" || !pathname.startsWith("/referee")) return <PlayerBottomNavigation />;

  return (
    <nav className="player-bottom-nav" aria-label="Referee navigation">
      {items.map((item) => (
        <Link
          key={item.to}
          to={item.to}
          className={`player-bottom-nav-link${pathname === item.to || (item.to === "/referee" && pathname === "/referee") ? " active" : ""}`}
        >
          <RefereeIcon name={item.icon} />
          <span>{item.label}</span>
        </Link>
      ))}
    </nav>
  );
}

import { useEffect, useState } from "react";
import { ClipboardList, House, Menu, Shield, Trophy, type LucideIcon } from "lucide-react";
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

const REFEREE_ICONS: Record<string, LucideIcon> = { home: House, match: Trophy, teams: Shield, whistle: ClipboardList };

function RefereeIcon({ name }: { name: string }) {
  const Icon = REFEREE_ICONS[name] ?? Menu;
  return <Icon aria-hidden="true" strokeWidth={1.8} />;
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

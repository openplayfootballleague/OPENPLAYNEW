import { useEffect, useState } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import { House, Menu, Shield, Trophy, UserPlus, type LucideIcon } from "lucide-react";
import { getSupabaseClient } from "../lib/supabase/client";
import {
  isNavigationItemActive, navigationItems, resolveNavigationMode,
  type NavigationItem, type NavigationMode,
} from "../lib/navigation/account-navigation";

const NAV_ICONS: Record<NavigationItem["icon"], LucideIcon> = { home: House, match: Trophy, teams: Shield, join: UserPlus, more: Menu };

function NavIcon({ name }: { name: NavigationItem["icon"] }) {
  const Icon = NAV_ICONS[name];
  return <Icon aria-hidden="true" strokeWidth={1.8} />;
}

/** Account-state bottom navigation; rules and evidence live in lib/navigation/account-navigation. */
export function PlayerBottomNavigation() {
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const [state, setState] = useState<{ mode: NavigationMode | "loading" }>({ mode: "loading" });

  useEffect(() => {
    let alive = true;
    let requestSequence = 0;
    const supabase = getSupabaseClient();

    async function resolveMode() {
      const sequence = ++requestSequence;
      try {
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        if (!alive || sequence !== requestSequence) return;
        if (sessionError || !session) {
          setState({ mode: "visitor" });
          return;
        }
        const [{ data: player, error: playerError }, { data: memberships, error: membershipError }] = await Promise.all([
          supabase.from("players").select("registration_status,is_banned").eq("user_id", session.user.id).maybeSingle(),
          supabase.from("team_memberships").select("is_captain").eq("user_id", session.user.id).eq("status", "active"),
        ]);
        if (!alive || sequence !== requestSequence) return;
        if (playerError || membershipError) {
          // Fail closed to the signed-in account bar; destinations still enforce access server-side.
          setState({ mode: "account" });
          return;
        }
        setState({ mode: resolveNavigationMode({ signedIn: true, player: player ?? null, activeMemberships: memberships ?? [] }) });
      } catch {
        if (alive && sequence === requestSequence) setState({ mode: "visitor" });
      }
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
  }, []);

  if (state.mode === "loading") return null;
  const mode = state.mode;
  const items: NavigationItem[] = navigationItems(mode, pathname);

  return (
    <nav className="player-bottom-nav" data-tabs={items.length} aria-label="Main navigation">
      {items.map((item) => (
        <Link key={item.id} to={item.to} className={"player-bottom-nav-link" + (isNavigationItemActive(item, pathname) ? " active" : "")}
          aria-current={isNavigationItemActive(item, pathname) ? "page" : undefined}>
          <NavIcon name={item.icon} />
          <span>{item.label}</span>
        </Link>
      ))}
    </nav>
  );
}

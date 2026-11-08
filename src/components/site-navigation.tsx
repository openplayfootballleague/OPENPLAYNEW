import { useEffect, useState } from "react";
import { Link } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

type Access = {
  signedIn: boolean;
  approvedPlayer: boolean;
  captain: boolean;
  admin: boolean;
  finance: boolean;
  loading: boolean;
};

const signedOut: Access = {
  signedIn: false,
  approvedPlayer: false,
  captain: false,
  admin: false,
  finance: false,
  loading: false,
};

export function SiteNavigation() {
  const [access, setAccess] = useState<Access>({ ...signedOut, loading: true });

  useEffect(() => {
    let alive = true;
    const supabase = getSupabaseClient();

    async function load() {
      const { data: { session } } = await supabase.auth.getSession();
      if (!alive) return;
      if (!session) {
        setAccess(signedOut);
        return;
      }

      const [{ data: player }, { data: memberships }, { data: roles }] = await Promise.all([
        supabase.from("players").select("registration_status,is_banned").eq("user_id", session.user.id).maybeSingle(),
        supabase.from("team_memberships").select("is_captain").eq("user_id", session.user.id).eq("status", "active").eq("is_captain", true),
        supabase.from("user_roles").select("role").eq("user_id", session.user.id),
      ]);
      if (!alive) return;

      const roleNames = (roles ?? []).map((row) => row.role);
      const approvedPlayer = player?.registration_status === "registered" && player.is_banned !== true;
      setAccess({
        signedIn: true,
        approvedPlayer,
        captain: approvedPlayer && (memberships ?? []).length > 0,
        admin: roleNames.some((role) => ["admin", "super_admin", "league_admin"].includes(role)),
        finance: roleNames.some((role) => ["admin", "super_admin", "finance_admin"].includes(role)),
        loading: false,
      });
    }

    void load();
    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => {
      // Defer the refresh until Supabase has finished its auth-state callback.
      queueMicrotask(() => { void load(); });
    });
    return () => {
      alive = false;
      subscription.unsubscribe();
    };
  }, []);

  const homeTarget = access.signedIn ? "/player" : "/";
  const showJoin = !access.approvedPlayer;
  const navLabel = access.captain ? "Matchday" : "Home";

  return (
    <header className="op-site-nav">
      <Link className="op-nav-brand" to={homeTarget} aria-label="Open Play home">
        <span>OPEN</span><strong>PLAY</strong>
      </Link>
      <nav aria-label="Open Play navigation">
        <Link to={homeTarget}>{navLabel}</Link>
        <Link to="/match-centre">Match Centre</Link>
        <Link to="/teams">Teams</Link>
        {showJoin && <Link to="/join">Join Open Play</Link>}
        {access.captain && <Link to="/captain">Matchday</Link>}
        {access.admin && <Link to="/admin">Admin</Link>}
        {access.finance && <Link to="/finance">Finance</Link>}
      </nav>
      <div className="op-nav-account">
        {access.signedIn ? <Link to="/player">My account</Link> : <Link to="/sign-in">Sign in</Link>}
      </div>
    </header>
  );
}

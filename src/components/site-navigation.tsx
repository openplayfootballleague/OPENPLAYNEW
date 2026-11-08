import { useEffect, useState } from "react";
import { Link } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

type Access = { signedIn: boolean; captain: boolean; admin: boolean; finance: boolean };

export function SiteNavigation() {
  const [access, setAccess] = useState<Access>({ signedIn: false, captain: false, admin: false, finance: false });
  useEffect(() => {
    let alive = true;
    const supabase = getSupabaseClient();
    async function load() {
      const { data: { session } } = await supabase.auth.getSession();
      if (!alive) return;
      if (!session) { setAccess({ signedIn: false, captain: false, admin: false, finance: false }); return; }
      const [{ data: roles }, { data: memberships }] = await Promise.all([
        supabase.from("user_roles").select("role").eq("user_id", session.user.id),
        supabase.from("team_memberships").select("is_captain").eq("user_id", session.user.id).eq("status", "active").eq("is_captain", true).limit(1),
      ]);
      if (!alive) return;
      const roleNames = (roles ?? []).map((row) => row.role);
      setAccess({
        signedIn: true,
        captain: (memberships ?? []).length > 0,
        admin: roleNames.some((role) => ["admin", "super_admin", "league_admin"].includes(role)),
        finance: roleNames.some((role) => ["admin", "super_admin", "finance_admin"].includes(role)),
      });
    }
    void load();
    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => { void load(); });
    return () => { alive = false; subscription.unsubscribe(); };
  }, []);

  return (
    <header className="op-site-nav">
      <Link className="op-nav-brand" to="/player" aria-label="Open Play Player Hub"><span>OPEN</span><strong>PLAY</strong></Link>
      <nav aria-label="Open Play navigation">
        <Link to="/player">Home</Link>
        <Link to="/match-centre">Match Centre</Link>
        <Link to="/teams">Teams</Link>
        <Link to="/join">Join Open Play</Link>
        {access.captain && <Link to="/captain">Captain Hub</Link>}
        {access.admin && <Link to="/admin">Admin</Link>}
        {access.finance && <Link to="/finance">Finance</Link>}
      </nav>
      <div className="op-nav-account">
        {access.signedIn ? <Link to="/player">My account</Link> : <Link to="/sign-in">Sign in</Link>}
      </div>
    </header>
  );
}

import { useEffect, useState } from "react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { RefereeBottomNavigation } from "../components/referee-bottom-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

type MoreAccess = {
  loading: boolean;
  signedIn: boolean;
  player: boolean;
  captain: boolean;
  admin: boolean;
  finance: boolean;
  referee: boolean;
};

const initialAccess: MoreAccess = {
  loading: true,
  signedIn: false,
  player: false,
  captain: false,
  admin: false,
  finance: false,
  referee: false,
};

export const Route = createFileRoute("/more")({ component: MorePage });

function MorePage() {
  const [access, setAccess] = useState<MoreAccess>(initialAccess);

  useEffect(() => {
    const supabase = getSupabaseClient();
    let active = true;

    async function loadAccess() {
      setAccess((current) => ({ ...current, loading: true }));
      const { data: { session } } = await supabase.auth.getSession();
      if (!active) return;

      if (!session) {
        setAccess({ ...initialAccess, loading: false });
        return;
      }

      const [
        { data: player, error: playerError },
        { data: memberships, error: membershipError },
        adminResult,
        financeResult,
        refereeResult,
      ] = await Promise.all([
        supabase
          .from("players")
          .select("registration_status,is_banned")
          .eq("user_id", session.user.id)
          .maybeSingle(),
        supabase
          .from("team_memberships")
          .select("status,is_captain")
          .eq("user_id", session.user.id)
          .eq("status", "active"),
        supabase.rpc("get_admin_context_preference"),
        supabase.rpc("get_finance_options"),
        supabase.from("referee_memberships").select("status").eq("user_id", session.user.id).eq("status", "active"),
      ]);

      if (!active) return;
      setAccess({
        loading: false,
        signedIn: true,
        player: !playerError && player?.registration_status === "registered" && !player.is_banned,
        captain: !membershipError && (memberships ?? []).some((membership) => membership.is_captain),
        admin: !adminResult.error && adminResult.data !== null,
        finance: !financeResult.error,
        referee: !refereeResult.error && (refereeResult.data ?? []).length > 0,
      });
    }

    void loadAccess();
    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => {
      void loadAccess();
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  async function signOut() {
    await getSupabaseClient().auth.signOut();
    setAccess({ ...initialAccess, loading: false });
  }

  const hasPrivateWorkspace = access.player || access.captain || access.admin || access.finance || access.referee;

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel hub-panel">
        <Link className="notice-brand" to="/">
          <img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" />
        </Link>
        <p className="eyebrow eyebrow-dark">OPEN PLAY</p>
        <h1>More<br /><em>to explore.</em></h1>
        <p>Public league information and the account options available to you.</p>

        <section className="hub-memberships">
          <div className="hub-section-heading"><span className="hub-kicker">EXPLORE</span></div>
          <Link className="admin-inline-action" to="/teams">TEAMS &amp; LEAGUES <span aria-hidden="true">↗</span></Link>
          <Link className="admin-inline-action" to="/gallery">MATCHDAY GALLERY <span aria-hidden="true">↗</span></Link>
          <Link className="admin-inline-action" to="/match-centre">FIXTURES, RESULTS &amp; TABLES <span aria-hidden="true">↗</span></Link>
          <Link className="admin-inline-action" to="/referee">REFEREE APPLICATION / WORKSPACE <span aria-hidden="true">↗</span></Link>
        </section>

        {access.loading ? (
          <p className="form-note" role="status">Checking which Open Play workspaces are available…</p>
        ) : hasPrivateWorkspace ? (
          <section className="hub-memberships">
            <div className="hub-section-heading"><span className="hub-kicker">YOUR OPEN PLAY</span></div>
            <Link className="admin-inline-action" to="/messages">MESSAGES &amp; SUPPORT <span aria-hidden="true">↗</span></Link>
            {access.player && <Link className="admin-inline-action" to="/player">PLAYER HUB <span aria-hidden="true">↗</span></Link>}
            {access.captain && <Link className="admin-inline-action" to="/captain">CAPTAIN HUB <span aria-hidden="true">↗</span></Link>}
            {access.admin && <Link className="admin-inline-action" to="/admin">ADMIN DASHBOARD <span aria-hidden="true">↗</span></Link>}
            {access.finance && <Link className="admin-inline-action" to="/finance">FINANCE WORKSPACE <span aria-hidden="true">↗</span></Link>}
          </section>
        ) : access.signedIn ? (
          <p className="form-note">Your account has basic-view access. You can follow public fixtures, results and league tables. Player registration starts at age 16; team actions require an approved player registration.</p>
        ) : null}

        <section className="hub-memberships">
          <div className="hub-section-heading"><span className="hub-kicker">ACCOUNT</span></div>
          {access.signedIn ? (
            <button className="auth-text-button" type="button" onClick={signOut}>SIGN OUT</button>
          ) : (
            <>
              <Link className="admin-inline-action" to="/sign-in">SIGN IN <span aria-hidden="true">↗</span></Link>
              <Link className="admin-inline-action" to="/sign-up">CREATE AN ACCOUNT <span aria-hidden="true">↗</span></Link>
            </>
          )}
        </section>
        <Link className="auth-switch" to="/">Back to Open Play home</Link>
      </section>
      <RefereeBottomNavigation />
    </main>
  );
}

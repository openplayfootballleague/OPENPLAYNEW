import { useEffect, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { RefereeBottomNavigation } from "../../components/referee-bottom-navigation";
import { getSupabaseClient } from "../../lib/supabase/client";

type RpcClient = {
  rpc(name: string): Promise<{ data: unknown; error: { message: string } | null }>;
};
type PortalState = { membership?: { status?: "active" | "suspended" } | null };

export const Route = createFileRoute("/referee/matchday")({ component: RefereeMatchdayPage });

function RefereeMatchdayPage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [active, setActive] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let alive = true;
    async function load() {
      const supabase = getSupabaseClient();
      const { data: { session } } = await supabase.auth.getSession();
      if (!alive) return;
      if (!session) {
        void navigate({ to: "/sign-in", replace: true });
        return;
      }
      const result = await (supabase as unknown as RpcClient).rpc("get_my_referee_portal_state");
      if (!alive) return;
      if (result.error) setError(result.error.message);
      else if (result.data && typeof result.data === "object") {
        setActive((result.data as PortalState).membership?.status === "active");
      }
      setLoading(false);
    }
    void load();
    return () => { alive = false; };
  }, [navigate]);

  useEffect(() => {
    if (!loading && !active && !error) void navigate({ to: "/referee", replace: true });
  }, [active, error, loading, navigate]);

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel hub-panel">
        <Link className="notice-brand" to="/referee">
          <img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" />
        </Link>
        <p className="eyebrow eyebrow-dark">OPEN PLAY · OFFICIALS</p>
        <h1>Matchday<br /><em>workspace.</em></h1>
        {loading ? <p className="form-note" role="status">Checking referee membership…</p> : error ? (
          <p className="form-note" role="alert">{error}</p>
        ) : active ? (
          <section className="hub-memberships">
            <div className="hub-section-heading"><span className="hub-kicker">YOUR APPOINTMENTS</span></div>
            <h2>No fixtures allocated yet.</h2>
            <p>Your matchday appointments will appear here once an Open Play administrator has assigned fixtures to you. You will only see fixtures allocated to your referee membership.</p>
            <p className="form-note">Fixture allocation and match reporting are the next development components. No appointment or payment is created by this page.</p>
          </section>
        ) : <p className="form-note">An active referee membership is required to view this workspace.</p>}
        <Link className="auth-switch" to="/referee">Back to referee home</Link>
      </section>
      <RefereeBottomNavigation />
    </main>
  );
}

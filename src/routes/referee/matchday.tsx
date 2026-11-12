import { useEffect, useState } from "react";
import { AuthenticatedSessionBoundary } from "../../components/authenticated-session-boundary";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { RefereeBottomNavigation } from "../../components/referee-bottom-navigation";
import { getSupabaseClient } from "../../lib/supabase/client";
import { useOpenPlayAnalytics } from "../../components/analytics-provider";

type RpcClient = {
  rpc(name: string): Promise<{ data: unknown; error: { message: string } | null }>;
};
type PortalState = { membership?: { status?: "active" | "suspended" } | null };
type RefereeAppointment = { assignment_id: string; fixture_id: string; assignment_role: "lead" | "assistant"; assigned_at: string; scheduled_at: string; gameweek: number; fixture_number: number; home_team_name: string; away_team_name: string; venue_name: string | null; fixture_status: string };

export const Route = createFileRoute("/referee/matchday")({ component: RefereeMatchdayPage });

function RefereeMatchdayPage(){
 return <AuthenticatedSessionBoundary label="REFEREE MATCHDAY"><RefereeMatchdayWorkspace/></AuthenticatedSessionBoundary>;
}

function RefereeMatchdayWorkspace() {
  const capture = useOpenPlayAnalytics();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [active, setActive] = useState(false);
  const [error, setError] = useState("");
  const [appointments, setAppointments] = useState<RefereeAppointment[]>([]);

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
      if (result.error) {
        setError(result.error.message);
        capture("data_load_failed", { feature: "referee_workspace", error_code: "network_error", outcome: "failure" });
      }
      else if (result.data && typeof result.data === "object") {
        const isActive = (result.data as PortalState).membership?.status === "active";
        setActive(isActive);
        if (isActive) {
          const appointmentResult = await (supabase as unknown as RpcClient).rpc("get_my_referee_assignments");
          if (!alive) return;
          if (appointmentResult.error) {
            setError(appointmentResult.error.message);
            capture("data_load_failed", { feature: "referee_workspace", error_code: "network_error", outcome: "failure" });
          } else {
            setAppointments((appointmentResult.data ?? []) as RefereeAppointment[]);
            capture("feature_opened", { feature: "referee_workspace", outcome: "success" });
          }
        }
      }
      setLoading(false);
    }
    void load();
    return () => { alive = false; };
  }, [capture, navigate]);

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
            {appointments.length === 0 ? (
              <>
                <h2>No fixtures allocated yet.</h2>
                <p>Your appointments will appear here once an Open Play administrator assigns a fixture to you.</p>
              </>
            ) : appointments.map((appointment) => (
              <article className="admin-queue-row" key={appointment.assignment_id}>
                <div>
                  <strong>Gameweek {appointment.gameweek} · {appointment.assignment_role.toUpperCase()}</strong>
                  <span>{appointment.home_team_name} v {appointment.away_team_name}</span>
                  <small>{appointment.venue_name ?? "Venue to be confirmed"} · {new Date(appointment.scheduled_at).toLocaleString("en-GB", { dateStyle: "full", timeStyle: "short" })}</small>
                  <small>Status: {appointment.fixture_status}</small>
                  {new Date(appointment.scheduled_at).getTime() <= Date.now() &&
                    !["cancelled", "postponed"].includes(appointment.fixture_status) && (
                      <Link className="button" to="/referee/report/$fixtureId" params={{ fixtureId: appointment.fixture_id }}>
                        OPEN MATCH REPORT
                      </Link>
                    )}
                </div>
              </article>
            ))}
            <p className="form-note">Appointments are private to your referee account. Submit each report within the 24-hour reporting window; rejected reports remain available for correction.</p>
          </section>
        ) : <p className="form-note">An active referee membership is required to view this workspace.</p>}
        <Link className="auth-switch" to="/referee">Back to referee home</Link>
      </section>
      <RefereeBottomNavigation />
    </main>
  );
}

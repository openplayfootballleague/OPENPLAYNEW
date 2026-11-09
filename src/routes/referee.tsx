import { useEffect, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { useRequiredSession } from "../lib/auth/use-required-session";
import { getSupabaseClient } from "../lib/supabase/client";

type RefereeApplication = {
  full_name: string;
  status: "pending" | "approved" | "rejected";
  qualifications: string;
  availability: string;
  preferred_locations: string[];
};

export const Route = createFileRoute("/referee")({ component: RefereeHubPage });

function RefereeHubPage() {
  const authStatus = useRequiredSession();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [application, setApplication] = useState<RefereeApplication | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (authStatus === "unauthenticated") {
      void navigate({ to: "/sign-in", replace: true });
      return;
    }
    if (authStatus !== "authenticated") return;
    let active = true;

    async function load() {
      const [{ data: hasRole, error: roleError }, { data: rows, error: applicationError }] = await Promise.all([
        getSupabaseClient().rpc("has_referee_role"),
        getSupabaseClient().rpc("get_my_referee_application"),
      ]);
      if (!active) return;
      if (roleError || applicationError) {
        setError(roleError?.message ?? applicationError?.message ?? "Unable to verify referee access.");
      } else if (!hasRole) {
        await navigate({ to: "/apply-referee", replace: true });
        return;
      } else {
        const current = ((rows ?? []) as unknown as RefereeApplication[])[0] ?? null;
        if (!current || current.status !== "approved") {
          setError("Your referee membership could not be confirmed. Please contact an Open Play administrator.");
        } else {
          setApplication(current);
        }
      }
      setLoading(false);
    }

    void load();
    return () => { active = false; };
  }, [authStatus, navigate]);

  if (authStatus !== "authenticated" || loading) {
    return <main className="notice-page"><section className="notice-panel"><p role="status">Verifying referee membership…</p></section></main>;
  }

  return (
    <main className="notice-page">
      <section className="notice-panel hub-panel">
        <Link className="notice-brand" to="/more"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" /></Link>
        <p className="eyebrow eyebrow-dark">OPEN PLAY OFFICIALS</p>
        <h1>Referee<br /><em>Hub.</em></h1>
        {error ? <p className="form-error" role="alert">{error}</p> : (
          <>
            <p>Welcome, {application?.full_name}. This is your dedicated matchday workspace.</p>
            <div className="admin-workspace-nav" aria-label="Referee workspaces">
              <a href="#referee-overview">Overview</a>
              <a href="#referee-fixtures">My fixtures</a>
              <a href="#referee-reports">Match reports</a>
              <a href="#referee-profile">My profile</a>
            </div>
            <section className="admin-queue" id="referee-overview">
              <div className="hub-section-heading"><span className="hub-kicker">OFFICIAL STATUS</span><span className="join-request-status join-request-status--success">APPROVED REFEREE</span></div>
              <p>Your referee membership is active. Your referee permissions are separate from player, captain and administrator access.</p>
            </section>
            <section className="admin-queue" id="referee-fixtures">
              <div className="hub-section-heading"><span className="hub-kicker">MY FIXTURES</span><span>ASSIGNMENTS</span></div>
              <div className="hub-empty"><h2>No fixture assignments yet</h2><p>When an administrator assigns you to a fixture, the match details and matchday information will appear here.</p></div>
            </section>
            <section className="admin-queue" id="referee-reports">
              <div className="hub-section-heading"><span className="hub-kicker">MATCH REPORTS</span></div>
              <div className="hub-empty"><h2>Match reporting is coming next</h2><p>We will connect referee reports to the official fixture result, goalscorers and disciplinary record workflow. No results can be submitted from this screen yet.</p></div>
            </section>
            <section className="admin-queue" id="referee-profile">
              <div className="hub-section-heading"><span className="hub-kicker">MY REFEREE PROFILE</span></div>
              <p><strong>Qualifications</strong><br />{application?.qualifications || "Not supplied"}</p>
              <p><strong>Availability</strong><br />{application?.availability}</p>
              <p><strong>Preferred locations</strong><br />{application?.preferred_locations.join(", ") || "No preference supplied"}</p>
            </section>
          </>
        )}
        <div className="admin-workspace-utility-nav">
          <Link to="/more">More Open Play workspaces</Link>
          <Link to="/match-centre">Public Match Centre</Link>
        </div>
      </section>
    </main>
  );
}

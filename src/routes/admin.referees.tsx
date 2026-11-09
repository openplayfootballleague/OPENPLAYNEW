import { useCallback, useEffect, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { useRequiredSession } from "../lib/auth/use-required-session";
import { getSupabaseClient } from "../lib/supabase/client";

type RefereeApplication = {
  id: string;
  user_id: string;
  full_name: string;
  email: string;
  phone: string;
  experience: string;
  qualifications: string;
  availability: string;
  preferred_locations: string[];
  additional_notes: string;
  status: "pending" | "approved" | "rejected";
  submitted_at: string;
  reviewed_at: string | null;
  review_reason: string | null;
};

export const Route = createFileRoute("/admin/referees")({ component: AdminRefereesPage });

function AdminRefereesPage() {
  const authStatus = useRequiredSession();
  const navigate = useNavigate();
  const [applications, setApplications] = useState<RefereeApplication[]>([]);
  const [filter, setFilter] = useState("pending");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [reasons, setReasons] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    if (authStatus !== "authenticated") return;
    setLoading(true);
    setError("");
    try {
      const { data, error: rpcError } = await getSupabaseClient().rpc("admin_get_referee_applications", { p_status: filter });
      if (rpcError) throw rpcError;
      setApplications((data ?? []) as unknown as RefereeApplication[]);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to load referee applications.");
      setApplications([]);
    } finally {
      setLoading(false);
    }
  }, [authStatus, filter]);

  useEffect(() => {
    if (authStatus === "unauthenticated") void navigate({ to: "/sign-in", replace: true });
    if (authStatus === "authenticated") void load();
  }, [authStatus, load, navigate]);

  async function resolve(application: RefereeApplication, decision: "approved" | "rejected") {
    const reason = (reasons[application.user_id] ?? "").trim();
    if (decision === "rejected" && reason.length < 5) {
      setError("Enter a rejection reason of at least 5 characters.");
      return;
    }
    setBusy(application.user_id);
    setError("");
    setNotice("");
    try {
      const { error: rpcError } = await getSupabaseClient().rpc("admin_resolve_referee_application", {
        p_user_id: application.user_id,
        p_decision: decision,
        p_reason: reason || null,
      });
      if (rpcError) throw rpcError;
      setNotice(decision === "approved"
        ? application.full_name + " has been approved. Their referee membership is now active."
        : application.full_name + "'s application has been rejected.");
      setReasons((current) => ({ ...current, [application.user_id]: "" }));
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to resolve this application.");
    } finally {
      setBusy("");
    }
  }

  if (authStatus !== "authenticated") {
    return <main className="notice-page"><section className="notice-panel"><p role="status">Checking administrator access…</p></section></main>;
  }

  return (
    <main className="notice-page">
      <section className="notice-panel hub-panel">
        <Link className="notice-brand" to="/admin"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" /></Link>
        <p className="eyebrow eyebrow-dark">ADMINISTRATION · MEMBERSHIPS</p>
        <h1>Referee<br /><em>applications.</em></h1>
        <p>Review prospective officials and control access to the Referee Hub. Approval grants the separate referee role; it does not grant administrator permissions.</p>

        <div className="admin-context-selector">
          <div className="hub-section-heading"><span className="hub-kicker">APPLICATION QUEUE</span><span>{applications.length} shown</span></div>
          <label>Application status
            <select value={filter} onChange={(event) => setFilter(event.target.value)}>
              <option value="pending">Awaiting review</option>
              <option value="approved">Approved</option>
              <option value="rejected">Rejected</option>
              <option value="all">All applications</option>
            </select>
          </label>
          <button type="button" onClick={() => void load()} disabled={loading}>{loading ? "LOADING…" : "REFRESH QUEUE"}</button>
        </div>

        {error && <p className="form-error" role="alert">{error}</p>}
        {notice && <p className="form-success" role="status">{notice}</p>}
        {loading ? <p className="form-note">Loading referee applications…</p> : applications.length === 0 ? (
          <div className="hub-empty"><h2>No applications found</h2><p>There are no referee applications in this queue.</p></div>
        ) : (
          <section className="admin-queue">
            {applications.map((application) => (
              <article className="admin-queue-row" key={application.id}>
                <div>
                  <div className="hub-section-heading">
                    <strong>{application.full_name}</strong>
                    <span className={"join-request-status " + (application.status === "approved" ? "join-request-status--success" : application.status === "rejected" ? "join-request-status--danger" : "join-request-status--pending")}>{application.status.toUpperCase()}</span>
                  </div>
                  <span>{application.email} · {application.phone}</span>
                  <small>Submitted {new Date(application.submitted_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</small>
                  <p><strong>Experience</strong><br />{application.experience}</p>
                  <p><strong>Qualifications</strong><br />{application.qualifications || "Not provided"}</p>
                  <p><strong>Availability</strong><br />{application.availability}</p>
                  <p><strong>Preferred locations</strong><br />{application.preferred_locations.length ? application.preferred_locations.join(", ") : "No preference supplied"}</p>
                  {application.additional_notes && <p><strong>Additional notes</strong><br />{application.additional_notes}</p>}
                  {application.review_reason && <p><strong>Previous decision reason</strong><br />{application.review_reason}</p>}
                  {application.status === "pending" && (
                    <div className="admin-sheet-editor">
                      <label>Review notes / rejection reason
                        <textarea rows={3} value={reasons[application.user_id] ?? ""} onChange={(event) => setReasons((current) => ({ ...current, [application.user_id]: event.target.value }))} placeholder="Optional for approval; required when rejecting." />
                      </label>
                      <div className="captain-actions">
                        <button type="button" className="reject" disabled={busy === application.user_id || (reasons[application.user_id] ?? "").trim().length < 5} onClick={() => void resolve(application, "rejected")}>{busy === application.user_id ? "SAVING…" : "REJECT APPLICATION"}</button>
                        <button type="button" disabled={busy === application.user_id} onClick={() => void resolve(application, "approved")}>{busy === application.user_id ? "SAVING…" : "APPROVE & ACTIVATE REFEREE"}</button>
                      </div>
                    </div>
                  )}
                </div>
              </article>
            ))}
          </section>
        )}
        <p className="form-note">All decisions are recorded in the administrative audit log. Applicants cannot grant themselves referee permissions or access this review queue.</p>
        <Link className="auth-switch" to="/admin">Back to Admin Dashboard</Link>
      </section>
    </main>
  );
}

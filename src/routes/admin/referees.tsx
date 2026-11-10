import { useCallback, useEffect, useState } from "react";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { useRequiredSession } from "../../lib/auth/use-required-session";
import { getSupabaseClient } from "../../lib/supabase/client";

type RpcError = { message: string };
type RpcClient = {
  rpc(name: string, args?: Record<string, unknown>): Promise<{ data: unknown; error: RpcError | null }>;
};
type RefereeApplication = {
  application_id: string;
  user_id: string;
  player_name: string;
  email: string;
  contact_phone: string;
  experience_summary: string;
  qualifications: string[];
  availability: Array<{ weekday: number; start_time: string; end_time: string }>;
  preferred_location_ids: string[];
  preferred_location_names: string[];
  additional_notes: string | null;
  status: "pending" | "approved" | "rejected";
  submitted_at: string;
  reviewed_at: string | null;
  review_reason: string | null;
};

const dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

export const Route = createFileRoute("/admin/referees")({ component: AdminRefereesPage });

function AdminRefereesPage() {
  const authStatus = useRequiredSession();
  const navigate = useNavigate();
  const [applications, setApplications] = useState<RefereeApplication[]>([]);
  const [statusFilter, setStatusFilter] = useState("pending");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [reasons, setReasons] = useState<Record<string, string>>({});

  useEffect(() => {
    if (authStatus === "unauthenticated") void navigate({ to: "/sign-in", replace: true });
  }, [authStatus, navigate]);

  const loadApplications = useCallback(async () => {
    setLoading(true);
    setError("");
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("admin_list_referee_applications", { p_status: statusFilter });
    if (result.error) {
      setError(result.error.message);
      setApplications([]);
    } else {
      setApplications((result.data ?? []) as RefereeApplication[]);
    }
    setLoading(false);
  }, [statusFilter]);

  useEffect(() => { void loadApplications(); }, [loadApplications]);

  async function decide(application: RefereeApplication, decision: "approved" | "rejected") {
    const reason = (reasons[application.application_id] ?? "").trim();
    if (reason.length < 5) {
      setError("Enter a review reason of at least five characters before making a decision.");
      return;
    }
    setBusy(application.application_id);
    setError("");
    setNotice("");
    const rpc = getSupabaseClient() as unknown as RpcClient;
    const result = await rpc.rpc("review_referee_application", {
      p_application_id: application.application_id,
      p_decision: decision,
      p_reason: reason,
    });
    setBusy("");
    if (result.error) {
      setError(result.error.message);
      return;
    }
    setNotice(decision === "approved"
      ? `${application.player_name} has been approved as an Open Play referee.`
      : `${application.player_name}'s application has been rejected.`);
    await loadApplications();
  }

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel hub-panel">
        <Link className="notice-brand" to="/admin">
          <img className="open-play-logo" src="/open-play-logo.png" alt="Open Play" />
        </Link>
        <p className="eyebrow eyebrow-dark">ADMINISTRATION · OFFICIALS</p>
        <h1>Referee<br /><em>applications.</em></h1>
        <p>Review referee applicants for the locations you administer. Approval grants a separate referee membership; it does not rely on user-editable account metadata.</p>

        <section className="hub-memberships">
          <div className="hub-section-heading">
            <span className="hub-kicker">APPLICATION QUEUE</span>
            <select aria-label="Filter applications" value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
              <option value="pending">Pending</option>
              <option value="approved">Approved</option>
              <option value="rejected">Rejected</option>
              <option value="all">All applications</option>
            </select>
          </div>
          {error && <p className="form-note" role="alert">{error}</p>}
          {notice && <p className="form-note" role="status">{notice}</p>}
          {loading ? <p className="form-note">Loading referee applications…</p> : applications.length === 0 ? (
            <p className="form-note">No applications match this filter for your permitted locations.</p>
          ) : applications.map((application) => (
            <article className="admin-queue-row" key={application.application_id}>
              <div>
                <strong>{application.player_name}</strong>
                <span>{application.email} · {application.contact_phone}</span>
                <small>{application.preferred_location_names.join(", ")}</small>
                <small>Submitted {new Date(application.submitted_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })} · {application.status.toUpperCase()}</small>
                <p><strong>Experience</strong><br />{application.experience_summary}</p>
                <p><strong>Qualifications</strong><br />{application.qualifications.length ? application.qualifications.join(", ") : "None supplied"}</p>
                <p><strong>Availability</strong><br />{application.availability.map((slot) => `${dayNames[slot.weekday - 1]} ${slot.start_time}–${slot.end_time}`).join(" · ")}</p>
                {application.additional_notes && <p><strong>Additional information</strong><br />{application.additional_notes}</p>}
                {application.review_reason && <p className="form-note"><strong>Previous review:</strong> {application.review_reason}</p>}
              </div>
              {application.status === "pending" && (
                <div className="admin-sheet-editor">
                  <label>
                    Review reason (required)
                    <textarea rows={2} minLength={5} maxLength={500} value={reasons[application.application_id] ?? ""} onChange={(event) => setReasons((current) => ({ ...current, [application.application_id]: event.target.value }))} placeholder="Record why this application is approved or rejected." />
                  </label>
                  <div className="captain-actions">
                    <button type="button" className="reject" disabled={busy === application.application_id} onClick={() => void decide(application, "rejected")}>REJECT</button>
                    <button type="button" disabled={busy === application.application_id} onClick={() => void decide(application, "approved")}>{busy === application.application_id ? "SAVING…" : "APPROVE REFEREE"}</button>
                  </div>
                </div>
              )}
            </article>
          ))}
          <button type="button" disabled={loading} onClick={() => void loadApplications()}>REFRESH QUEUE</button>
        </section>
        <Link className="auth-switch" to="/admin">Back to Admin Dashboard</Link>
      </section>
    </main>
  );
}

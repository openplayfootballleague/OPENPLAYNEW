import { useEffect, useState } from "react";
import { AuthenticatedSessionBoundary } from "../components/authenticated-session-boundary";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

type ConsentRow = {
  id: string;
  player_user_id: string;
  player_email: string;
  player_date_of_birth: string;
  guardian_full_name: string;
  guardian_email: string;
  status: "pending_admin_review" | "approved" | "rejected" | "withdrawn";
  verified_at: string | null;
  created_at: string;
};

export const Route = createFileRoute("/admin_/guardian-consents")({ component: GuardianConsentAdminPage });

function GuardianConsentAdminPage(){
 return <AuthenticatedSessionBoundary label="GUARDIAN CONSENT ADMIN"><GuardianConsentAdminWorkspace/></AuthenticatedSessionBoundary>;
}

function GuardianConsentAdminWorkspace() {
  const navigate = useNavigate();
  const [rows, setRows] = useState<ConsentRow[]>([]);
  const [reasons, setReasons] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    const supabase = getSupabaseClient();
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      await navigate({ to: "/sign-in", replace: true });
      return;
    }
    const { data: roles, error: roleError } = await supabase.from("user_roles").select("role").eq("user_id", session.user.id);
    if (roleError) {
      setError(roleError.message);
      setLoading(false);
      return;
    }
    if (!(roles ?? []).some((row) => ["admin", "super_admin"].includes(row.role))) {
      setError("Global administrator permission is required to review guardian consent.");
      setLoading(false);
      return;
    }
    const { data, error: queueError } = await supabase.rpc("admin_get_guardian_consent_queue");
    if (queueError) setError(queueError.message);
    else setRows((data ?? []) as ConsentRow[]);
    setLoading(false);
  }

  useEffect(() => { void load(); }, []);

  async function review(row: ConsentRow, decision: "approved" | "rejected") {
    const reason = (reasons[row.id] ?? "").trim();
    if (reason.length < 5) {
      setError("Enter a review reason of at least 5 characters.");
      return;
    }
    setBusy(row.id);
    setError("");
    setNotice("");
    const { error: reviewError } = await getSupabaseClient().rpc("admin_review_guardian_consent", {
      p_consent_id: row.id,
      p_decision: decision,
      p_reason: reason,
    });
    if (reviewError) setError(reviewError.message);
    else {
      setNotice(decision === "approved"
        ? "Guardian consent approved. The player can now return and complete player registration."
        : "Guardian consent rejected. The player cannot complete player registration.");
      await load();
    }
    setBusy("");
  }

  return <main className="notice-page player-facing">
    <section className="notice-panel auth-panel" style={{ maxWidth: 900 }}>
      <Link className="notice-brand" to="/admin">← ADMIN DASHBOARD</Link>
      <p className="eyebrow eyebrow-dark">SAFEGUARDING</p>
      <h1>Guardian<br/><em>consents.</em></h1>
      <p>Review parent or legal-guardian confirmations for 16- and 17-year-old player registrations. A verified email is not automatically an approval.</p>
      {error && <p className="form-error" role="alert">{error}</p>}
      {notice && <p className="form-success" role="status">{notice}</p>}
      {loading ? <p>Loading guardian consent queue…</p> : rows.length === 0 ? <p>No guardian consent requests are available.</p> : <div className="admin-record-list">
        {rows.map((row) => <article key={row.id} className="admin-record">
          <p className="eyebrow eyebrow-dark">{row.status.replaceAll("_", " ")}</p>
          <h2>{row.player_email}</h2>
          <p>Player date of birth: <strong>{row.player_date_of_birth}</strong></p>
          <p>Parent/legal guardian: <strong>{row.guardian_full_name}</strong> · {row.guardian_email}</p>
          <p>Guardian verified: {row.verified_at ? new Date(row.verified_at).toLocaleString("en-GB") : "Not verified"}</p>
          {row.status === "pending_admin_review" && <>
            <label>Review reason<textarea required minLength={5} value={reasons[row.id] ?? ""} onChange={(event) => setReasons((old) => ({ ...old, [row.id]: event.target.value }))} /></label>
            <div className="admin-action-row">
              <button className="button" type="button" disabled={busy === row.id} onClick={() => void review(row, "approved")}>{busy === row.id ? "SAVING…" : "APPROVE CONSENT"}</button>
              <button className="button button-secondary" type="button" disabled={busy === row.id} onClick={() => void review(row, "rejected")}>REJECT</button>
            </div>
          </>}
        </article>)}
      </div>}
      <button className="auth-text-button" type="button" onClick={() => void load()}>Refresh queue</button>
    </section>
  </main>;
}

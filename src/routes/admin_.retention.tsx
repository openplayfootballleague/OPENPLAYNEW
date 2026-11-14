import { useEffect, useState } from "react";
import { AuthenticatedSessionBoundary } from "../components/authenticated-session-boundary";
import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { getSupabaseClient } from "../lib/supabase/client";

type RetentionAccount = {
  user_id: string;
  full_name: string;
  email: string | null;
  account_retention_status: "active" | "closed" | "erasure_due";
  last_sign_in_at: string;
  account_closed_at: string | null;
  archive_expires_at: string | null;
  retention_hold: boolean;
  retention_hold_reason: string | null;
};

export const Route = createFileRoute("/admin_/retention")({ component: PlayerRetentionAdminPage });

function PlayerRetentionAdminPage(){
 return <AuthenticatedSessionBoundary label="PLAYER RETENTION ADMIN"><PlayerRetentionAdminWorkspace/></AuthenticatedSessionBoundary>;
}

function PlayerRetentionAdminWorkspace() {
  const navigate = useNavigate();
  const [rows, setRows] = useState<RetentionAccount[]>([]);
  const [search, setSearch] = useState("");
  const [reasons, setReasons] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  async function load(query = search) {
    setLoading(true);
    setError("");
    const supabase = getSupabaseClient();
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      await navigate({ to: "/sign-in", replace: true });
      return;
    }
    const { data: roles, error: roleError } = await supabase
      .from("user_roles").select("role").eq("user_id", session.user.id);
    if (roleError) {
      setError(roleError.message);
      setLoading(false);
      return;
    }
    if (!(roles ?? []).some((row) => ["admin", "super_admin"].includes(row.role))) {
      setError("Global administrator permission is required to manage retention holds.");
      setLoading(false);
      return;
    }
    const { data, error: queueError } = await supabase.rpc("admin_list_player_retention_accounts", {
      p_search: query.trim() || null,
    });
    if (queueError) setError(queueError.message);
    else setRows((data ?? []) as RetentionAccount[]);
    setLoading(false);
  }

  useEffect(() => { void load(""); }, []);

  async function setHold(row: RetentionAccount, hold: boolean) {
    const reason = (reasons[row.user_id] ?? "").trim();
    if (reason.length < 5) {
      setError("Enter an audit reason of at least 5 characters.");
      return;
    }
    setBusy(row.user_id);
    setError("");
    setNotice("");
    const { error: updateError } = await getSupabaseClient().rpc("admin_set_player_retention_hold", {
      p_user_id: row.user_id,
      p_hold: hold,
      p_reason: reason,
    });
    if (updateError) setError(updateError.message);
    else {
      setNotice(hold
        ? "Retention hold applied. Automatic closure and erasure are paused while the hold remains active."
        : "Retention hold cleared. The account will be assessed by the normal retention rules.");
      setReasons((old) => ({ ...old, [row.user_id]: "" }));
      await load();
    }
    setBusy("");
  }

  const date = (value: string | null) => value
    ? new Date(value).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })
    : "—";

  return <main className="notice-page player-facing">
    <section className="notice-panel auth-panel" style={{ maxWidth: 960 }}>
      <Link className="notice-brand" to="/admin">← ADMIN DASHBOARD</Link>
      <p className="eyebrow eyebrow-dark">ACCOUNT GOVERNANCE</p>
      <h1>Player<br/><em>retention.</em></h1>
      <p>Review account retention status and apply or clear a documented legal, safeguarding or financial hold. Every change requires a reason and is recorded in the audit history.</p>
      {error && <p className="form-error" role="alert">{error}</p>}
      {notice && <p className="form-success" role="status">{notice}</p>}
      <form className="admin-player-search" onSubmit={(event) => { event.preventDefault(); void load(search); }}>
        <label>Find a player by name or email<input value={search} maxLength={100} onChange={(event) => setSearch(event.target.value)} placeholder="Search player accounts" /></label>
        <button className="button" type="submit" disabled={loading}>{loading ? "SEARCHING…" : "SEARCH"}</button>
        <button className="button button-secondary" type="button" disabled={loading} onClick={() => void load(search)}>REFRESH</button>
      </form>
      {loading ? <p>Loading player retention accounts…</p> : rows.length === 0 ? <p>No player accounts match this search.</p> : <div className="admin-record-list">
        {rows.map((row) => <article key={row.user_id} className="admin-record">
          <p className="eyebrow eyebrow-dark">{row.account_retention_status.replaceAll("_", " ")}</p>
          <h2>{row.full_name}</h2>
          <p>{row.email ?? "No email available"}</p>
          <p>Last successful sign-in: <strong>{date(row.last_sign_in_at)}</strong></p>
          <p>Account closed: <strong>{date(row.account_closed_at)}</strong></p>
          <p>Archive expires: <strong>{date(row.archive_expires_at)}</strong></p>
          <p>Retention hold: <strong>{row.retention_hold ? "ACTIVE" : "Not active"}</strong></p>
          {row.retention_hold_reason && <p>Current reason: {row.retention_hold_reason}</p>}
          {row.account_retention_status === "erasure_due"
            ? <p className="form-note">Final erasure has begun. A new hold cannot safely be applied at this stage.</p>
            : <>
              <label>Reason for {row.retention_hold ? "clearing" : "applying"} the hold<textarea required minLength={5} maxLength={500} value={reasons[row.user_id] ?? ""} onChange={(event) => setReasons((old) => ({ ...old, [row.user_id]: event.target.value }))} /></label>
              <div className="admin-action-row">
                {!row.retention_hold
                  ? <button className="button" type="button" disabled={busy === row.user_id} onClick={() => void setHold(row, true)}>{busy === row.user_id ? "SAVING…" : "APPLY RETENTION HOLD"}</button>
                  : <button className="button button-secondary" type="button" disabled={busy === row.user_id} onClick={() => void setHold(row, false)}>{busy === row.user_id ? "SAVING…" : "CLEAR RETENTION HOLD"}</button>}
              </div>
            </>}
        </article>)}
      </div>}
      <p className="form-note">Only global administrators can use this workspace. A hold must be applied before the account enters the final erasure stage. Clearing a hold allows the ordinary 12-month inactivity and archive rules to resume.</p>
    </section>
  </main>;
}

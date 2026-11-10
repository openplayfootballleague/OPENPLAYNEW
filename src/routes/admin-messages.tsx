import { useCallback, useEffect, useState } from "react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { useRequiredSession } from "../lib/auth/use-required-session";
import { getSupabaseClient } from "../lib/supabase/client";

type LocationOption = { id: string; name: string; town: string };
type SeasonOption = { id: string; name: string; league_name: string; location_name: string };
type TeamOption = { id: string; name: string; season_name: string; location_name: string };
type PlayerOption = { user_id: string; full_name: string };
type Setup = {
  locations?: LocationOption[];
  seasons?: SeasonOption[];
  teams?: TeamOption[];
  players?: PlayerOption[];
};
type MessageReport = {
  report_id: string;
  message_id: string | null;
  conversation_id: string | null;
  conversation_title: string | null;
  reporter_name: string;
  reported_user_name: string;
  message_body: string | null;
  reason: string;
  status: string;
  created_at: string;
  location_id: string | null;
};

export const Route = createFileRoute("/admin-messages")({ component: AdminMessagesPage });

function AdminMessagesPage() {
  const authStatus = useRequiredSession();
  const [loading, setLoading] = useState(true);
  const [isGlobalAdmin, setIsGlobalAdmin] = useState(false);
  const [setup, setSetup] = useState<Setup>({});
  const [reports, setReports] = useState<MessageReport[]>([]);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [targetType, setTargetType] = useState("everyone");
  const [targetId, setTargetId] = useState("");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [moderationReasons, setModerationReasons] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    setError("");
    const supabase = getSupabaseClient();
    const [{ data: preference, error: preferenceError }, { data: setupData, error: setupError }, { data: reportData, error: reportError }] = await Promise.all([
      supabase.rpc("get_admin_context_preference"),
      supabase.rpc("admin_get_message_target_options"),
      supabase.rpc("admin_get_message_reports", { p_status: "open", p_limit: 100 }),
    ]);
    if (preferenceError || setupError || reportError) {
      setError(preferenceError?.message ?? setupError?.message ?? reportError?.message ?? "Unable to load messaging administration.");
      setLoading(false);
      return;
    }
    const context = preference as { is_global_admin?: boolean } | null;
    setIsGlobalAdmin(Boolean(context?.is_global_admin));
    setTargetType(context?.is_global_admin ? "everyone" : "location");
    setSetup((setupData ?? {}) as Setup);
    setReports((reportData ?? []) as MessageReport[]);
    setLoading(false);
  }, []);

  useEffect(() => {
    if (authStatus === "authenticated") void load();
    else if (authStatus === "unauthenticated") setLoading(false);
  }, [authStatus, load]);

  const needsTarget = ["location", "season", "team", "individual"].includes(targetType);
  const options = targetType === "location" || targetType === "captains"
    ? (setup.locations ?? []).map((item) => ({ value: item.id, label: item.name + " · " + item.town }))
    : targetType === "season"
      ? (setup.seasons ?? []).map((item) => ({ value: item.id, label: item.location_name + " · " + item.league_name + " · " + item.name }))
      : targetType === "team"
        ? (setup.teams ?? []).map((item) => ({ value: item.id, label: item.location_name + " · " + item.season_name + " · " + item.name }))
        : targetType === "individual"
          ? (setup.players ?? []).map((item) => ({ value: item.user_id, label: item.full_name }))
          : [];

  async function createBroadcast(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (needsTarget && !targetId) {
      setError("Choose the audience before sending the broadcast.");
      return;
    }
    if (targetType === "captains" && !isGlobalAdmin && !targetId) {
      setError("Choose a location for this captain broadcast.");
      return;
    }
    setBusy(true); setError(""); setNotice("");
    const { error: rpcError } = await getSupabaseClient().rpc("admin_create_message_broadcast", {
      p_title: title.trim(),
      p_body: body.trim(),
      p_target_type: targetType,
      p_target_id: targetId || null,
    });
    if (rpcError) setError(rpcError.message);
    else {
      setNotice("Broadcast created. Recipients will see it in their Open Play inbox and receive notifications according to their preferences.");
      setTitle(""); setBody(""); setTargetId("");
      await load();
    }
    setBusy(false);
  }

  async function resolveReport(reportId: string, action: "hide_message" | "dismiss") {
    const reason = (moderationReasons[reportId] ?? "").trim();
    if (reason.length < 5) {
      setError("Enter a moderation reason of at least five characters.");
      return;
    }
    setBusy(true); setError(""); setNotice("");
    const { error: rpcError } = await getSupabaseClient().rpc("admin_resolve_message_report", {
      p_report_id: reportId,
      p_action: action,
      p_reason: reason,
    });
    if (rpcError) setError(rpcError.message);
    else {
      setNotice(action === "hide_message" ? "Message hidden and report resolved." : "Report dismissed.");
      setModerationReasons((current) => ({ ...current, [reportId]: "" }));
      await load();
    }
    setBusy(false);
  }

  if (authStatus === "loading" || loading) {
    return <main className="notice-page player-facing"><section className="notice-panel"><p>Loading message administration…</p></section></main>;
  }
  if (authStatus === "unauthenticated") {
    return <main className="notice-page player-facing"><section className="notice-panel"><p className="eyebrow eyebrow-dark">ADMIN MESSAGING</p><h1>Sign in to<br/><em>continue.</em></h1><Link className="button" to="/sign-in">SIGN IN</Link></section></main>;
  }

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel messaging-panel admin-messaging-panel">
        <div className="hub-top">
          <Link className="notice-brand" to="/admin"><img className="open-play-logo" src="/open-play-logo.png" alt="Open Play"/></Link>
          <Link className="messaging-back-link" to="/messages">INBOX</Link>
        </div>
        <p className="eyebrow eyebrow-dark">ADMIN WORKSPACE</p>
        <h1>Messaging<br/><em>control.</em></h1>
        <p className="form-note">Send targeted announcements and review member reports. Broadcasts are read-only for recipients; private support replies stay in the inbox.</p>
        {error && <p className="form-error" role="alert">{error}</p>}
        {notice && <p className="form-success" role="status">{notice}</p>}

        <form className="admin-setup-form messaging-broadcast-form" onSubmit={createBroadcast}>
          <h3>CREATE ANNOUNCEMENT</h3>
          <label>Audience
            <select value={targetType} onChange={(event) => { setTargetType(event.target.value); setTargetId(""); }}>
              {isGlobalAdmin && <option value="everyone">Everyone with an active Open Play account</option>}
              {isGlobalAdmin && <option value="players">All registered players</option>}
              <option value="captains">Team captains</option>
              {isGlobalAdmin && <option value="admins">Administrators only</option>}
              <option value="location">Players in a location</option>
              <option value="season">Players in a season</option>
              <option value="team">A specific team</option>
              {isGlobalAdmin && <option value="individual">One individual player</option>}
            </select>
          </label>
          {(needsTarget || targetType === "captains") && <label>Target
            <select value={targetId} onChange={(event) => setTargetId(event.target.value)} required={needsTarget || (targetType === "captains" && !isGlobalAdmin)}>
              {targetType === "captains" && isGlobalAdmin && <option value="">All locations</option>}
              {targetType !== "captains" && <option value="">Choose a target…</option>}
              {options.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
          </label>}
          <label>Announcement title<input value={title} onChange={(event) => setTitle(event.target.value)} maxLength={120} minLength={3} required placeholder="e.g. Matchday update"/></label>
          <label>Message<textarea value={body} onChange={(event) => setBody(event.target.value)} rows={5} maxLength={2000} required placeholder="Write a clear announcement…"/></label>
          <small>Message limit: 2,000 characters. Email/SMS notifications contain an alert only; the message content remains inside the authenticated inbox.</small>
          <button type="submit" disabled={busy}>{busy ? "SENDING…" : "SEND ANNOUNCEMENT"}</button>
        </form>

        <section className="messaging-moderation">
          <div className="hub-section-heading"><span className="hub-kicker">OPEN MEMBER REPORTS</span><strong>{reports.length} open</strong></div>
          {reports.length === 0 ? <p className="form-note">No open message reports. Private support conversations are available in the inbox.</p> : reports.map((report) => <article className="messaging-report-card" key={report.report_id}>
            <div className="messaging-report-card-head"><strong>{report.conversation_title ?? "Conversation report"}</strong><small>{new Date(report.created_at).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"})}</small></div>
            <p><b>Reported by:</b> {report.reporter_name} · <b>Member:</b> {report.reported_user_name}</p>
            {report.message_body && <blockquote>{report.message_body}</blockquote>}
            <p><b>Reason:</b> {report.reason}</p>
            <label>Moderation reason<textarea rows={2} value={moderationReasons[report.report_id] ?? ""} onChange={(event) => setModerationReasons((current) => ({ ...current, [report.report_id]: event.target.value }))} placeholder="Record why you are resolving this report…"/></label>
            <div className="messaging-moderation-actions">
              <button type="button" disabled={busy} onClick={() => void resolveReport(report.report_id,"hide_message")}>HIDE MESSAGE &amp; RESOLVE</button>
              <button type="button" className="secondary" disabled={busy} onClick={() => void resolveReport(report.report_id,"dismiss")}>DISMISS REPORT</button>
            </div>
          </article>)}
        </section>
      </section>
    </main>
  );
}

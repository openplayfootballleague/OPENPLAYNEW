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
type MessagingRpcClient = { rpc: (name: string, args?: Record<string, unknown>) => Promise<{ data: unknown; error: { message: string } | null }> };
const messagingRpc = () => getSupabaseClient() as unknown as MessagingRpcClient;
type SupportCase = {
  case_id: string;
  conversation_id: string;
  subject: string;
  requester_user_id: string;
  requester_name: string;
  assigned_to: string | null;
  assigned_admin_name: string | null;
  status: "open" | "in_progress" | "waiting_for_member" | "resolved" | "closed";
  priority: "low" | "normal" | "high" | "urgent";
  resolution_summary: string | null;
  created_at: string;
  updated_at: string;
  last_message_at: string | null;
  last_message_preview: string | null;
};
type SupportAdmin = { user_id: string; display_name: string };
type SupportCaseDraft = {
  assigned_to: string;
  status: SupportCase["status"];
  priority: SupportCase["priority"];
  resolution_summary: string;
  reason: string;
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
  const [supportCases, setSupportCases] = useState<SupportCase[]>([]);
  const [supportAdmins, setSupportAdmins] = useState<SupportAdmin[]>([]);
  const [supportCaseDrafts, setSupportCaseDrafts] = useState<Record<string, SupportCaseDraft>>({});
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [announcementsEnabled, setAnnouncementsEnabled] = useState<boolean | null>(null);
  const [targetType, setTargetType] = useState("everyone");
  const [targetId, setTargetId] = useState("");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [moderationReasons, setModerationReasons] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    setError("");
    const supabase = getSupabaseClient();
    const [{ data: preference, error: preferenceError }, { data: setupData, error: setupError }, { data: reportData, error: reportError }, { data: announcementStatus, error: announcementStatusError }] = await Promise.all([
      supabase.rpc("get_admin_context_preference"),
      messagingRpc().rpc("admin_get_message_target_options"),
      messagingRpc().rpc("admin_get_message_reports", { p_status: "open", p_limit: 100 }),
      supabase.rpc("get_public_announcement_status"),
    ]);
    if (preferenceError || setupError || reportError || announcementStatusError) {
      setError(preferenceError?.message ?? setupError?.message ?? reportError?.message ?? announcementStatusError?.message ?? "Unable to load messaging administration.");
      setLoading(false);
      return;
    }
    const context = preference as { is_global_admin?: boolean } | null;
    setIsGlobalAdmin(Boolean(context?.is_global_admin));
    setAnnouncementsEnabled(announcementStatus === true);
    setTargetType(context?.is_global_admin ? "everyone" : "location");
    setSetup((setupData ?? {}) as Setup);
    setReports((reportData ?? []) as MessageReport[]);
    if (context?.is_global_admin) {
      const [{ data: caseData, error: caseError }, { data: adminData, error: adminError }] = await Promise.all([
        messagingRpc().rpc("admin_get_support_cases", { p_status: "all", p_limit: 100, p_offset: 0 }),
        messagingRpc().rpc("admin_get_support_case_options"),
      ]);
      if (caseError || adminError) {
        setError(caseError?.message ?? adminError?.message ?? "Unable to load support cases.");
      } else {
        const cases = (caseData ?? []) as SupportCase[];
        setSupportCases(cases);
        setSupportAdmins((adminData ?? []) as SupportAdmin[]);
        setSupportCaseDrafts(Object.fromEntries(cases.map((item) => [item.case_id, {
          assigned_to: item.assigned_to ?? "",
          status: item.status,
          priority: item.priority,
          resolution_summary: item.resolution_summary ?? "",
          reason: "",
        }])));
      }
    } else {
      setSupportCases([]);
      setSupportAdmins([]);
      setSupportCaseDrafts({});
    }
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
    if (announcementsEnabled !== true) {
      setError("Open Play announcements are currently paused by a platform administrator.");
      return;
    }
    if (needsTarget && !targetId) {
      setError("Choose the audience before sending the broadcast.");
      return;
    }
    if (targetType === "captains" && !isGlobalAdmin && !targetId) {
      setError("Choose a location for this captain broadcast.");
      return;
    }
    setBusy(true); setError(""); setNotice("");
    const { error: rpcError } = await messagingRpc().rpc("admin_create_message_broadcast", {
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
    const { error: rpcError } = await messagingRpc().rpc("admin_resolve_message_report", {
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

  async function saveSupportCase(caseItem: SupportCase) {
    const draft = supportCaseDrafts[caseItem.case_id];
    if (!draft) return;
    if (draft.reason.trim().length < 5) {
      setError("Enter a support case update reason of at least five characters.");
      return;
    }
    if ((draft.status === "resolved" || draft.status === "closed") && draft.resolution_summary.trim().length < 10) {
      setError("Enter a resolution summary of at least ten characters before resolving or closing a case.");
      return;
    }
    setBusy(true); setError(""); setNotice("");
    const { error: rpcError } = await messagingRpc().rpc("admin_update_support_case", {
      p_case_id: caseItem.case_id,
      p_assigned_to: draft.assigned_to || null,
      p_status: draft.status,
      p_priority: draft.priority,
      p_resolution_summary: draft.resolution_summary.trim() || null,
      p_reason: draft.reason.trim(),
    });
    if (rpcError) setError(rpcError.message);
    else {
      setNotice("Support case updated and the change recorded in the audit history.");
      await load();
    }
    setBusy(false);
  }

  function updateSupportCaseDraft(caseId: string, changes: Partial<SupportCaseDraft>) {
    setSupportCaseDrafts((current) => ({
      ...current,
      [caseId]: { ...current[caseId], ...changes },
    }));
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
        <p className="form-note">Manage member support cases, send targeted announcements and review message reports. Case changes are audited; private support replies stay in the inbox.</p>
        {error && <p className="form-error" role="alert">{error}</p>}
        {notice && <p className="form-success" role="status">{notice}</p>}

        {announcementsEnabled === false && <p className="form-error" role="status">Announcements are currently paused by a platform administrator. Existing conversations and member messages remain available.</p>}
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
          <button type="submit" disabled={busy || announcementsEnabled !== true}>{busy ? "SENDING…" : announcementsEnabled === false ? "ANNOUNCEMENTS PAUSED" : "SEND ANNOUNCEMENT"}</button>
        </form>

        {isGlobalAdmin && <section className="messaging-moderation support-case-register">
          <div className="hub-section-heading"><span className="hub-kicker">MEMBER SUPPORT CASES</span><strong>{supportCases.length} cases</strong></div>
          <p className="form-note">Assign ownership, prioritise requests, track progress and record a reason for every case change. Resolving or closing a case requires a written resolution summary.</p>
          {supportCases.length === 0 ? <p className="form-note">No support cases have been raised.</p> : supportCases.map((caseItem) => {
            const draft = supportCaseDrafts[caseItem.case_id];
            if (!draft) return null;
            return <article className="messaging-report-card support-case-card" key={caseItem.case_id}>
              <div className="messaging-report-card-head">
                <strong>{caseItem.subject}</strong>
                <small>{new Date(caseItem.updated_at).toLocaleString("en-GB",{dateStyle:"medium",timeStyle:"short"})}</small>
              </div>
              <p><b>Requester:</b> {caseItem.requester_name} · <b>Status:</b> {caseItem.status.replaceAll("_"," ")}</p>
              {caseItem.last_message_preview && <blockquote>{caseItem.last_message_preview}</blockquote>}
              <div className="support-case-fields">
                <label>Assigned administrator
                  <select value={draft.assigned_to} disabled={busy} onChange={(event) => updateSupportCaseDraft(caseItem.case_id,{assigned_to:event.target.value})}>
                    <option value="">Unassigned</option>
                    {supportAdmins.map((admin) => <option key={admin.user_id} value={admin.user_id}>{admin.display_name}</option>)}
                  </select>
                </label>
                <label>Case status
                  <select value={draft.status} disabled={busy} onChange={(event) => updateSupportCaseDraft(caseItem.case_id,{status:event.target.value as SupportCase["status"]})}>
                    <option value="open">Open</option>
                    <option value="in_progress">In progress</option>
                    <option value="waiting_for_member">Waiting for member</option>
                    <option value="resolved">Resolved</option>
                    <option value="closed">Closed</option>
                  </select>
                </label>
                <label>Priority
                  <select value={draft.priority} disabled={busy} onChange={(event) => updateSupportCaseDraft(caseItem.case_id,{priority:event.target.value as SupportCase["priority"]})}>
                    <option value="low">Low</option>
                    <option value="normal">Normal</option>
                    <option value="high">High</option>
                    <option value="urgent">Urgent</option>
                  </select>
                </label>
                {(draft.status === "resolved" || draft.status === "closed") && <label>Resolution summary
                  <textarea rows={2} maxLength={1000} value={draft.resolution_summary} disabled={busy} onChange={(event) => updateSupportCaseDraft(caseItem.case_id,{resolution_summary:event.target.value})} placeholder="Summarise the outcome for the case record…"/>
                </label>}
                <label>Reason for this change
                  <textarea rows={2} maxLength={500} value={draft.reason} disabled={busy} onChange={(event) => updateSupportCaseDraft(caseItem.case_id,{reason:event.target.value})} placeholder="Explain the assignment, priority or status change…"/>
                </label>
              </div>
              <div className="messaging-moderation-actions">
                <button type="button" disabled={busy} onClick={() => void saveSupportCase(caseItem)}>SAVE CASE UPDATE</button>
                <Link className="messaging-back-link" to="/messages">OPEN INBOX TO REPLY</Link>
              </div>
            </article>;
          })}
        </section>}

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

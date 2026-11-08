import { useEffect, useMemo, useState } from "react";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { SiteNavigation } from "../components/site-navigation";
import { getSupabaseClient } from "../lib/supabase/client";

type NotificationRow = { id: string; event_type: string; payload: unknown; created_at: string; read_at: string | null };
type Preferences = { email_enabled: boolean; sms_enabled: boolean; in_app_enabled: boolean };

export const Route = createFileRoute("/notifications")({ component: NotificationsPage });

function notificationCopy(row: NotificationRow): { title: string; body: string; href: string } {
  const payload = (row.payload && typeof row.payload === "object" ? row.payload : {}) as Record<string, unknown>;
  const home = String(payload.home_team_name ?? "Home team");
  const away = String(payload.away_team_name ?? "Away team");
  const team = String(payload.team_name ?? "your team");
  switch (row.event_type) {
    case "team.membership_approved": return { title: "Team request approved", body: "Your request to join " + team + " has been approved.", href: "/player#teams" };
    case "team.membership_rejected": return { title: "Team request update", body: "Your request to join " + team + " was not approved.", href: "/player#teams" };
    case "team.membership_removed": return { title: "Team membership update", body: "Your membership with " + team + " has ended. Contact Open Play if you need help.", href: "/player#teams" };
    case "team.registration_approved": return { title: "Team registration approved", body: team + " has been approved for Open Play.", href: "/player#teams" };
    case "team.registration_rejected": return { title: "Team registration update", body: "The registration for " + team + " was not approved.", href: "/player#teams" };
    case "player.banned": return { title: "Player eligibility update", body: "Your player account is currently restricted. Contact Open Play support.", href: "/support" };
    case "player.unbanned": return { title: "Player eligibility restored", body: "Your player account is eligible for future team sheets.", href: "/player" };
    case "player.transfer_approved": return { title: "Transfer approved", body: "Your team transfer has been approved.", href: "/player#teams" };
    case "player.transfer_rejected": return { title: "Transfer request update", body: "Your team transfer request was not approved.", href: "/player#teams" };
    case "fixture.scheduled": return { title: "Fixture scheduled", body: home + " v " + away + " has been scheduled.", href: "/match-centre" };
    case "fixture.reminder_24h": return { title: "Match reminder", body: home + " v " + away + " is scheduled for tomorrow.", href: "/match-centre" };
    case "fixture.reminder_3h": return { title: "Match reminder", body: home + " v " + away + " is scheduled in about three hours.", href: "/match-centre" };
    case "fixture.rescheduled": return { title: "Fixture rescheduled", body: home + " v " + away + " has been rescheduled.", href: "/match-centre" };
    case "fixture.status_changed": return { title: "Fixture update", body: home + " v " + away + " has a status update.", href: "/match-centre" };
    case "fixture.result_published": return { title: "Result published", body: "The result for " + home + " v " + away + " is now available.", href: "/match-centre" };
    case "fixture.result_corrected": return { title: "Result corrected", body: "The result for " + home + " v " + away + " has been corrected.", href: "/match-centre" };
    default: return { title: row.event_type.replaceAll(".", " ").replaceAll("_", " "), body: "You have received an Open Play update.", href: "/account" };
  }
}

function NotificationsPage() {
  const navigate = useNavigate();
  const [rows, setRows] = useState<NotificationRow[]>([]);
  const [preferences, setPreferences] = useState<Preferences | null>(null);
  const [filter, setFilter] = useState<"all" | "unread">("all");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  async function refresh() {
    const supabase = getSupabaseClient();
    const [{ data, error: rowsError }, { data: prefs, error: prefsError }] = await Promise.all([
      supabase.from("notification_events").select("id,event_type,payload,created_at,read_at").eq("channel", "in_app").eq("status", "sent").order("created_at", { ascending: false }).limit(100),
      supabase.rpc("get_my_notification_preferences"),
    ]);
    if (rowsError || prefsError) throw rowsError ?? prefsError;
    setRows((data ?? []) as NotificationRow[]);
    setPreferences(prefs as unknown as Preferences);
  }

  useEffect(() => {
    let alive = true;
    async function load() {
      try {
        const { data: { session } } = await getSupabaseClient().auth.getSession();
        if (!session) { await navigate({ to: "/sign-in" }); return; }
        await refresh();
      } catch (cause) {
        if (alive) setError(cause instanceof Error ? cause.message : "Unable to load notifications.");
      } finally { if (alive) setLoading(false); }
    }
    void load();
    return () => { alive = false; };
  }, [navigate]);

  const unreadCount = rows.filter(row => !row.read_at).length;
  const visible = useMemo(() => filter === "unread" ? rows.filter(row => !row.read_at) : rows, [filter, rows]);

  async function markRead(id: string) {
    setError(""); setMessage("");
    const { error: readError } = await getSupabaseClient().rpc("mark_notification_read", { p_event_id: id });
    if (readError) { setError(readError.message); return; }
    setRows(old => old.map(row => row.id === id ? { ...row, read_at: new Date().toISOString() } : row));
  }

  async function markAllRead() {
    setSaving(true); setError(""); setMessage("");
    const unread = rows.filter(row => !row.read_at);
    const results = await Promise.all(unread.map(row => getSupabaseClient().rpc("mark_notification_read", { p_event_id: row.id })));
    const failed = results.find(result => result.error)?.error;
    if (failed) setError(failed.message);
    else {
      const now = new Date().toISOString();
      setRows(old => old.map(row => row.read_at ? row : { ...row, read_at: now }));
      setMessage("All notifications marked as read.");
    }
    setSaving(false);
  }

  async function savePreferences(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (!preferences) return;
    setSaving(true); setError(""); setMessage("");
    const { data, error: saveError } = await getSupabaseClient().rpc("update_my_notification_preferences", { p_email_enabled: preferences.email_enabled, p_sms_enabled: preferences.sms_enabled, p_in_app_enabled: preferences.in_app_enabled });
    if (saveError) setError(saveError.message);
    else { setPreferences(data as unknown as Preferences); setMessage("Notification preferences saved."); }
    setSaving(false);
  }

  if (loading) return <main className="notice-page"><SiteNavigation /><section className="notice-panel"><p>Loading notifications…</p></section></main>;

  return <main className="notice-page"><SiteNavigation /><section className="notice-panel notification-page">
    <Link className="account-back-link" to="/account">← MY ACCOUNT</Link>
    <p className="eyebrow eyebrow-dark">YOUR OPEN PLAY</p><h1>NOTIFI<em>CATIONS</em></h1>
    <div className="notification-page-heading"><span>{unreadCount} unread</span><button type="button" className="auth-text-button" disabled={saving || unreadCount === 0} onClick={() => void markAllRead()}>MARK ALL AS READ</button></div>
    <div className="notification-filter"><button type="button" className={filter === "all" ? "active" : ""} onClick={() => setFilter("all")}>All</button><button type="button" className={filter === "unread" ? "active" : ""} onClick={() => setFilter("unread")}>Unread</button></div>
    {error && <p className="form-error" role="alert">{error}</p>}{message && <p className="form-success" role="status">{message}</p>}
    {visible.length === 0 ? <p className="form-note">{filter === "unread" ? "You have no unread notifications." : "You have no notifications yet. Important Open Play updates will appear here."}</p> : <div className="notification-list">{visible.map(row => { const copy = notificationCopy(row); return <article className={row.read_at ? "notification-card" : "notification-card unread"} key={row.id}><div><span className="notification-card-type">{row.event_type.split(".")[0].replaceAll("_", " ")}</span><h2>{copy.title}</h2><p>{copy.body}</p><time dateTime={row.created_at}>{new Date(row.created_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</time></div><div className="notification-card-actions"><a href={copy.href} onClick={() => { if (!row.read_at) void markRead(row.id); }}>OPEN</a>{!row.read_at && <button type="button" onClick={() => void markRead(row.id)}>MARK READ</button>}</div></article>; })}</div>}
    <section className="notification-preference-panel"><h2>Delivery preferences</h2><p>Choose the channels Open Play can use. Push notifications and category-level controls will appear when device delivery is configured.</p>{preferences && <form onSubmit={savePreferences}><label><input type="checkbox" checked={preferences.in_app_enabled} onChange={e=>setPreferences(old=>old?{...old,in_app_enabled:e.target.checked}:old)}/> In-app notifications</label><label><input type="checkbox" checked={preferences.email_enabled} onChange={e=>setPreferences(old=>old?{...old,email_enabled:e.target.checked}:old)}/> Email notifications</label><label><input type="checkbox" checked={preferences.sms_enabled} onChange={e=>setPreferences(old=>old?{...old,sms_enabled:e.target.checked}:old)}/> I agree to receive service SMS/text messages about team approvals, fixtures, reminders and results. Message/data rates may apply. I can switch this off at any time.</label><button className="button button-small" disabled={saving}>SAVE PREFERENCES</button></form>}</section>
  </section></main>;
}

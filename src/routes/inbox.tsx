import { useCallback, useEffect, useState, type KeyboardEvent } from "react";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AuthenticatedSessionBoundary } from "../components/authenticated-session-boundary";
import { MessagesPanel } from "../components/messages-panel";
import { PlayerBottomNavigation } from "../components/player-bottom-navigation";
import { useRequiredSession } from "../lib/auth/use-required-session";
import { describeNotification } from "../lib/notifications/describe";
import { getSupabaseClient } from "../lib/supabase/client";

type InboxTab = "notifications" | "messages";

/**
 * Owner decision D4: one Inbox with two sections.
 * - Notifications: automated league alerts and official announcements.
 * - Messages: player-to-player messaging (secure messaging rules apply server-side).
 */
export const Route = createFileRoute("/inbox")({
  validateSearch: (search: Record<string, unknown>): { tab: InboxTab } => ({
    tab: search.tab === "messages" ? "messages" : "notifications",
  }),
  component: InboxPage,
});

type NotificationRow = { id: string; event_type: string; payload: unknown; created_at: string; read_at: string | null };
type Announcement = { conversation_id: string; title: string; last_message_body: string | null; last_message_at: string | null; unread_count: number };
type RpcClient = { rpc: (name: string, args?: Record<string, unknown>) => Promise<{ data: unknown; error: { message: string } | null }> };

function InboxPage() {
  // PR #117: remount the Inbox when the signed-in account changes so no previous
  // user's notifications or messages survive on a shared device.
  return (
    <AuthenticatedSessionBoundary label="INBOX">
      <InboxWorkspace />
    </AuthenticatedSessionBoundary>
  );
}

function InboxWorkspace() {
  const { tab } = Route.useSearch();
  const navigate = useNavigate();
  const authStatus = useRequiredSession();
  const [notifications, setNotifications] = useState<NotificationRow[]>([]);
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setError("");
    const supabase = getSupabaseClient();
    const { data: sessionData } = await supabase.auth.getSession();
    const userId = sessionData.session?.user.id;
    if (!userId) {
      setLoading(false);
      return;
    }
    const [notificationResult, conversationResult] = await Promise.all([
      supabase.from("notification_events").select("id,event_type,payload,created_at,read_at")
        .eq("user_id", userId).eq("channel", "in_app").eq("status", "sent")
        .order("created_at", { ascending: false }).limit(50),
      (supabase as unknown as RpcClient).rpc("get_my_message_conversations", { p_limit: 100 }),
    ]);
    if (notificationResult.error) setError(notificationResult.error.message);
    else setNotifications(notificationResult.data as NotificationRow[]);
    if (conversationResult.error) setError((current) => current || conversationResult.error!.message);
    else setAnnouncements(((conversationResult.data ?? []) as Array<Announcement & { kind: string }>).filter((row) => row.kind === "announcement"));
    setLoading(false);
  }, []);

  useEffect(() => {
    if (authStatus === "authenticated") void load();
    if (authStatus === "unauthenticated") setLoading(false);
  }, [authStatus, load]);

  async function markRead(id: string) {
    const { error: rpcError } = await getSupabaseClient().rpc("mark_notification_read", { p_event_id: id });
    if (rpcError) {
      setError(rpcError.message);
      return;
    }
    setNotifications((rows) => rows.map((row) => (row.id === id ? { ...row, read_at: new Date().toISOString() } : row)));
  }

  const leagueAlerts = notifications.filter((row) => describeNotification(row.event_type, null).category === "league");
  const messageAlerts = notifications.filter((row) => describeNotification(row.event_type, null).category === "message");
  const unreadLeague = leagueAlerts.filter((row) => !row.read_at).length + announcements.reduce((sum, a) => sum + (a.unread_count > 0 ? 1 : 0), 0);
  const unreadMessages = messageAlerts.filter((row) => !row.read_at).length;

  const selectTab = (next: InboxTab) => void navigate({ to: "/inbox", search: { tab: next }, replace: true });
  const onTabKey = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
      event.preventDefault();
      selectTab(tab === "notifications" ? "messages" : "notifications");
    }
  };

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel inbox-panel">
        <p className="eyebrow eyebrow-dark">YOUR OPEN PLAY</p>
        <h1>Inbox.</h1>
        <div className="inbox-tabs" role="tablist" aria-label="Inbox sections" onKeyDown={onTabKey}>
          <button type="button" role="tab" id="inbox-tab-notifications" aria-controls="inbox-panel-notifications"
            aria-selected={tab === "notifications"} tabIndex={tab === "notifications" ? 0 : -1} onClick={() => selectTab("notifications")}>
            NOTIFICATIONS{unreadLeague > 0 && <span className="inbox-badge" aria-label={`${unreadLeague} unread`}>{unreadLeague}</span>}
          </button>
          <button type="button" role="tab" id="inbox-tab-messages" aria-controls="inbox-panel-messages"
            aria-selected={tab === "messages"} tabIndex={tab === "messages" ? 0 : -1} onClick={() => selectTab("messages")}>
            MESSAGES{unreadMessages > 0 && <span className="inbox-badge" aria-label={`${unreadMessages} unread`}>{unreadMessages}</span>}
          </button>
        </div>
        {error && <p className="form-error" role="alert">{error}</p>}

        {tab === "notifications" ? (
          <section role="tabpanel" id="inbox-panel-notifications" aria-labelledby="inbox-tab-notifications" className="hub-notification-feed">
            {loading || authStatus === "loading" ? (
              <p className="form-note" role="status">Loading notifications…</p>
            ) : (
              <>
                {announcements.length > 0 && (
                  <div className="inbox-announcements">
                    <div className="hub-section-heading"><span className="hub-kicker">OFFICIAL ANNOUNCEMENTS</span><span>{announcements.length}</span></div>
                    {announcements.map((a) => (
                      <article className={a.unread_count > 0 ? "player-notification unread" : "player-notification"} key={a.conversation_id}>
                        <div>
                          <strong>{a.title}</strong>
                          {a.last_message_body && <p>{a.last_message_body}</p>}
                          {a.last_message_at && <small>{new Date(a.last_message_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</small>}
                        </div>
                      </article>
                    ))}
                  </div>
                )}
                <div className="hub-section-heading"><span className="hub-kicker">LEAGUE ALERTS</span><span>{leagueAlerts.filter((n) => !n.read_at).length} unread</span></div>
                {leagueAlerts.length === 0 ? (
                  <p className="form-note">No notifications yet. Team approvals, fixtures and results will appear here.</p>
                ) : (
                  leagueAlerts.map((n) => {
                    const described = describeNotification(n.event_type, n.payload as Record<string, unknown> | null);
                    return (
                      <article className={n.read_at ? "player-notification" : "player-notification unread"} key={n.id}>
                        <div>
                          <strong>{described.title}</strong>
                          <p>{described.body}</p>
                          <small>{new Date(n.created_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</small>
                        </div>
                        {!n.read_at && <button type="button" onClick={() => void markRead(n.id)}>MARK READ</button>}
                      </article>
                    );
                  })
                )}
              </>
            )}
          </section>
        ) : (
          <section role="tabpanel" id="inbox-panel-messages" aria-labelledby="inbox-tab-messages">
            <MessagesPanel embedded />
          </section>
        )}
      </section>
      <PlayerBottomNavigation />
    </main>
  );
}

import { useCallback, useEffect, useMemo, useState, type KeyboardEvent } from "react";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AuthenticatedSessionBoundary } from "../components/authenticated-session-boundary";
import { MessagesPanel } from "../components/messages-panel";
import { PlayerBottomNavigation } from "../components/player-bottom-navigation";
import {
  buildInboxActivity,
  unreadCount,
  type InboxActivityItem,
  type InboxConversationInput,
  type InboxFilter,
  type InboxNotificationInput,
} from "../lib/notifications/inbox-activity";
import { getSupabaseClient } from "../lib/supabase/client";

/**
 * Owner decision D4 and visual reference IMG_0576: "Your Inbox." with three filters.
 * - All: one chronological activity feed.
 * - Messages: person-to-person / captain messaging (secure messaging rules apply server-side).
 * - Notifications: automated league alerts and official announcements.
 */
export const Route = createFileRoute("/inbox")({
  validateSearch: (search: Record<string, unknown>): { tab: InboxFilter } => ({
    tab: search.tab === "messages" || search.tab === "notifications" ? search.tab : "all",
  }),
  component: InboxPage,
});

type RpcClient = { rpc: (name: string, args?: Record<string, unknown>) => Promise<{ data: unknown; error: { message: string } | null }> };

const FILTERS: Array<{ id: InboxFilter; label: string }> = [
  { id: "all", label: "ALL" },
  { id: "messages", label: "MESSAGES" },
  { id: "notifications", label: "NOTIFICATIONS" },
];

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
  const [notifications, setNotifications] = useState<InboxNotificationInput[]>([]);
  const [conversations, setConversations] = useState<InboxConversationInput[]>([]);
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
    // Both reads are recipient-scoped server-side (RLS on notification_events; the
    // messaging RPC returns only conversations the caller participates in).
    const [notificationResult, conversationResult] = await Promise.all([
      supabase.from("notification_events").select("id,event_type,payload,created_at,read_at")
        .eq("user_id", userId).eq("channel", "in_app").eq("status", "sent")
        .order("created_at", { ascending: false }).limit(50),
      (supabase as unknown as RpcClient).rpc("get_my_message_conversations", { p_limit: 100 }),
    ]);
    if (notificationResult.error) setError(notificationResult.error.message);
    else setNotifications(notificationResult.data as InboxNotificationInput[]);
    if (conversationResult.error) setError((current) => current || conversationResult.error!.message);
    else setConversations((conversationResult.data ?? []) as InboxConversationInput[]);
    setLoading(false);
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const activity = useMemo(() => buildInboxActivity(notifications, conversations), [notifications, conversations]);
  const visible = tab === "notifications" ? activity.filter((item) => item.section === "notifications") : activity;

  async function markRead(id: string) {
    const { error: rpcError } = await getSupabaseClient().rpc("mark_notification_read", { p_event_id: id });
    if (rpcError) {
      setError(rpcError.message);
      return;
    }
    setNotifications((rows) => rows.map((row) => (row.id === id ? { ...row, read_at: new Date().toISOString() } : row)));
  }

  const selectTab = (next: InboxFilter) => void navigate({ to: "/inbox", search: { tab: next }, replace: true });
  const onTabKey = (event: KeyboardEvent<HTMLDivElement>) => {
    const index = FILTERS.findIndex((f) => f.id === tab);
    if (event.key === "ArrowRight") { event.preventDefault(); selectTab(FILTERS[(index + 1) % FILTERS.length].id); }
    if (event.key === "ArrowLeft") { event.preventDefault(); selectTab(FILTERS[(index + FILTERS.length - 1) % FILTERS.length].id); }
  };
  const badge = (id: InboxFilter) => unreadCount(activity, id === "all" ? undefined : id);

  return (
    <main className="notice-page player-facing">
      <section className="notice-panel inbox-panel">
        <p className="eyebrow eyebrow-dark">YOUR OPEN PLAY</p>
        <h1>Your Inbox.</h1>
        <p className="form-note">League alerts, official announcements and messages from your teammates, all in one place.</p>
        <div className="inbox-tabs" role="tablist" aria-label="Inbox filters" onKeyDown={onTabKey}>
          {FILTERS.map((filter) => {
            const unread = badge(filter.id);
            return (
              <button key={filter.id} type="button" role="tab" id={`inbox-tab-${filter.id}`} aria-controls={`inbox-panel-${filter.id}`}
                aria-selected={tab === filter.id} tabIndex={tab === filter.id ? 0 : -1} onClick={() => selectTab(filter.id)}>
                {filter.label}{unread > 0 && <span className="inbox-badge" aria-label={`${unread} unread`}>{unread}</span>}
              </button>
            );
          })}
        </div>
        {error && <p className="form-error" role="alert">{error}</p>}

        {tab === "messages" ? (
          <section role="tabpanel" id="inbox-panel-messages" aria-labelledby="inbox-tab-messages">
            <MessagesPanel embedded />
          </section>
        ) : (
          <section role="tabpanel" id={`inbox-panel-${tab}`} aria-labelledby={`inbox-tab-${tab}`} className="hub-notification-feed">
            <div className="hub-section-heading">
              <span className="hub-kicker">RECENT ACTIVITY</span>
              <span>{unreadCount(visible)} unread</span>
            </div>
            {loading ? (
              <p className="form-note" role="status">Loading your inbox…</p>
            ) : visible.length === 0 ? (
              <p className="form-note">
                {tab === "notifications"
                  ? "No notifications yet. Team approvals, fixtures, results and official announcements will appear here."
                  : "Nothing here yet. Notifications and messages will appear here as they arrive."}
              </p>
            ) : (
              visible.map((item) => <ActivityCard key={item.id} item={item} onMarkRead={markRead} onOpenMessages={() => selectTab("messages")} />)
            )}
          </section>
        )}
      </section>
      <PlayerBottomNavigation />
    </main>
  );
}

function ActivityCard({ item, onMarkRead, onOpenMessages }: { item: InboxActivityItem; onMarkRead: (id: string) => void; onOpenMessages: () => void }) {
  return (
    <article className={item.unread ? "player-notification unread" : "player-notification"}>
      <div>
        <span className={`inbox-type inbox-type-${item.section}`}>{item.typeLabel}</span>
        <strong>{item.title}</strong>
        {item.preview && <p>{item.preview}</p>}
        <small>{new Date(item.at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</small>
      </div>
      {item.source === "notification" && item.unread && <button type="button" onClick={() => onMarkRead(item.refId)}>MARK READ</button>}
      {item.source === "conversation" && <button type="button" onClick={onOpenMessages}>OPEN</button>}
    </article>
  );
}

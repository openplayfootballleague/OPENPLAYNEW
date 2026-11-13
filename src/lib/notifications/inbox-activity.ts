import { describeNotification } from "./describe";

/**
 * Inbox "All" activity feed (visual reference IMG_0576, spec section 5): one chronological
 * list combining league notifications, official announcements and person-to-person
 * conversations. Notifications are never presented as direct messages.
 */

export type InboxFilter = "all" | "messages" | "notifications";

export type InboxNotificationInput = { id: string; event_type: string; payload: unknown; created_at: string; read_at: string | null };
export type InboxConversationInput = {
  conversation_id: string;
  kind: "direct" | "team" | "support" | "announcement";
  title: string;
  other_participant_name?: string | null;
  last_message_body: string | null;
  last_message_at: string | null;
  updated_at?: string | null;
  unread_count: number;
};

export type InboxActivityItem = {
  id: string;
  source: "notification" | "announcement" | "conversation";
  section: "notifications" | "messages";
  title: string;
  typeLabel: string;
  preview: string;
  at: string;
  unread: boolean;
  /** Notification row id, for mark-read; conversation id for conversations. */
  refId: string;
};

const CONVERSATION_LABEL: Record<InboxConversationInput["kind"], string> = {
  direct: "Message",
  team: "Team chat",
  support: "Support",
  announcement: "Announcement",
};

export function buildInboxActivity(
  notifications: readonly InboxNotificationInput[],
  conversations: readonly InboxConversationInput[],
): InboxActivityItem[] {
  const items: InboxActivityItem[] = [];
  for (const n of notifications) {
    const described = describeNotification(n.event_type, n.payload as Record<string, unknown> | null);
    // "New message" alerts point at a conversation that is already listed in the feed.
    if (described.category === "message") continue;
    items.push({
      id: `n:${n.id}`, source: "notification", section: "notifications", title: described.title,
      typeLabel: "League alert", preview: described.body, at: n.created_at, unread: !n.read_at, refId: n.id,
    });
  }
  for (const c of conversations) {
    const at = c.last_message_at ?? c.updated_at;
    if (!at) continue; // An empty conversation has no activity to show yet.
    const isAnnouncement = c.kind === "announcement";
    items.push({
      id: `c:${c.conversation_id}`,
      source: isAnnouncement ? "announcement" : "conversation",
      section: isAnnouncement ? "notifications" : "messages",
      title: (c.kind === "direct" && c.other_participant_name) || c.title,
      typeLabel: CONVERSATION_LABEL[c.kind],
      preview: c.last_message_body ?? "",
      at,
      unread: c.unread_count > 0,
      refId: c.conversation_id,
    });
  }
  return items.sort((a, b) => b.at.localeCompare(a.at) || a.id.localeCompare(b.id));
}

export function unreadCount(items: readonly InboxActivityItem[], section?: "notifications" | "messages"): number {
  return items.filter((item) => item.unread && (!section || item.section === section)).length;
}

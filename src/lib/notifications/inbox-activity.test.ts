import { describe, expect, it } from "vitest";
import { buildInboxActivity, unreadCount } from "./inbox-activity";

const notifications = [
  { id: "n1", event_type: "fixture.result_published", payload: { home_team_name: "A", away_team_name: "B", home_score: 2, away_score: 0 }, created_at: "2026-11-13T10:00:00Z", read_at: null },
  { id: "n2", event_type: "message.new", payload: {}, created_at: "2026-11-13T12:00:00Z", read_at: null },
  { id: "n3", event_type: "fixture.scheduled", payload: {}, created_at: "2026-11-12T09:00:00Z", read_at: "2026-11-12T10:00:00Z" },
];
const conversations = [
  { conversation_id: "c1", kind: "announcement" as const, title: "Season update", last_message_body: "Fixtures out", last_message_at: "2026-11-13T11:00:00Z", unread_count: 1 },
  { conversation_id: "c2", kind: "direct" as const, title: "Direct message", other_participant_name: "Sam", last_message_body: "See you Friday", last_message_at: "2026-11-13T12:30:00Z", unread_count: 2 },
  { conversation_id: "c3", kind: "team" as const, title: "Instow Rovers", last_message_body: null, last_message_at: null, updated_at: null, unread_count: 0 },
];

describe("Inbox All activity feed", () => {
  const items = buildInboxActivity(notifications, conversations);

  it("is chronological, newest first, across notifications and conversations", () => {
    expect(items.map((i) => i.id)).toEqual(["c:c2", "c:c1", "n:n1", "n:n3"]);
  });

  it("drops new-message alerts because the conversation itself is listed", () => {
    expect(items.some((i) => i.refId === "n2")).toBe(false);
  });

  it("files announcements under Notifications, never as private messages", () => {
    const announcement = items.find((i) => i.refId === "c1");
    expect(announcement).toMatchObject({ source: "announcement", section: "notifications", typeLabel: "Announcement" });
  });

  it("titles direct conversations by the other participant and skips empty conversations", () => {
    expect(items.find((i) => i.refId === "c2")).toMatchObject({ title: "Sam", typeLabel: "Message", section: "messages" });
    expect(items.some((i) => i.refId === "c3")).toBe(false);
  });

  it("counts unread items per section", () => {
    expect(unreadCount(items)).toBe(3);
    expect(unreadCount(items, "notifications")).toBe(2);
    expect(unreadCount(items, "messages")).toBe(1);
  });
});

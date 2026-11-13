export type PushMessage = { heading: string; body: string; path: string };

export function renderPushMessage(eventType: string): PushMessage {
  switch (eventType) {
    case "message.new":
      return { heading: "New Open Play message", body: "You have a new message. Sign in to view it.", path: "/messages" };
    case "fixture.scheduled":
    case "fixture.reminder_24h":
    case "fixture.reminder_3h":
    case "fixture.rescheduled":
    case "fixture.status_changed":
    case "fixture.result_published":
    case "fixture.result_corrected":
      return { heading: "Open Play match update", body: "There is an update to one of your fixtures. Open Match Centre for details.", path: "/match-centre" };
    case "team.membership_approved":
    case "team.membership_rejected":
    case "team.membership_removed":
    case "team.registration_approved":
    case "team.registration_rejected":
    case "player.transfer_approved":
    case "player.transfer_rejected":
      return { heading: "Open Play team update", body: "There is an update to your team or membership. Sign in to view details.", path: "/player" };
    case "player.banned":
    case "player.unbanned":
    case "player.guardian_consent.captain_review_required":
      return { heading: "Open Play account update", body: "There is an update to your account that needs your attention. Sign in to view details.", path: "/player" };
    default:
      if (eventType.startsWith("referee.")) {
        return { heading: "Open Play referee update", body: "There is an update to a match report. Sign in to view details.", path: "/referee" };
      }
      if (eventType.startsWith("support.")) {
        return { heading: "Open Play support update", body: "There is an update to your support request. Sign in to view details.", path: "/messages" };
      }
      return { heading: "Open Play notification", body: "You have a new update. Sign in to view details.", path: "/notifications" };
  }
}

export function buildOneSignalPayload(
  appId: string,
  externalId: string,
  eventId: string,
  message: PushMessage,
  appOrigin: string,
) {
  const origin = new URL(appOrigin);
  if (origin.protocol !== "https:" && origin.hostname !== "localhost" && origin.hostname !== "127.0.0.1") {
    throw new Error("Push notification app origin must use HTTPS");
  }
  if (!origin.hostname || origin.username || origin.password || origin.search || origin.hash) {
    throw new Error("Push notification app origin is invalid");
  }
  const targetUrl = new URL(message.path, origin.origin).toString();
  return {
    app_id: appId,
    target_channel: "push",
    include_aliases: { external_id: [externalId] },
    headings: { en: message.heading },
    contents: { en: message.body },
    url: targetUrl,
    data: { deep_link: message.path },
    idempotency_key: eventId,
  };
}

export type SafePushDevice = {
  subscriptionId: string;
  type: string;
  enabled: boolean;
  deviceModel: string | null;
  deviceOs: string | null;
  createdAt: string | null;
  lastActive: string | null;
};

export function sanitisePushDevice(value: unknown): SafePushDevice | null {
  if (!value || typeof value !== "object") return null;
  const item = value as Record<string, unknown>;
  if (typeof item.id !== "string" || !/^[0-9a-f-]{36}$/i.test(item.id)) return null;
  return {
    subscriptionId: item.id,
    type: typeof item.type === "string" ? item.type.slice(0, 40) : "Web",
    enabled: item.enabled === true,
    deviceModel: typeof item.device_model === "string" ? item.device_model.slice(0, 80) : null,
    deviceOs: typeof item.device_os === "string" ? item.device_os.slice(0, 80) : null,
    createdAt: typeof item.created_at === "string" ? item.created_at : null,
    lastActive: typeof item.last_active === "string" ? item.last_active : null,
  };
}

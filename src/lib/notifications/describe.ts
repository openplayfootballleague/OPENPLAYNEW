/**
 * In-app notification wording, shared by the Player Hub feed and the Inbox
 * (owner decision D4). Text is unchanged from the original Player Hub feed.
 */

export type NotificationCategory = "league" | "message";

export type NotificationDescription = {
  title: string;
  body: string;
  category: NotificationCategory;
};

export function describeNotification(eventType: string, payload: Record<string, unknown> | null | undefined): NotificationDescription {
  const p = payload ?? {};
  const home = String(p.home_team_name ?? "Home team");
  const away = String(p.away_team_name ?? "Away team");
  const score = `${p.home_score ?? "–"}–${p.away_score ?? "–"}`;
  const reason = String(p.reason ?? "Contact Open Play for details.");
  const bodies: Record<string, string> = {
    "team.membership_approved": `Your request to join ${p.team_name ?? "the team"} has been approved.`,
    "team.membership_rejected": `Your request to join ${p.team_name ?? "the team"} was not approved.`,
    "team.membership_removed": `Your membership with ${p.team_name ?? "the team"} has been ended by an administrator. Reason: ${reason}`,
    "team.registration_approved": `Your team ${p.team_name ?? ""} has been approved.`,
    "team.registration_rejected": `Your team registration for ${p.team_name ?? "Open Play"} was not approved.`,
    "player.banned": `Your player account has been suspended from future team sheets. Reason: ${reason}`,
    "player.unbanned": "Your player account is no longer suspended and can be considered for future team sheets.",
    "player.transfer_approved": `Your move from ${p.source_team_name ?? "your previous team"} to ${p.team_name ?? "your new team"} has been approved.`,
    "player.transfer_rejected": `Your transfer request to ${p.team_name ?? "the destination team"} was not approved. Reason: ${reason}`,
    "fixture.scheduled": `Fixture scheduled: ${home} v ${away}.`,
    "fixture.reminder_24h": `Reminder: ${home} v ${away} is scheduled for tomorrow.`,
    "fixture.reminder_3h": `Reminder: ${home} v ${away} is scheduled in about three hours.`,
    "fixture.rescheduled": `Fixture rescheduled: ${home} v ${away}.`,
    "fixture.result_published": `Result: ${home} ${score} ${away}.`,
    "fixture.result_corrected": `Corrected result: ${home} ${score} ${away}.`,
    "fixture.status_changed": `Fixture update: ${home} v ${away} is now ${p.status ?? "updated"}.`,
    "message.new": "You have a new message in your Open Play inbox.",
  };
  return {
    title: eventType.replaceAll(".", " ").replaceAll("_", " "),
    body: bodies[eventType] ?? "You have a new Open Play update.",
    category: eventType.startsWith("message.") ? "message" : "league",
  };
}

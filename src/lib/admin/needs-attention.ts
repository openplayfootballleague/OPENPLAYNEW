export type NeedsAttentionTask = {
  id: string;
  category: "Player review" | "Team application" | "Membership request" | "Missing team sheet" | "Player transfer request" | "Notification exception" | "Result needs attention" | "Fixture needs attention" | "Payment due" | "Payment exception";
  subject: string;
  context: string;
  createdAt: string;
  href: "#admin-player-approvals" | "#admin-team-approvals" | "#admin-membership-requests" | "#admin-team-sheets" | "#admin-transfers" | "#admin-communications" | "#admin-results" | "#admin-fixtures" | "/finance";
  actionLabel: string;
};

export type NeedsAttentionInput = {
  playerReviews: ReadonlyArray<{ player_id: string; full_name: string; created_at: string }>;
  teamApplications: ReadonlyArray<{ season_team_id: string; team_name: string; season_name: string; created_at: string }>;
  membershipRequests: ReadonlyArray<{ membership_id: string; team_name: string; player_name: string; created_at: string }>;
  fixtures?: ReadonlyArray<{ id: string; season_name: string; gameweek: number; scheduled_at: string | null; status: string; home_team_id: string; away_team_id: string; home_team_name: string; away_team_name: string; home_score?: number | null; away_score?: number | null }>;
  submittedSheets?: ReadonlyArray<{ fixture_id: string; season_team_id: string; is_locked: boolean }>;
  transferRequests?: ReadonlyArray<{ id: string; player_name: string | null; source_team_name: string; destination_team_name: string; season_name: string; requested_at: string }>;
  notifications?: ReadonlyArray<{ id: string; recipient_name: string | null; recipient_email: string | null; recipient_phone: string | null; event_type: string; status: string; created_at: string; last_error: string | null; hold_reason: string | null }>;
  paymentObligations?: ReadonlyArray<{ obligation_id: string; season_name: string; team_name: string; opponent_name: string; gameweek: number; amount_pence: number; deadline_at: string; status: string; refund_status: string | null }>;
};

/**
 * Build the actionable approval items already returned by the Admin Dashboard RPC.
 * Oldest requests appear first; no urgency or deadline is inferred from age alone.
 */
export function buildNeedsAttentionTasks(input: NeedsAttentionInput, limit = 12): NeedsAttentionTask[] {
  const tasks: NeedsAttentionTask[] = [
    ...input.playerReviews.map((item): NeedsAttentionTask => ({
      id: `player:${item.player_id}`,
      category: "Player review",
      subject: item.full_name,
      context: "Player registration and identity checks",
      createdAt: item.created_at,
      href: "#admin-player-approvals",
      actionLabel: "Review player",
    })),
    ...input.teamApplications.map((item): NeedsAttentionTask => ({
      id: `team:${item.season_team_id}`,
      category: "Team application",
      subject: item.team_name,
      context: item.season_name,
      createdAt: item.created_at,
      href: "#admin-team-approvals",
      actionLabel: "Review team",
    })),
    ...input.membershipRequests.map((item): NeedsAttentionTask => ({
      id: `membership:${item.membership_id}`,
      category: "Membership request",
      subject: item.player_name,
      context: item.team_name,
      createdAt: item.created_at,
      href: "#admin-membership-requests",
      actionLabel: "Review request",
    })),
  ];

  const submittedSheetKeys = new Set((input.submittedSheets ?? []).filter((sheet) => sheet.is_locked).map((sheet) => `${sheet.fixture_id}:${sheet.season_team_id}`));
  for (const fixture of input.fixtures ?? []) {
    if (fixture.status === "postponed") {
      tasks.push({
        id: `fixture:postponed:${fixture.id}`,
        category: "Fixture needs attention",
        subject: `${fixture.home_team_name} vs ${fixture.away_team_name}`,
        context: `${fixture.season_name} · Gameweek ${fixture.gameweek} · Postponed fixture awaiting a new date`,
        createdAt: fixture.scheduled_at ?? "",
        href: "#admin-fixtures",
        actionLabel: "Reschedule fixture",
      });
    }
    if (fixture.status === "completed" && (fixture.home_score == null || fixture.away_score == null)) {
      tasks.push({
        id: `result:${fixture.id}`,
        category: "Result needs attention",
        subject: `${fixture.home_team_name} vs ${fixture.away_team_name}`,
        context: `${fixture.season_name} · Gameweek ${fixture.gameweek} · Completed fixture has no confirmed score`,
        createdAt: fixture.scheduled_at ?? "",
        href: "#admin-results",
        actionLabel: "Review result",
      });
    }
    if (fixture.status !== "scheduled" && fixture.status !== "in_progress") continue;
    for (const side of [
      { teamId: fixture.home_team_id, teamName: fixture.home_team_name },
      { teamId: fixture.away_team_id, teamName: fixture.away_team_name },
    ]) {
      if (submittedSheetKeys.has(`${fixture.id}:${side.teamId}`)) continue;
      tasks.push({
        id: `sheet:${fixture.id}:${side.teamId}`,
        category: "Missing team sheet",
        subject: side.teamName,
        context: `${fixture.season_name} · Gameweek ${fixture.gameweek} vs ${side.teamName === fixture.home_team_name ? fixture.away_team_name : fixture.home_team_name}`,
        createdAt: fixture.scheduled_at ?? "",
        href: "#admin-team-sheets",
        actionLabel: "Open team sheets",
      });
    }
  }

  tasks.push(...(input.transferRequests ?? []).map((item): NeedsAttentionTask => ({
    id: `transfer:${item.id}`,
    category: "Player transfer request",
    subject: item.player_name ?? "Player transfer",
    context: `${item.source_team_name} → ${item.destination_team_name} · ${item.season_name}`,
    createdAt: item.requested_at,
    href: "#admin-transfers",
    actionLabel: "Review transfer",
  })));

  tasks.push(...(input.notifications ?? [])
    .filter((item) => item.status === "failed" || item.status === "unconfirmed" || item.status === "held")
    .map((item): NeedsAttentionTask => ({
      id: `notification:${item.id}`,
      category: "Notification exception",
      subject: item.recipient_name ?? item.recipient_email ?? item.recipient_phone ?? "Notification delivery",
      context: [item.event_type, item.status, item.last_error ?? item.hold_reason].filter(Boolean).join(" · "),
      createdAt: item.created_at,
      href: "#admin-communications",
      actionLabel: "Open outbox",
    })));

  tasks.push(...(input.paymentObligations ?? [])
    .filter((item) =>
      item.status === "due" ||
      item.status === "grace_period" ||
      item.status === "defaulted" ||
      item.status === "admin_review" ||
      item.status === "paid_after_cancellation" ||
      item.status === "refund_pending" ||
      item.status === "refund_failed" ||
      item.refund_status === "failed"
    )
    .map((item): NeedsAttentionTask => ({
      id: `payment:${item.obligation_id}`,
      category: item.status === "due" || item.status === "grace_period" ? "Payment due" : "Payment exception",
      subject: item.team_name,
      context: `${item.season_name} · Gameweek ${item.gameweek} vs ${item.opponent_name} · ${item.status.replaceAll("_", " ")} · £${(item.amount_pence / 100).toFixed(2)}${item.refund_status ? ` · refund ${item.refund_status}` : ""}`,
      createdAt: item.deadline_at,
      href: "/finance",
      actionLabel: "Review payment",
    })));

  tasks.sort((a, b) => {
    const aTime = Date.parse(a.createdAt);
    const bTime = Date.parse(b.createdAt);
    const aValid = Number.isFinite(aTime);
    const bValid = Number.isFinite(bTime);
    if (aValid !== bValid) return aValid ? -1 : 1;
    if (aValid && bValid && aTime !== bTime) return aTime - bTime;
    return a.id.localeCompare(b.id);
  });

  return tasks.slice(0, Math.max(0, Math.floor(limit)));
}

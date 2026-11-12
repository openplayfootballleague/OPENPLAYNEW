export type NeedsAttentionTask = {
  id: string;
  category: "Player review" | "Team application" | "Membership request";
  subject: string;
  context: string;
  createdAt: string;
  href: "#admin-player-approvals" | "#admin-team-approvals" | "#admin-membership-requests";
  actionLabel: string;
};

export type NeedsAttentionInput = {
  playerReviews: ReadonlyArray<{ player_id: string; full_name: string; created_at: string }>;
  teamApplications: ReadonlyArray<{ season_team_id: string; team_name: string; season_name: string; created_at: string }>;
  membershipRequests: ReadonlyArray<{ membership_id: string; team_name: string; player_name: string; created_at: string }>;
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

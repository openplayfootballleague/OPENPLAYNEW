import { describe, expect, it } from "vitest";
import { buildNeedsAttentionTasks } from "./needs-attention";

describe("buildNeedsAttentionTasks", () => {
  it("combines actionable approval queues and links to the correct workspace", () => {
    const tasks = buildNeedsAttentionTasks({
      playerReviews: [{ player_id: "p1", full_name: "Alex Player", created_at: "2026-11-10T10:00:00Z" }],
      teamApplications: [{ season_team_id: "t1", team_name: "Northside FC", season_name: "Season 2", created_at: "2026-11-09T10:00:00Z" }],
      membershipRequests: [{ membership_id: "m1", team_name: "Town FC", player_name: "Sam Player", created_at: "2026-11-11T10:00:00Z" }],
    });

    expect(tasks.map((task) => task.category)).toEqual([
      "Team application",
      "Player review",
      "Membership request",
    ]);
    expect(tasks[0]).toMatchObject({
      subject: "Northside FC",
      context: "Season 2",
      href: "#admin-team-approvals",
      actionLabel: "Review team",
    });
    expect(tasks[1].href).toBe("#admin-player-approvals");
    expect(tasks[2].href).toBe("#admin-membership-requests");
  });

  it("shows the oldest dated requests first and places undated items last", () => {
    const tasks = buildNeedsAttentionTasks({
      playerReviews: [
        { player_id: "later", full_name: "Later", created_at: "2026-11-11T10:00:00Z" },
        { player_id: "unknown", full_name: "Unknown date", created_at: "not-a-date" },
        { player_id: "earlier", full_name: "Earlier", created_at: "2026-11-08T10:00:00Z" },
      ],
      teamApplications: [],
      membershipRequests: [],
    });

    expect(tasks.map((task) => task.id)).toEqual(["player:earlier", "player:later", "player:unknown"]);
  });

  it("limits the number of displayed items and handles empty queues", () => {
    const input = {
      playerReviews: Array.from({ length: 15 }, (_, index) => ({
        player_id: String(index),
        full_name: `Player ${index}`,
        created_at: `2026-11-${String(index + 1).padStart(2, "0")}T10:00:00Z`,
      })),
      teamApplications: [],
      membershipRequests: [],
    };

    expect(buildNeedsAttentionTasks(input, 5)).toHaveLength(5);
    expect(buildNeedsAttentionTasks(input, 0)).toEqual([]);
    expect(buildNeedsAttentionTasks({ playerReviews: [], teamApplications: [], membershipRequests: [] })).toEqual([]);
  });
});

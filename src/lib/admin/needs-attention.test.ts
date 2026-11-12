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

  it("flags each missing side of an active fixture without duplicating submitted sheets", () => {
    const tasks = buildNeedsAttentionTasks({
      playerReviews: [],
      teamApplications: [],
      membershipRequests: [],
      fixtures: [{
        id: "fixture-1",
        season_name: "Season 2",
        gameweek: 4,
        scheduled_at: "2026-11-14T19:00:00Z",
        status: "scheduled",
        home_team_id: "home",
        away_team_id: "away",
        home_team_name: "Northside FC",
        away_team_name: "Town FC",
      }],
      submittedSheets: [{ fixture_id: "fixture-1", season_team_id: "home" }],
    });

    expect(tasks).toHaveLength(1);
    expect(tasks[0]).toMatchObject({
      id: "sheet:fixture-1:away",
      category: "Missing team sheet",
      subject: "Town FC",
      href: "#admin-team-sheets",
      actionLabel: "Open team sheets",
    });
  });

  it("includes pending player transfers with their direct review destination", () => {
    const tasks = buildNeedsAttentionTasks({
      playerReviews: [],
      teamApplications: [],
      membershipRequests: [],
      transferRequests: [{
        id: "transfer-1",
        player_name: "Jamie Player",
        source_team_name: "Northside FC",
        destination_team_name: "Town FC",
        season_name: "Season 2",
        requested_at: "2026-11-10T10:00:00Z",
      }],
    });

    expect(tasks[0]).toMatchObject({
      id: "transfer:transfer-1",
      category: "Player transfer request",
      subject: "Jamie Player",
      context: "Northside FC → Town FC · Season 2",
      href: "#admin-transfers",
      actionLabel: "Review transfer",
    });
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

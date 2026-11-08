import { describe, expect, it } from "vitest";
import { getTeamRequestDisplay, type TeamRequestStatus } from "./team-request-status";

const base: TeamRequestStatus = {
  membership_id: "m-1",
  season_team_id: "team-1",
  season_id: "season-1",
  team_name: "North Devon FC",
  season_name: "Season 1",
  team_registration_status: "approved",
  membership_status: "pending",
  is_captain: false,
  is_transfer_request: false,
  created_at: "2026-11-08T00:00:00Z",
};

describe("getTeamRequestDisplay", () => {
  it("shows captain approval for a pending join request", () => {
    expect(getTeamRequestDisplay(base).label).toBe("Join request pending");
  });

  it("shows administrator review for a pending team application", () => {
    expect(getTeamRequestDisplay({ ...base, team_registration_status: "pending" }).label).toBe("Team application pending");
  });

  it("shows an approved captain appointment", () => {
    expect(getTeamRequestDisplay({ ...base, membership_status: "active", is_captain: true }).label).toBe("Captain access active");
  });

  it("shows ordinary active membership", () => {
    expect(getTeamRequestDisplay({ ...base, membership_status: "active" }).label).toBe("Team membership active");
  });

  it("distinguishes rejected membership from rejected team registration", () => {
    expect(getTeamRequestDisplay({ ...base, membership_status: "rejected" }).label).toBe("Join request declined");
    expect(getTeamRequestDisplay({ ...base, team_registration_status: "rejected" }).label).toBe("Team application declined");
  });

  it("shows suspended memberships as restricted", () => {
    expect(getTeamRequestDisplay({ ...base, membership_status: "suspended" }).label).toBe("Membership suspended");
  });

  it("identifies transfer requests separately", () => {
    expect(getTeamRequestDisplay({ ...base, is_transfer_request: true }).label).toBe("Transfer awaiting approval");
  });
});

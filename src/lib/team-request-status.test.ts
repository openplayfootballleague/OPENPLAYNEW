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
  future_approved_at: null,
  activation_after_season_id: null,
  activation_after_season_name: null,
  future_activated_at: null,
  future_conflict_reason: null,
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

  it("explains when an approved future membership will activate", () => {
    const display = getTeamRequestDisplay({
      ...base,
      future_approved_at: "2026-11-12T00:00:00Z",
      activation_after_season_id: "previous-season",
      activation_after_season_name: "Season 1",
    });
    expect(display.label).toBe("Approved future membership");
    expect(display.description).toContain("Season 1");
  });

  it("keeps future captaincy distinct from active captain permissions", () => {
    const display = getTeamRequestDisplay({
      ...base,
      is_captain: true,
      future_approved_at: "2026-11-12T00:00:00Z",
      activation_after_season_id: "previous-season",
      activation_after_season_name: "Season 1",
    });
    expect(display.label).toBe("Future captaincy approved");
    expect(display.description).toContain("Captain access begins");
  });

  it("surfaces a blocked future membership conflict", () => {
    const display = getTeamRequestDisplay({
      ...base,
      future_approved_at: "2026-11-12T00:00:00Z",
      activation_after_season_id: "previous-season",
      future_conflict_reason: "Leave your other club first.",
    });
    expect(display.label).toBe("Membership conflict");
    expect(display.description).toContain("Leave your other club first.");
  });

  it("returns activated future memberships to the normal active state", () => {
    expect(getTeamRequestDisplay({
      ...base,
      membership_status: "active",
      future_approved_at: "2026-11-12T00:00:00Z",
      activation_after_season_id: "previous-season",
      future_activated_at: "2026-11-12T00:30:00Z",
    }).label).toBe("Team membership active");
  });

  it("identifies transfer requests separately", () => {
    expect(getTeamRequestDisplay({ ...base, is_transfer_request: true }).label).toBe("Transfer awaiting approval");
  });
});

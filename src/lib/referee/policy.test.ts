import { describe, expect, it } from "vitest";
import {
  assessTeamPayment,
  calculateNextTeamPaymentPence,
  calculateRefereeAllocation,
  getDisciplinaryFinePence,
  getIndividualStrikeDelta,
  getRefereeMilestone,
  isPlayerInactiveForStrikes,
  renumberUnplayedGameweeks,
  shouldRefundCompliantWithdrawal,
} from "./policy";

describe("Open Play Phase 1 finance and discipline policy", () => {
  it("uses the fixed competition-wide disciplinary prices", () => {
    expect(getDisciplinaryFinePence("yellow")).toBe(500);
    expect(getDisciplinaryFinePence("second_yellow_red")).toBe(1500);
    expect(getDisciplinaryFinePence("straight_red")).toBe(3000);
  });

  it("only gives an individual strike for a registered player's straight red", () => {
    expect(getIndividualStrikeDelta("registered_player", "straight_red")).toBe(1);
    expect(getIndividualStrikeDelta("registered_player", "second_yellow_red")).toBe(0);
    expect(getIndividualStrikeDelta("supporter", "straight_red")).toBe(0);
    expect(getIndividualStrikeDelta("bench", "straight_red")).toBe(0);
    expect(isPlayerInactiveForStrikes(2, 1)).toBe(true);
    expect(isPlayerInactiveForStrikes(2, 0)).toBe(false);
  });

  it("adds the outstanding fines to one team's season fee", () => {
    expect(calculateNextTeamPaymentPence(3500, 3500)).toBe(7000);
    expect(calculateNextTeamPaymentPence(4200, 0)).toBe(4200);
  });

  it("applies the 24-hour deadline and 12-hour grace period", () => {
    const deadlineAt = "2026-11-10T12:00:00.000Z";
    expect(assessTeamPayment({ feePence: 3500, deadlineAt, assessedAt: "2026-11-10T11:59:59Z" }).state).toBe("on_time");
    expect(assessTeamPayment({ feePence: 3500, deadlineAt, assessedAt: "2026-11-10T18:00:00Z" }).state).toBe("grace_period");
    const paidLate = assessTeamPayment({ feePence: 3500, deadlineAt, assessedAt: "2026-11-10T13:00:00Z", paidAt: "2026-11-10T13:00:00Z" });
    expect(paidLate).toMatchObject({ state: "late_paid", strike: true, fixtureCancelled: false });
    const paidAfterGrace = assessTeamPayment({
      feePence: 3500,
      deadlineAt,
      assessedAt: "2026-11-11T00:01:00Z",
      paidAt: "2026-11-11T00:01:00Z",
      opponentHasPaid: true,
    });
    expect(paidAfterGrace).toMatchObject({
      state: "defaulted",
      strike: true,
      fixtureCancelled: true,
      teamFeeLiabilityPence: 0,
      opponentRefundDue: true,
    });
  });

  it("cancels an unpaid fixture after grace but leaves only that team's fee liable", () => {
    expect(assessTeamPayment({
      feePence: 3500,
      deadlineAt: "2026-11-10T12:00:00Z",
      assessedAt: "2026-11-11T00:00:01Z",
      opponentHasPaid: true,
    })).toMatchObject({
      state: "defaulted",
      strike: true,
      fixtureCancelled: true,
      teamFeeLiabilityPence: 3500,
      opponentRefundDue: true,
    });
  });

  it("refunds compliant withdrawals only", () => {
    expect(shouldRefundCompliantWithdrawal(true)).toBe(true);
    expect(shouldRefundCompliantWithdrawal(false)).toBe(false);
  });

  it("renumbers unplayed rounds chronologically without rewriting completed rounds", () => {
    const result = renumberUnplayedGameweeks([
      { id: "f1", gameweekId: "round-1", scheduledAt: "2026-01-01T18:00:00Z", gameweekNumber: 1, completed: true },
      { id: "f2", gameweekId: "round-2", scheduledAt: "2026-01-08T18:00:00Z", gameweekNumber: 2, completed: false },
      { id: "f3", gameweekId: "round-3", scheduledAt: "2026-01-15T18:00:00Z", gameweekNumber: 3, completed: false },
      { id: "f4", gameweekId: "round-2", scheduledAt: "2026-01-22T18:00:00Z", gameweekNumber: 2, completed: false },
    ]);
    expect(result.get("round-2")).toBe(2);
    expect(result.get("round-3")).toBe(3);
    expect(result.has("round-1")).toBe(false);
  });

  it("guarantees £20 net and credits the actual net amount", () => {
    expect(calculateRefereeAllocation(25)).toMatchObject({
      grossAllocationPence: 2200,
      deductionsPence: 25,
      refereeNetPence: 2175,
      openPlayTopUpPence: 0,
    });
    expect(calculateRefereeAllocation(250)).toMatchObject({
      refereeNetPence: 2000,
      openPlayTopUpPence: 50,
    });
  });

  it("calculates lifetime referee milestones every 50 approved games", () => {
    expect(getRefereeMilestone(125)).toMatchObject({
      completedMilestones: 2,
      nextMilestoneGames: 150,
      progressGames: 25,
      remainingGames: 25,
      rewardDuePence: 10000,
    });
    expect(getRefereeMilestone(500).nextMilestoneGames).toBeNull();
    expect(getRefereeMilestone(550)).toMatchObject({
      completedMilestones: 10,
      nextMilestoneGames: null,
      rewardDuePence: 50000,
    });
  });
});


describe("Open Play referee report workflow", () => {
  it("closes initial referee reports 24 hours after the latest fixture", async () => {
    const { assessRefereeReportSubmission } = await import("./policy");
    const latestFixtureAt = "2026-11-10T20:00:00.000Z";
    expect(assessRefereeReportSubmission({
      actor: "assigned_referee",
      status: "not_started",
      latestFixtureAt,
      assessedAt: "2026-11-11T20:00:00.000Z",
    })).toMatchObject({ allowed: true, reason: "within_deadline" });
    expect(assessRefereeReportSubmission({
      actor: "assigned_referee",
      status: "submitted",
      latestFixtureAt,
      assessedAt: "2026-11-11T20:00:00.001Z",
    })).toMatchObject({ allowed: false, reason: "deadline_passed" });
  });

  it("allows admin takeover and rejected-report resubmission after the deadline", async () => {
    const { assessRefereeReportSubmission } = await import("./policy");
    const common = {
      latestFixtureAt: "2026-11-10T20:00:00.000Z",
      assessedAt: "2026-11-15T20:00:00.000Z",
    };
    expect(assessRefereeReportSubmission({
      ...common,
      actor: "admin",
      status: "not_started",
    })).toMatchObject({ allowed: true, reason: "admin_takeover" });
    expect(assessRefereeReportSubmission({
      ...common,
      actor: "assigned_referee",
      status: "rejected",
    })).toMatchObject({ allowed: true, reason: "rejected_resubmission" });
  });

  it("prevents referee resubmission from changing an approved report", async () => {
    const { assessRefereeReportSubmission } = await import("./policy");
    expect(assessRefereeReportSubmission({
      actor: "assigned_referee",
      status: "approved",
      latestFixtureAt: "2026-11-10T20:00:00.000Z",
      assessedAt: "2026-11-10T21:00:00.000Z",
    })).toMatchObject({ allowed: false, reason: "already_approved" });
  });

  it("assigns the agreed lifetime milestone titles and exactly five referee tabs", async () => {
    const { getRefereeMilestoneTitle, REFEREE_NAVIGATION_TABS } = await import("./policy");
    expect(getRefereeMilestoneTitle(49)).toBeNull();
    expect(getRefereeMilestoneTitle(50)).toBe("Bronze Official");
    expect(getRefereeMilestoneTitle(500)).toBe("Open Play Ambassador");
    expect(REFEREE_NAVIGATION_TABS).toEqual(["Home", "Match Centre", "Teams", "Matchday", "More"]);
  });
});

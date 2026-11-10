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
  });
});

export type DisciplinaryRecipient = "registered_player" | "bench" | "supporter";
export type CardOutcome = "yellow" | "second_yellow_red" | "straight_red";

export const DISCIPLINARY_FINE_PENCE: Readonly<Record<CardOutcome, number>> = {
  yellow: 500,
  second_yellow_red: 1500,
  straight_red: 3000,
};

export const REFEREE_GROSS_ALLOCATION_PENCE = 2200;
export const REFEREE_MINIMUM_NET_PENCE = 2000;
export const REFEREE_MILESTONE_INTERVAL = 50;
export const REFEREE_MILESTONE_REWARD_PENCE = 5000;

export function getDisciplinaryFinePence(outcome: CardOutcome): number {
  return DISCIPLINARY_FINE_PENCE[outcome];
}

/**
 * Strikes are individual-player consequences, not team consequences.
 * Only a straight red issued to an identified registered player counts.
 * Bench/supporter incidents remain team-liable but do not invent an account strike.
 */
export function getIndividualStrikeDelta(
  recipient: DisciplinaryRecipient,
  outcome: CardOutcome,
): number {
  return recipient === "registered_player" && outcome === "straight_red" ? 1 : 0;
}

export function isPlayerInactiveForStrikes(existingStrikes: number, newStrikes = 0): boolean {
  if (!Number.isInteger(existingStrikes) || !Number.isInteger(newStrikes) || existingStrikes < 0 || newStrikes < 0) {
    throw new RangeError("Strike counts must be non-negative integers");
  }
  return existingStrikes + newStrikes >= 3;
}

export function calculateNextTeamPaymentPence(
  seasonMatchFeePence: number,
  outstandingFinePence: number,
): number {
  for (const amount of [seasonMatchFeePence, outstandingFinePence]) {
    if (!Number.isSafeInteger(amount) || amount < 0) {
      throw new RangeError("Payment amounts must be non-negative integer pence");
    }
  }
  return seasonMatchFeePence + outstandingFinePence;
}

export type TeamPaymentState =
  | "on_time"
  | "grace_period"
  | "late_paid"
  | "defaulted";

export interface TeamPaymentAssessment {
  state: TeamPaymentState;
  strike: boolean;
  fixtureCancelled: boolean;
  teamFeeLiabilityPence: number;
  opponentRefundDue: boolean;
}

const GRACE_PERIOD_MS = 12 * 60 * 60 * 1000;

export function assessTeamPayment(input: {
  feePence: number;
  deadlineAt: string | Date;
  assessedAt: string | Date;
  paidAt?: string | Date | null;
  opponentHasPaid?: boolean;
}): TeamPaymentAssessment {
  if (!Number.isSafeInteger(input.feePence) || input.feePence < 0) {
    throw new RangeError("Fee must be non-negative integer pence");
  }
  const deadline = new Date(input.deadlineAt).getTime();
  const assessed = new Date(input.assessedAt).getTime();
  const paid = input.paidAt == null ? null : new Date(input.paidAt).getTime();
  if (![deadline, assessed, ...(paid === null ? [] : [paid])].every(Number.isFinite)) {
    throw new RangeError("Payment dates must be valid timestamps");
  }

  if (paid !== null) {
    if (paid <= deadline) {
      return { state: "on_time", strike: false, fixtureCancelled: false, teamFeeLiabilityPence: 0, opponentRefundDue: false };
    }
    if (paid < deadline + GRACE_PERIOD_MS) {
      return { state: "late_paid", strike: true, fixtureCancelled: false, teamFeeLiabilityPence: 0, opponentRefundDue: false };
    }
    // Payment after the grace period does not reinstate a cancelled fixture.
    return {
      state: "defaulted",
      strike: true,
      fixtureCancelled: true,
      teamFeeLiabilityPence: 0,
      opponentRefundDue: input.opponentHasPaid === true,
    };
  }

  if (assessed <= deadline) {
    return { state: "on_time", strike: false, fixtureCancelled: false, teamFeeLiabilityPence: 0, opponentRefundDue: false };
  }

  if (assessed < deadline + GRACE_PERIOD_MS) {
    return { state: "grace_period", strike: false, fixtureCancelled: false, teamFeeLiabilityPence: 0, opponentRefundDue: false };
  }

  return {
    state: "defaulted",
    strike: true,
    fixtureCancelled: true,
    teamFeeLiabilityPence: input.feePence,
    opponentRefundDue: input.opponentHasPaid === true,
  };
}

export function shouldRefundCompliantWithdrawal(followsWithdrawalPolicy: boolean): boolean {
  return followsWithdrawalPolicy;
}

export interface GameweekFixture {
  id: string;
  gameweekId: string;
  scheduledAt: string;
  gameweekNumber: number;
  completed: boolean;
}

/**
 * Re-number uncompleted gameweeks in chronological order after a postponement.
 * Stable gameweek IDs are retained; only the display number changes.
 * Completed rounds are not rewritten.
 */
export function renumberUnplayedGameweeks(
  fixtures: readonly GameweekFixture[],
): ReadonlyMap<string, number> {
  const rounds = new Map<string, number>();
  let lastCompletedNumber = 0;
  for (const fixture of fixtures) {
    if (fixture.completed) {
      lastCompletedNumber = Math.max(lastCompletedNumber, fixture.gameweekNumber);
      continue;
    }
    const timestamp = new Date(fixture.scheduledAt).getTime();
    if (!Number.isFinite(timestamp)) throw new RangeError("Fixture date must be valid");
    const current = rounds.get(fixture.gameweekId);
    if (current === undefined || timestamp < current) rounds.set(fixture.gameweekId, timestamp);
  }
  const ordered = [...rounds.entries()].sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]));
  return new Map(ordered.map(([gameweekId], index) => [gameweekId, lastCompletedNumber + index + 1]));
}

export interface RefereeAllocation {
  grossAllocationPence: number;
  deductionsPence: number;
  refereeNetPence: number;
  openPlayTopUpPence: number;
}

export function calculateRefereeAllocation(deductionsPence: number): RefereeAllocation {
  if (!Number.isSafeInteger(deductionsPence) || deductionsPence < 0) {
    throw new RangeError("Deductions must be non-negative integer pence");
  }
  const afterDeductions = REFEREE_GROSS_ALLOCATION_PENCE - deductionsPence;
  const refereeNetPence = Math.max(REFEREE_MINIMUM_NET_PENCE, afterDeductions);
  return {
    grossAllocationPence: REFEREE_GROSS_ALLOCATION_PENCE,
    deductionsPence,
    refereeNetPence,
    openPlayTopUpPence: Math.max(0, refereeNetPence - afterDeductions),
  };
}

export function getRefereeMilestone(approvedGames: number): {
  completedMilestones: number;
  nextMilestoneGames: number | null;
  progressGames: number;
  remainingGames: number;
  rewardDuePence: number;
} {
  if (!Number.isSafeInteger(approvedGames) || approvedGames < 0) {
    throw new RangeError("Approved game count must be a non-negative integer");
  }
  const completedMilestones = Math.min(10, Math.floor(approvedGames / REFEREE_MILESTONE_INTERVAL));
  const nextMilestoneGames = completedMilestones >= 10 ? null : (completedMilestones + 1) * REFEREE_MILESTONE_INTERVAL;
  const progressGames = nextMilestoneGames === null ? 0 : approvedGames % REFEREE_MILESTONE_INTERVAL;
  return {
    completedMilestones,
    nextMilestoneGames,
    progressGames,
    remainingGames: nextMilestoneGames === null ? 0 : nextMilestoneGames - approvedGames,
    rewardDuePence: completedMilestones * REFEREE_MILESTONE_REWARD_PENCE,
  };
}


export type RefereeReportStatus = "not_started" | "submitted" | "rejected" | "approved";
export type ReportSubmissionActor = "assigned_referee" | "admin";

export interface ReportSubmissionAssessment {
  allowed: boolean;
  reason: "within_deadline" | "admin_takeover" | "rejected_resubmission" | "deadline_passed" | "already_approved";
}

/**
 * Initial referee submissions close 24 hours after the latest fixture in the
 * gameweek. Admin takeover remains available after the deadline. A rejected
 * report can be corrected and resubmitted; an approved report is immutable
 * through this referee submission path.
 */
export function assessRefereeReportSubmission(input: {
  actor: ReportSubmissionActor;
  status: RefereeReportStatus;
  latestFixtureAt: string | Date;
  assessedAt: string | Date;
}): ReportSubmissionAssessment {
  const latestFixture = new Date(input.latestFixtureAt).getTime();
  const assessedAt = new Date(input.assessedAt).getTime();
  if (!Number.isFinite(latestFixture) || !Number.isFinite(assessedAt)) {
    throw new RangeError("Report deadline dates must be valid timestamps");
  }
  if (input.status === "approved") {
    return { allowed: false, reason: "already_approved" };
  }
  if (input.actor === "admin") {
    return { allowed: true, reason: "admin_takeover" };
  }
  if (input.status === "rejected") {
    return { allowed: true, reason: "rejected_resubmission" };
  }
  const deadline = latestFixture + 24 * 60 * 60 * 1000;
  return assessedAt <= deadline
    ? { allowed: true, reason: "within_deadline" }
    : { allowed: false, reason: "deadline_passed" };
}

export const REFEREE_MILESTONE_TITLES = [
  "Bronze Official",
  "Silver Official",
  "Gold Official",
  "Elite Official",
  "Premier Official",
  "Platinum Official",
  "Diamond Official",
  "Master Official",
  "Legend Official",
  "Open Play Ambassador",
] as const;

export function getRefereeMilestoneTitle(approvedGames: number): string | null {
  if (!Number.isSafeInteger(approvedGames) || approvedGames < 0) {
    throw new RangeError("Approved game count must be a non-negative integer");
  }
  const milestoneIndex = Math.floor(approvedGames / REFEREE_MILESTONE_INTERVAL) - 1;
  return milestoneIndex < 0 ? null : REFEREE_MILESTONE_TITLES[Math.min(milestoneIndex, REFEREE_MILESTONE_TITLES.length - 1)];
}

export const REFEREE_NAVIGATION_TABS = [
  "Home",
  "Match Centre",
  "Teams",
  "Matchday",
  "More",
] as const;


/** Weekly team match fees fall due exactly 24 hours before local fixture kickoff. */
export function getTeamPaymentDeadlineAt(kickoffAt: string | Date): Date {
  const kickoff = new Date(kickoffAt).getTime();
  if (!Number.isFinite(kickoff)) throw new RangeError("Fixture kickoff must be a valid timestamp");
  return new Date(kickoff - 24 * 60 * 60 * 1000);
}

/**
 * Returns the remaining refundable amount in integer pence. The caller must
 * still create the refund against the original Stripe payment with an
 * idempotency key and persist the refund ledger entry transactionally.
 */
export function calculateRefundDuePence(amountPaidPence: number, alreadyRefundedPence = 0): number {
  for (const amount of [amountPaidPence, alreadyRefundedPence]) {
    if (!Number.isSafeInteger(amount) || amount < 0) {
      throw new RangeError("Refund amounts must be non-negative integer pence");
    }
  }
  if (alreadyRefundedPence > amountPaidPence) {
    throw new RangeError("Refunded amount cannot exceed the original payment");
  }
  return amountPaidPence - alreadyRefundedPence;
}

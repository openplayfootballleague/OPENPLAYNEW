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
  const completedMilestones = Math.floor(approvedGames / REFEREE_MILESTONE_INTERVAL);
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

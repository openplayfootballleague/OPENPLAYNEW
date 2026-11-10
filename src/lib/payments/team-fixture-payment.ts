export const TEAM_FIXTURE_PAYMENT_DEADLINE_HOURS = 24;
export const TEAM_FIXTURE_PAYMENT_GRACE_HOURS = 12;
export const TEAM_FIXTURE_PAYMENT_FINAL_HOURS =
  TEAM_FIXTURE_PAYMENT_DEADLINE_HOURS + TEAM_FIXTURE_PAYMENT_GRACE_HOURS;

export type TeamFixturePaymentState =
  | "paid_on_time"
  | "paid_late"
  | "paid_after_deadline"
  | "due"
  | "grace_period"
  | "admin_review"
  | "cancellation_due";

export type TeamFixturePaymentAssessment = {
  state: TeamFixturePaymentState;
  deadlineAt: string;
  graceEndsAt: string;
  strikeCount: 0 | 1;
  fixtureCancellationDue: boolean;
  teamFeeRemainsLiable: boolean;
};

function parseTimestamp(value: string, label: string): number {
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) throw new RangeError(`Invalid ${label} timestamp.`);
  return timestamp;
}

/**
 * Assess one team's own fixture payment against the scheduled kick-off.
 * The caller must supply authoritative server/database timestamps.
 * This function is deterministic and has no side effects.
 */
export function assessTeamFixturePayment(input: {
  kickoffAt: string;
  assessedAt: string;
  paidAt?: string | null;
  adminReviewHold?: boolean;
}): TeamFixturePaymentAssessment {
  const kickoff = parseTimestamp(input.kickoffAt, "kick-off");
  const assessed = parseTimestamp(input.assessedAt, "assessment");
  const paid = input.paidAt ? parseTimestamp(input.paidAt, "payment") : null;
  const deadline = kickoff - TEAM_FIXTURE_PAYMENT_DEADLINE_HOURS * 60 * 60 * 1000;
  const graceEnds = deadline + TEAM_FIXTURE_PAYMENT_GRACE_HOURS * 60 * 60 * 1000;
  const deadlineAt = new Date(deadline).toISOString();
  const graceEndsAt = new Date(graceEnds).toISOString();

  if (paid !== null) {
    if (paid <= deadline) {
      return { state: "paid_on_time", deadlineAt, graceEndsAt, strikeCount: 0, fixtureCancellationDue: false, teamFeeRemainsLiable: false };
    }
    if (paid <= graceEnds) {
      return { state: "paid_late", deadlineAt, graceEndsAt, strikeCount: 1, fixtureCancellationDue: false, teamFeeRemainsLiable: false };
    }
    return { state: "paid_after_deadline", deadlineAt, graceEndsAt, strikeCount: 1, fixtureCancellationDue: true, teamFeeRemainsLiable: false };
  }

  if (assessed <= deadline) {
    return { state: "due", deadlineAt, graceEndsAt, strikeCount: 0, fixtureCancellationDue: false, teamFeeRemainsLiable: true };
  }
  if (assessed <= graceEnds) {
    return { state: "grace_period", deadlineAt, graceEndsAt, strikeCount: 0, fixtureCancellationDue: false, teamFeeRemainsLiable: true };
  }
  if (input.adminReviewHold) {
    return { state: "admin_review", deadlineAt, graceEndsAt, strikeCount: 0, fixtureCancellationDue: false, teamFeeRemainsLiable: true };
  }
  return { state: "cancellation_due", deadlineAt, graceEndsAt, strikeCount: 1, fixtureCancellationDue: true, teamFeeRemainsLiable: true };
}

export function calculateTeamFixtureAmountDue(input: {
  weeklyFeePence: number;
  approvedFineAmountsPence?: number[];
  otherApprovedChargesPence?: number[];
}): number {
  const amounts = [
    input.weeklyFeePence,
    ...(input.approvedFineAmountsPence ?? []),
    ...(input.otherApprovedChargesPence ?? []),
  ];
  if (amounts.some((amount) => !Number.isSafeInteger(amount) || amount < 0)) {
    throw new RangeError("Team charges must be non-negative integer amounts in pence.");
  }
  const total = amounts.reduce((sum, amount) => sum + amount, 0);
  if (!Number.isSafeInteger(total)) throw new RangeError("Total team charges exceed the safe integer range.");
  return total;
}

/** The opposing team's own payment is refundable when the other team defaults. */
export function opposingTeamRefundDue(input: {
  fixtureCancellationReason: "opponent_payment_default" | "weather_postponement" | "other";
  opponentPaidAmountPence: number;
}): number {
  if (!Number.isSafeInteger(input.opponentPaidAmountPence) || input.opponentPaidAmountPence < 0) {
    throw new RangeError("Refund amount must be a non-negative integer number of pence.");
  }
  return input.fixtureCancellationReason === "opponent_payment_default" ||
    input.fixtureCancellationReason === "weather_postponement"
    ? input.opponentPaidAmountPence
    : 0;
}

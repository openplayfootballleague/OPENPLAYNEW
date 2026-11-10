export const REFEREE_GROSS_ALLOCATION_PENCE = 2_200;
export const REFEREE_MINIMUM_NET_PENCE = 2_000;
export const REFEREE_INCLUDED_COST_ALLOWANCE_PENCE = 200;

export type RefereePaymentCalculation = {
  grossAllocationPence: number;
  actualDeductionsPence: number;
  includedCostAllowancePence: number;
  platformTopUpPence: number;
  transferAmountPence: number;
  guaranteedNetPence: number;
  actualNetPence: number;
};

export type RefereePaymentStatus =
  | "earned"
  | "pending_transfer"
  | "transfer_failed"
  | "transferred"
  | "payout_pending"
  | "paid_out"
  | "adjustment_pending"
  | "reversed";

export type RefereePaymentStage = "earned" | "transfer" | "payout" | "adjustment";

export function calculateRefereePayment(deductionsPence: number): RefereePaymentCalculation {
  if (!Number.isSafeInteger(deductionsPence) || deductionsPence < 0) {
    throw new RangeError("Payment deductions must be a non-negative integer number of pence.");
  }

  const platformTopUpPence = Math.max(
    0,
    deductionsPence - REFEREE_INCLUDED_COST_ALLOWANCE_PENCE,
  );
  const transferAmountPence = REFEREE_GROSS_ALLOCATION_PENCE + platformTopUpPence;
  const actualNetPence = transferAmountPence - deductionsPence;

  if (actualNetPence < REFEREE_MINIMUM_NET_PENCE) {
    throw new Error("The referee minimum net guarantee could not be satisfied.");
  }

  return {
    grossAllocationPence: REFEREE_GROSS_ALLOCATION_PENCE,
    actualDeductionsPence: deductionsPence,
    includedCostAllowancePence: REFEREE_INCLUDED_COST_ALLOWANCE_PENCE,
    platformTopUpPence,
    transferAmountPence,
    guaranteedNetPence: REFEREE_MINIMUM_NET_PENCE,
    actualNetPence,
  };
}

/**
 * A stable, non-PII idempotency key: one entitlement per approved report.
 * A corrected or resubmitted version of the same report keeps the same key.
 */
export function refereeReportIdempotencyKey(reportId: string): string {
  const normalized = reportId.trim();
  if (!normalized || normalized.length > 128 || /[\r\n]/.test(normalized)) {
    throw new RangeError("A valid report identifier is required.");
  }
  return `openplay:referee-report:${normalized}:allocation:v1`;
}

const ALLOWED_TRANSITIONS: Record<RefereePaymentStatus, readonly RefereePaymentStatus[]> = {
  earned: ["pending_transfer", "adjustment_pending", "reversed"],
  pending_transfer: ["transferred", "transfer_failed", "adjustment_pending", "reversed"],
  transfer_failed: ["pending_transfer", "adjustment_pending", "reversed"],
  transferred: ["payout_pending", "paid_out", "adjustment_pending", "reversed"],
  payout_pending: ["paid_out", "adjustment_pending", "reversed"],
  paid_out: ["adjustment_pending", "reversed"],
  adjustment_pending: ["pending_transfer", "transferred", "payout_pending", "paid_out", "transfer_failed", "reversed"],
  reversed: [],
};

export function canTransitionRefereePayment(
  current: RefereePaymentStatus,
  next: RefereePaymentStatus,
): boolean {
  return ALLOWED_TRANSITIONS[current].includes(next);
}

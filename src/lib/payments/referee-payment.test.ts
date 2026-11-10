import { describe, expect, it } from "vitest";
import {
  calculateRefereePayment,
  canTransitionRefereePayment,
  refereeReportIdempotencyKey,
  type RefereePaymentStatus,
} from "./referee-payment";

describe("referee £22 allocation and £20 net guarantee", () => {
  it("retains £22 when there are no deductions", () => {
    expect(calculateRefereePayment(0)).toMatchObject({
      grossAllocationPence: 2200,
      platformTopUpPence: 0,
      transferAmountPence: 2200,
      actualNetPence: 2200,
      guaranteedNetPence: 2000,
    });
  });

  it("absorbs deductions up to the included £2 allowance", () => {
    expect(calculateRefereePayment(200)).toMatchObject({
      platformTopUpPence: 0,
      transferAmountPence: 2200,
      actualNetPence: 2000,
    });
  });

  it("does not top up when deductions are below £2", () => {
    expect(calculateRefereePayment(25)).toMatchObject({
      platformTopUpPence: 0,
      transferAmountPence: 2200,
      actualNetPence: 2175,
    });
  });

  it("makes Open Play absorb costs above £2 without reducing referee net below £20", () => {
    expect(calculateRefereePayment(250)).toMatchObject({
      grossAllocationPence: 2200,
      platformTopUpPence: 50,
      transferAmountPence: 2250,
      actualNetPence: 2000,
    });
    expect(calculateRefereePayment(475)).toMatchObject({
      platformTopUpPence: 275,
      transferAmountPence: 2475,
      actualNetPence: 2000,
    });
  });

  it("rejects negative, fractional and unsafe deductions", () => {
    expect(() => calculateRefereePayment(-1)).toThrow(RangeError);
    expect(() => calculateRefereePayment(1.5)).toThrow(RangeError);
    expect(() => calculateRefereePayment(Number.MAX_SAFE_INTEGER + 1)).toThrow(RangeError);
  });
});

describe("referee entitlement idempotency", () => {
  it("creates a stable report-level key", () => {
    expect(refereeReportIdempotencyKey("report-123")).toBe("openplay:referee-report:report-123:allocation:v1");
    expect(refereeReportIdempotencyKey(" report-123 ")).toBe(refereeReportIdempotencyKey("report-123"));
  });

  it("rejects missing or malformed report identifiers", () => {
    expect(() => refereeReportIdempotencyKey(" ")).toThrow(RangeError);
    expect(() => refereeReportIdempotencyKey("report\n123")).toThrow(RangeError);
  });

  it("uses the same key for a corrected/resubmitted version of the same report", () => {
    const original = refereeReportIdempotencyKey("fixture-report-abc");
    const corrected = refereeReportIdempotencyKey("fixture-report-abc");
    expect(corrected).toBe(original);
  });
});

describe("referee payment lifecycle", () => {
  const allowed: Array<[RefereePaymentStatus, RefereePaymentStatus]> = [
    ["earned", "pending_transfer"],
    ["pending_transfer", "transferred"],
    ["pending_transfer", "transfer_failed"],
    ["transfer_failed", "pending_transfer"],
    ["transferred", "payout_pending"],
    ["transferred", "paid_out"],
    ["payout_pending", "paid_out"],
    ["paid_out", "adjustment_pending"],
    ["adjustment_pending", "paid_out"],
    ["adjustment_pending", "reversed"],
  ];

  it.each(allowed)("allows %s → %s", (from, to) => {
    expect(canTransitionRefereePayment(from, to)).toBe(true);
  });

  it.each([
    ["earned", "paid_out"],
    ["transfer_failed", "paid_out"],
    ["paid_out", "pending_transfer"],
    ["reversed", "pending_transfer"],
  ] as Array<[RefereePaymentStatus, RefereePaymentStatus]>)("blocks unsafe %s → %s transition", (from, to) => {
    expect(canTransitionRefereePayment(from, to)).toBe(false);
  });

  it("never permits a transition out of reversed", () => {
    expect(canTransitionRefereePayment("reversed", "earned")).toBe(false);
  });
});

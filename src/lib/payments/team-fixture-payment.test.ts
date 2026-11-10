import { describe, expect, it } from "vitest";
import {
  assessTeamFixturePayment,
  calculateTeamFixtureAmountDue,
  opposingTeamRefundDue,
} from "./team-fixture-payment";

const kickoffAt = "2026-11-20T20:00:00.000Z";
const deadline = "2026-11-19T20:00:00.000Z";
const graceEnds = "2026-11-20T08:00:00.000Z";

describe("team fixture payment deadline and 12-hour grace period", () => {
  it("calculates the 24-hour deadline and 12-hour grace end from kick-off", () => {
    expect(assessTeamFixturePayment({ kickoffAt, assessedAt: "2026-11-19T19:59:59.999Z" }))
      .toMatchObject({ state: "due", deadlineAt: deadline, graceEndsAt: graceEnds, strikeCount: 0, fixtureCancellationDue: false });
  });

  it("accepts payment exactly at the 24-hour deadline without a strike", () => {
    expect(assessTeamFixturePayment({ kickoffAt, assessedAt: deadline, paidAt: deadline }))
      .toMatchObject({ state: "paid_on_time", strikeCount: 0, fixtureCancellationDue: false, teamFeeRemainsLiable: false });
  });

  it("accepts payment within the additional 12 hours with one strike", () => {
    expect(assessTeamFixturePayment({ kickoffAt, assessedAt: "2026-11-20T02:00:00Z", paidAt: "2026-11-20T02:00:00Z" }))
      .toMatchObject({ state: "paid_late", strikeCount: 1, fixtureCancellationDue: false });
  });

  it("treats payment exactly at the 36-hour final deadline as within grace", () => {
    expect(assessTeamFixturePayment({ kickoffAt, assessedAt: graceEnds, paidAt: graceEnds }))
      .toMatchObject({ state: "paid_late", strikeCount: 1, fixtureCancellationDue: false });
  });

  it("marks an unpaid team for cancellation after the final deadline", () => {
    expect(assessTeamFixturePayment({ kickoffAt, assessedAt: "2026-11-20T08:00:00.001Z" }))
      .toMatchObject({ state: "cancellation_due", strikeCount: 1, fixtureCancellationDue: true, teamFeeRemainsLiable: true });
  });

  it("routes an overdue case to admin review when a hold is present", () => {
    expect(assessTeamFixturePayment({ kickoffAt, assessedAt: "2026-11-20T09:00:00Z", adminReviewHold: true }))
      .toMatchObject({ state: "admin_review", strikeCount: 0, fixtureCancellationDue: false, teamFeeRemainsLiable: true });
  });

  it("does not treat a payment after cancellation as restoring the fixture", () => {
    expect(assessTeamFixturePayment({ kickoffAt, assessedAt: "2026-11-20T10:00:00Z", paidAt: "2026-11-20T09:00:00Z" }))
      .toMatchObject({ state: "paid_after_deadline", strikeCount: 1, fixtureCancellationDue: true });
  });

  it("rejects invalid timestamps", () => {
    expect(() => assessTeamFixturePayment({ kickoffAt: "not-a-date", assessedAt: deadline })).toThrow(RangeError);
  });
});

describe("team-level fee and approved fine totals", () => {
  it("adds the season weekly fee to approved fines and charges only this team", () => {
    expect(calculateTeamFixtureAmountDue({
      weeklyFeePence: 3500,
      approvedFineAmountsPence: [500, 1500],
      otherApprovedChargesPence: [250],
    })).toBe(5750);
  });

  it("does not add unapproved fines because only approved charges are supplied", () => {
    expect(calculateTeamFixtureAmountDue({ weeklyFeePence: 3500, approvedFineAmountsPence: [] })).toBe(3500);
  });

  it("rejects negative, fractional and unsafe money values", () => {
    expect(() => calculateTeamFixtureAmountDue({ weeklyFeePence: -1 })).toThrow(RangeError);
    expect(() => calculateTeamFixtureAmountDue({ weeklyFeePence: 3500, approvedFineAmountsPence: [5.5] })).toThrow(RangeError);
    expect(() => calculateTeamFixtureAmountDue({ weeklyFeePence: Number.MAX_SAFE_INTEGER, approvedFineAmountsPence: [1] })).toThrow(RangeError);
  });
});

describe("opponent and weather refund calculation", () => {
  it("refunds the opponent's own payment when the other team defaults", () => {
    expect(opposingTeamRefundDue({ fixtureCancellationReason: "opponent_payment_default", opponentPaidAmountPence: 3500 })).toBe(3500);
  });

  it("refunds paid teams for weather postponement", () => {
    expect(opposingTeamRefundDue({ fixtureCancellationReason: "weather_postponement", opponentPaidAmountPence: 3500 })).toBe(3500);
  });

  it("does not automatically refund for other cancellation reasons", () => {
    expect(opposingTeamRefundDue({ fixtureCancellationReason: "other", opponentPaidAmountPence: 3500 })).toBe(0);
  });

  it("rejects invalid refund amounts", () => {
    expect(() => opposingTeamRefundDue({ fixtureCancellationReason: "weather_postponement", opponentPaidAmountPence: -1 })).toThrow(RangeError);
  });
});

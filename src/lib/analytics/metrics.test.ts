import { describe, expect, it } from "vitest";
import { calculatePlayerRetention, calculateTeamRetention, summarizeFinanceForAnalytics } from "./metrics";

const range = ["2026-01-01T00:00:00.000Z", "2027-01-01T00:00:00.000Z"] as const;

describe("source-aware analytics metrics", () => {
  it("separates expected income, actual receipts and refunds", () => {
    const result = summarizeFinanceForAnalytics([
      { teamId: "a", entryType: "charge", amountPence: 3500, occurredAt: "2026-02-01T10:00:00.000Z" },
      { teamId: "a", entryType: "payment", amountPence: 2000, occurredAt: "2026-02-02T10:00:00.000Z" },
      { teamId: "a", entryType: "refund", amountPence: 500, occurredAt: "2026-02-03T10:00:00.000Z" },
      { teamId: "b", entryType: "fine", amountPence: 1000, occurredAt: "2026-03-01T10:00:00.000Z" },
      { teamId: "b", entryType: "credit", amountPence: 250, occurredAt: "2026-03-02T10:00:00.000Z" },
    ], range[0], range[1]);

    expect(result.expectedIncomePence).toBe(4500);
    expect(result.netCashReceivedPence).toBe(1500);
    expect(result.outstandingPence).toBe(1750);
    expect(result.expenditurePence).toBeNull();
    expect(result.operatingProfitPence).toBeNull();
    expect(result.profitMargin).toBeNull();
    expect(result.completeness).toBe("partial");
  });

  it("excludes entries outside the half-open reporting period", () => {
    const result = summarizeFinanceForAnalytics([
      { teamId: "a", entryType: "payment", amountPence: 100, occurredAt: "2025-12-31T23:59:59.999Z" },
      { teamId: "a", entryType: "payment", amountPence: 200, occurredAt: range[0] },
      { teamId: "a", entryType: "payment", amountPence: 300, occurredAt: range[1] },
    ], range[0], range[1]);

    expect(result.paymentsPence).toBe(200);
  });

  it("does not allow one team's overpayment to offset another team's debt", () => {
    const result = summarizeFinanceForAnalytics([
      { teamId: "a", entryType: "charge", amountPence: 1000, occurredAt: range[0] },
      { teamId: "a", entryType: "payment", amountPence: 1500, occurredAt: range[0] },
      { teamId: "b", entryType: "charge", amountPence: 800, occurredAt: range[0] },
    ], range[0], range[1]);

    expect(result.outstandingPence).toBe(800);
  });

  it("returns unavailable retention when the previous cohort is empty", () => {
    expect(calculateTeamRetention([], ["team-a"])).toBeNull();
  });

  it("calculates player retention against distinct comparable-period players", () => {
    expect(calculatePlayerRetention(["p1", "p1", "p2", "p3"], ["p1", "p3", "p4"])).toBeCloseTo(2 / 3);
    expect(calculatePlayerRetention([], ["p1"])).toBeNull();
  });

  it("calculates retention against the distinct previous-season cohort", () => {
    expect(calculateTeamRetention(["a", "a", "b", "c"], ["a", "c", "d"])).toBeCloseTo(2 / 3);
  });

  it("rejects invalid date ranges and malformed finance entries", () => {
    expect(() => summarizeFinanceForAnalytics([], range[1], range[0])).toThrow(RangeError);
    expect(() => summarizeFinanceForAnalytics([
      { teamId: "a", entryType: "payment", amountPence: 0, occurredAt: range[0] },
    ], range[0], range[1])).toThrow(RangeError);
  });
  it("calculates outstanding balances as of period end using charges from earlier periods", () => {
    const result = summarizeFinanceForAnalytics([
      { teamId: "a", entryType: "charge", amountPence: 3500, occurredAt: "2025-12-01T10:00:00.000Z" },
      { teamId: "a", entryType: "payment", amountPence: 1000, occurredAt: "2026-02-02T10:00:00.000Z" },
      { teamId: "b", entryType: "charge", amountPence: 900, occurredAt: "2027-01-01T00:00:00.000Z" },
    ], range[0], range[1]);

    expect(result.expectedIncomePence).toBe(0);
    expect(result.paymentsPence).toBe(1000);
    expect(result.outstandingPence).toBe(2500);
  });

});

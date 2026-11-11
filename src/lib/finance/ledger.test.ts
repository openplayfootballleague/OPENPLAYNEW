import { describe, expect, it } from "vitest";
import { financeEntryImpactPence, outstandingPenceByTeam, poundsToPence } from "./ledger";

describe("manual finance ledger calculations", () => {
  it("converts pounds to exact integer pence", () => {
    expect(poundsToPence("35")).toBe(3500);
    expect(poundsToPence("35.5")).toBe(3550);
    expect(poundsToPence("0.01")).toBe(1);
    expect(poundsToPence("1.999")).toBeNull();
    expect(poundsToPence("-1")).toBeNull();
    expect(poundsToPence("1e2")).toBeNull();
    expect(poundsToPence("")).toBeNull();
  });

  it("treats charges and fines as debt and payments and credits as reductions", () => {
    expect(financeEntryImpactPence("charge", 3500)).toBe(3500);
    expect(financeEntryImpactPence("fine", 500)).toBe(500);
    expect(financeEntryImpactPence("payment", 3500)).toBe(-3500);
    expect(financeEntryImpactPence("credit", 500)).toBe(-500);
  });

  it("treats refunds and credits as reductions to outstanding balances", () => {
    expect(financeEntryImpactPence("refund", 1200)).toBe(-1200);
    expect(financeEntryImpactPence("credit", 500)).toBe(-500);
  });

  it("does not let one team's overpayment cancel another team's debt", () => {
    expect(outstandingPenceByTeam([
      { teamId: "a", type: "charge", amountPence: 3500 },
      { teamId: "a", type: "payment", amountPence: 4000 },
      { teamId: "b", type: "charge", amountPence: 2500 },
    ])).toBe(2500);
  });

  it("rejects zero, negative and fractional pence", () => {
    expect(() => financeEntryImpactPence("charge", 0)).toThrow(RangeError);
    expect(() => financeEntryImpactPence("payment", -1)).toThrow(RangeError);
    expect(() => financeEntryImpactPence("fine", 1.5)).toThrow(RangeError);
  });
});

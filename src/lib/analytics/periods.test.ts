import { describe, expect, it } from "vitest";
import { getPreviousPeriodRange, getPreviousYearRange } from "./periods";

describe("analytics comparison periods", () => {
  it("creates an immediately preceding window of equal duration", () => {
    expect(getPreviousPeriodRange({
      startInclusive: "2026-04-01T00:00:00.000Z",
      endExclusive: "2026-05-01T00:00:00.000Z",
    })).toEqual({
      startInclusive: "2026-03-02T00:00:00.000Z",
      endExclusive: "2026-04-01T00:00:00.000Z",
    });
  });

  it("uses equivalent calendar dates for previous-year comparisons", () => {
    expect(getPreviousYearRange({
      startInclusive: "2026-04-01T00:00:00.000Z",
      endExclusive: "2026-05-01T00:00:00.000Z",
    })).toEqual({
      startInclusive: "2025-04-01T00:00:00.000Z",
      endExclusive: "2025-05-01T00:00:00.000Z",
    });
  });

  it("clamps leap day when shifting back to a non-leap year", () => {
    expect(getPreviousYearRange({
      startInclusive: "2024-02-29T12:00:00.000Z",
      endExclusive: "2024-03-01T12:00:00.000Z",
    })).toEqual({
      startInclusive: "2023-02-28T12:00:00.000Z",
      endExclusive: "2023-03-01T12:00:00.000Z",
    });
  });

  it("rejects invalid ranges", () => {
    expect(() => getPreviousPeriodRange({
      startInclusive: "2026-05-01T00:00:00.000Z",
      endExclusive: "2026-04-01T00:00:00.000Z",
    })).toThrow(RangeError);
  });
});

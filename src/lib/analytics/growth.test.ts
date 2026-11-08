import { describe, expect, it } from "vitest";
import { countReturningTeams, summarizeRegistrationGrowth } from "./growth";

describe("growth analytics", () => {
  const start = "2026-01-01T00:00:00.000Z";
  const end = "2027-01-01T00:00:00.000Z";

  it("counts distinct registered records by location and withdrawals separately", () => {
    expect(summarizeRegistrationGrowth([
      { id: "a", locationId: "bideford", createdAt: "2026-02-01T00:00:00.000Z", status: "registered" },
      { id: "a", locationId: "bideford", createdAt: "2026-02-01T00:00:00.000Z", status: "registered" },
      { id: "b", locationId: "barnstaple", createdAt: "2026-03-01T00:00:00.000Z", status: "registered" },
      { id: "c", locationId: "bideford", createdAt: "2026-04-01T00:00:00.000Z", status: "withdrawn" },
      { id: "d", locationId: "bideford", createdAt: "2025-12-31T23:59:59.999Z", status: "registered" },
      { id: "e", locationId: "bideford", createdAt: end, status: "registered" },
      { id: "f", locationId: "bideford", createdAt: "2026-05-01T00:00:00.000Z", status: "pending" },
    ], start, end)).toEqual({
      newRegistrations: 2,
      withdrawals: 1,
      registrationsByLocation: [
        { locationId: "barnstaple", registrations: 1 },
        { locationId: "bideford", registrations: 1 },
      ],
    });
  });

  it("returns distinct teams present in both seasons", () => {
    expect(countReturningTeams(["a", "a", "b", "c"], ["a", "c", "d"])).toBe(2);
  });

  it("rejects invalid date ranges", () => {
    expect(() => summarizeRegistrationGrowth([], end, start)).toThrow(RangeError);
  });
});

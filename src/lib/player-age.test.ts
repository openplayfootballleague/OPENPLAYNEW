import { describe, expect, it } from "vitest";
import { ageOnUkDate } from "./player-age";

describe("UK player age calculation", () => {
  it("uses the UK civil date across UTC midnight and the spring clock change", () => {
    expect(ageOnUkDate("2010-03-29", new Date("2026-03-28T23:30:00.000Z"))).toBe(15);
    expect(ageOnUkDate("2010-03-29", new Date("2026-03-29T00:30:00.000Z"))).toBe(16);
    expect(ageOnUkDate("2010-03-29", new Date("2026-03-29T01:30:00.000Z"))).toBe(16);
  });

  it("changes eligibility on the eighteenth birthday in UK local time", () => {
    expect(ageOnUkDate("2008-11-09", new Date("2026-11-08T23:30:00.000Z"))).toBe(17);
    expect(ageOnUkDate("2008-11-09", new Date("2026-11-09T00:30:00.000Z"))).toBe(18);
  });

  it("handles leap-day birthdays consistently", () => {
    expect(ageOnUkDate("2008-02-29", new Date("2025-02-28T12:00:00.000Z"))).toBe(16);
    expect(ageOnUkDate("2008-02-29", new Date("2025-03-01T12:00:00.000Z"))).toBe(17);
  });

  it("rejects malformed and impossible dates", () => {
    expect(ageOnUkDate("2026-02-30", new Date("2026-11-09T12:00:00.000Z"))).toBeNull();
    expect(ageOnUkDate("not-a-date", new Date("2026-11-09T12:00:00.000Z"))).toBeNull();
  });
});

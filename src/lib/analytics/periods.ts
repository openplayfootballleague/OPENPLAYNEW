export type AnalyticsDateRange = { startInclusive: string; endExclusive: string };

/** Returns the immediately preceding window with the same elapsed duration. */
export function getPreviousPeriodRange(range: AnalyticsDateRange): AnalyticsDateRange {
  const start = Date.parse(range.startInclusive);
  const end = Date.parse(range.endExclusive);
  if (!Number.isFinite(start) || !Number.isFinite(end) || start >= end) {
    throw new RangeError("Analytics reporting period must be a valid increasing date range.");
  }
  const duration = end - start;
  return {
    startInclusive: new Date(start - duration).toISOString(),
    endExclusive: new Date(start).toISOString(),
  };
}

/** Shifts a UTC date range back one calendar year, clamping leap days safely. */
export function getPreviousYearRange(range: AnalyticsDateRange): AnalyticsDateRange {
  const start = Date.parse(range.startInclusive);
  const end = Date.parse(range.endExclusive);
  if (!Number.isFinite(start) || !Number.isFinite(end) || start >= end) {
    throw new RangeError("Analytics reporting period must be a valid increasing date range.");
  }

  function shiftUtcYear(timestamp: number): string {
    const source = new Date(timestamp);
    const year = source.getUTCFullYear() - 1;
    const month = source.getUTCMonth();
    const day = source.getUTCDate();
    const hour = source.getUTCHours();
    const minute = source.getUTCMinutes();
    const second = source.getUTCSeconds();
    const millisecond = source.getUTCMilliseconds();
    const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
    return new Date(Date.UTC(year, month, Math.min(day, lastDay), hour, minute, second, millisecond)).toISOString();
  }

  return {
    startInclusive: shiftUtcYear(start),
    endExclusive: shiftUtcYear(end),
  };
}

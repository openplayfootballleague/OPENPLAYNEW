import {
  buildProductAnalyticsQueries,
  isValidDate,
  rowsAsObjects,
  validateProductAnalyticsFilters,
} from "./policy.ts";

function assert(value: boolean, message: string): void {
  if (!value) throw new Error(message);
}
function equal(actual: unknown, expected: unknown, message: string): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${message}: expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`);
  }
}
function matches(value: string, expression: RegExp, message: string): void {
  assert(expression.test(value), message);
}
function excludes(value: string, expression: RegExp, message: string): void {
  assert(!expression.test(value), message);
}

const seasonA = "f1000000-0000-4000-8000-000000000030";
const seasonB = "f1000000-0000-4000-8000-000000000031";

Deno.test("validates real calendar dates, including leap days", () => {
  equal(isValidDate("2024-02-29"), true, "Leap day should be valid");
  equal(isValidDate("2025-02-29"), false, "Non-leap February 29 should be invalid");
  equal(isValidDate("2026-02-30"), false, "Invalid calendar day should be rejected");
  equal(isValidDate("not-a-date"), false, "Malformed date should be rejected");
});

Deno.test("rejects reversed, overlong and malformed reporting filters", () => {
  equal(validateProductAnalyticsFilters({
    fromDate: "2026-11-14", toDate: "2026-11-13", seasonIds: [seasonA],
  }), "The reporting start date must be on or before the end date.", "Reversed range");
  equal(validateProductAnalyticsFilters({
    fromDate: "2025-11-12", toDate: "2026-11-13", seasonIds: [seasonA],
  }), "The reporting period cannot exceed 366 days.", "Overlong range");
  equal(validateProductAnalyticsFilters({
    fromDate: "2026-11-01", toDate: "2026-11-13", seasonIds: ["' OR 1=1 --"],
  }), "The reporting context contains an invalid competition season.", "Malformed season ID");
});

Deno.test("allows an empty authorised season list after validating the date window", () => {
  equal(validateProductAnalyticsFilters({
    fromDate: "2026-11-01", toDate: "2026-11-13", seasonIds: [],
  }), null, "An empty scope is a valid no-data state");
});

Deno.test("builds fixed, scoped aggregate queries with inclusive date boundaries", () => {
  const queries = buildProductAnalyticsQueries({
    fromDate: "2026-11-01",
    toDate: "2026-11-13",
    seasonIds: [seasonA, seasonB],
  });
  for (const query of [queries.weeklyActivity, queries.retention, queries.featurePerformance]) {
    matches(query, /event = 'core_value_action'/, "Must query the approved engagement event");
    matches(query, /properties\['season_id'\] IN \('[0-9a-f-]+', '[0-9a-f-]+'\)/, "Must scope to authorised seasons");
    matches(query, /timestamp >= toDateTime\('2026-11-01 00:00:00'\)/, "Must include start boundary");
    matches(query, /timestamp < toDateTime\('2026-11-14 00:00:00'\)/, "Must include the full end date");
    excludes(query, /SELECT \*|distinct_id|email|full_name|phone/, "Must not return direct identifiers or raw rows");
  }
  matches(queries.appUsageSummary, /event = 'navigation_section_viewed'/, "App usage summary must use explicit navigation events");
  matches(queries.appUsageSummary, /uniqExact\(person_id\)/, "App usage summary must count unique visitors");
  matches(queries.appUsageDaily, /event = 'navigation_section_viewed'/, "App usage must use explicit navigation events");
  matches(queries.appUsageDaily, /properties\['visitor_type'\] IN \('anonymous', 'authenticated'\)/, "App usage must separate anonymous and authenticated visitors");
  matches(queries.appUsageSections, /properties\['route_category'\] IN/, "App usage must allowlist navigation sections");
  matches(queries.appUsageDaily, /timestamp >= toDateTime\('2026-11-01 00:00:00'\)/, "App usage must use the selected start date");
  matches(queries.appUsageSections, /timestamp < toDateTime\('2026-11-14 00:00:00'\)/, "App usage must include the full selected end date");
  matches(queries.featurePerformance, /properties\['feature'\] IN \('fixtures', 'results', 'league_table', 'player_statistics', 'team_directory'\)/, "Feature list must be allowlisted");
  matches(queries.weeklyActivity, /timestamp < toStartOfWeek\(now\(\), 1\)/, "Weekly activity must exclude the incomplete current week");
  matches(queries.weeklyActivity, /toStartOfWeek\(timestamp, 1\) >= toDateTime\('2026-11-01 00:00:00'\)/, "Weekly activity must exclude a partial first week");
  matches(queries.weeklyActivity, /addWeeks\(toStartOfWeek\(timestamp, 1\), 1\) <= toDateTime\('2026-11-14 00:00:00'\)/, "Weekly activity must exclude a partial final week");
  matches(queries.retention, /timestamp < toStartOfWeek\(now\(\), 1\)/, "Retention must exclude the incomplete current week");
  matches(queries.retention, /dateDiff\('week'/, "Retention must use weekly intervals");
  matches(queries.retention, /CROSS JOIN numbers\(9\)/, "Retention must zero-fill the first nine weekly intervals");
  matches(queries.retention, /addWeeks\(s.cohort_week, intervals.number \+ 1\) <= toDateTime\('2026-11-14 00:00:00'\)/, "Retention must not zero-fill beyond the selected date window");
  matches(queries.retention, /coalesce\(r.retained_users, 0\)/, "Missing return weeks must be shown as zero");
});

Deno.test("converts PostHog array and object result rows without exposing identifiers", () => {
  equal(rowsAsObjects([["2026-11-09", 7, 12]], ["week_start", "active_users", "value_actions"]), [
    { week_start: "2026-11-09", active_users: 7, value_actions: 12 },
  ], "Array rows");
  equal(rowsAsObjects([{ feature: "fixtures", unique_users: 3 }], ["feature", "unique_users"]), [
    { feature: "fixtures", unique_users: 3 },
  ], "Object rows");
  equal(rowsAsObjects(null, ["feature"]), [], "Missing rows");
});

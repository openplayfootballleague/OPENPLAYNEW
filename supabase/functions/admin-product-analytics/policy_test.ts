import { assertEquals, assertMatch, assertNotMatch } from "jsr:@std/assert@1";
import {
  buildProductAnalyticsQueries,
  isValidDate,
  rowsAsObjects,
  validateProductAnalyticsFilters,
} from "./policy.ts";

const seasonA = "f1000000-0000-4000-8000-000000000030";
const seasonB = "f1000000-0000-4000-8000-000000000031";

Deno.test("validates real calendar dates, including leap days", () => {
  assertEquals(isValidDate("2024-02-29"), true);
  assertEquals(isValidDate("2025-02-29"), false);
  assertEquals(isValidDate("2026-02-30"), false);
  assertEquals(isValidDate("not-a-date"), false);
});

Deno.test("rejects reversed, overlong and malformed reporting filters", () => {
  assertEquals(validateProductAnalyticsFilters({
    fromDate: "2026-11-14", toDate: "2026-11-13", seasonIds: [seasonA],
  }), "The reporting start date must be on or before the end date.");
  assertEquals(validateProductAnalyticsFilters({
    fromDate: "2025-11-12", toDate: "2026-11-13", seasonIds: [seasonA],
  }), "The reporting period cannot exceed 366 days.");
  assertEquals(validateProductAnalyticsFilters({
    fromDate: "2026-11-01", toDate: "2026-11-13", seasonIds: ["' OR 1=1 --"],
  }), "The reporting context contains an invalid competition season.");
});

Deno.test("builds fixed, scoped aggregate queries with inclusive date boundaries", () => {
  const queries = buildProductAnalyticsQueries({
    fromDate: "2026-11-01",
    toDate: "2026-11-13",
    seasonIds: [seasonA, seasonB],
  });
  for (const query of Object.values(queries)) {
    assertMatch(query, /event = 'core_value_action'/);
    assertMatch(query, /properties\['season_id'\] IN \('[0-9a-f-]+', '[0-9a-f-]+'\)/);
    assertMatch(query, /timestamp >= toDateTime\('2026-11-01 00:00:00'\)/);
    assertMatch(query, /timestamp < toDateTime\('2026-11-14 00:00:00'\)/);
    assertNotMatch(query, /SELECT \*|distinct_id|email|full_name|phone/);
  }
  assertMatch(queries.featurePerformance, /properties\['feature'\] IN \('fixtures', 'results', 'league_table', 'player_statistics', 'team_directory'\)/);
  assertMatch(queries.retention, /timestamp < toStartOfWeek\(now\(\), 1\)/);
  assertMatch(queries.retention, /dateDiff\('week'/);
});

Deno.test("converts PostHog array and object result rows without exposing identifiers", () => {
  assertEquals(rowsAsObjects([["2026-11-09", 7, 12]], ["week_start", "active_users", "value_actions"]), [
    { week_start: "2026-11-09", active_users: 7, value_actions: 12 },
  ]);
  assertEquals(rowsAsObjects([{ feature: "fixtures", unique_users: 3 }], ["feature", "unique_users"]), [
    { feature: "fixtures", unique_users: 3 },
  ]);
  assertEquals(rowsAsObjects(null, ["feature"]), []);
});

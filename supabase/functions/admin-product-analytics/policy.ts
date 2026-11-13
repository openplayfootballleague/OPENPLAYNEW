export type ProductAnalyticsFilters = {
  fromDate: string;
  toDate: string;
  seasonIds: string[];
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DATE = /^\d{4}-\d{2}-\d{2}$/;

export function isValidDate(value: string): boolean {
  if (!DATE.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

export function validateProductAnalyticsFilters(filters: ProductAnalyticsFilters): string | null {
  if (!isValidDate(filters.fromDate) || !isValidDate(filters.toDate)) return "Choose valid reporting dates.";
  if (filters.fromDate > filters.toDate) return "The reporting start date must be on or before the end date.";
  const from = Date.parse(`${filters.fromDate}T00:00:00.000Z`);
  const to = Date.parse(`${filters.toDate}T00:00:00.000Z`);
  if ((to - from) / 86_400_000 > 365) return "The reporting period cannot exceed 366 days.";
  if (filters.seasonIds.some((id) => !UUID.test(id))) {
    return "The reporting context contains an invalid competition season.";
  }
  return null;
}

export function buildProductAnalyticsQueries(filters: ProductAnalyticsFilters) {
  const seasons = filters.seasonIds.map((id) => `'${id}'`).join(", ");
  const from = `${filters.fromDate} 00:00:00`;
  const until = new Date(Date.parse(`${filters.toDate}T00:00:00.000Z`) + 86_400_000)
    .toISOString().slice(0, 10) + " 00:00:00";
  const scope = `event = 'core_value_action'
    AND timestamp >= toDateTime('${from}')
    AND timestamp < toDateTime('${until}')
    AND properties['season_id'] IN (${seasons})`;

  return {
    weeklyActivity: `SELECT
      toStartOfWeek(timestamp, 1) AS week_start,
      uniqExact(person_id) AS active_users,
      count() AS value_actions
    FROM events
    WHERE ${scope}
      AND timestamp < toStartOfWeek(now(), 1)
    GROUP BY week_start
    ORDER BY week_start ASC
    LIMIT 54`,
    featurePerformance: `SELECT
      properties['feature'] AS feature,
      uniqExact(person_id) AS unique_users,
      count() AS value_actions
    FROM events
    WHERE ${scope}
      AND properties['feature'] IN ('fixtures', 'results', 'league_table', 'player_statistics', 'team_directory')
    GROUP BY feature
    ORDER BY value_actions DESC
    LIMIT 20`,
    retention: `WITH weekly_activity AS (
      SELECT
        person_id,
        toStartOfWeek(timestamp, 1) AS active_week
      FROM events
      WHERE ${scope}
        AND timestamp < toStartOfWeek(now(), 1)
      GROUP BY person_id, active_week
    ),
    cohorts AS (
      SELECT person_id, min(active_week) AS cohort_week
      FROM weekly_activity
      GROUP BY person_id
    ),
    cohort_sizes AS (
      SELECT cohort_week, uniqExact(person_id) AS cohort_users
      FROM cohorts
      GROUP BY cohort_week
    )
    SELECT
      toDate(c.cohort_week) AS cohort_week,
      dateDiff('week', c.cohort_week, a.active_week) AS weeks_since_start,
      any(s.cohort_users) AS cohort_users,
      uniqExact(a.person_id) AS retained_users,
      round(uniqExact(a.person_id) / any(s.cohort_users) * 100, 1) AS retention_rate
    FROM weekly_activity AS a
    INNER JOIN cohorts AS c ON c.person_id = a.person_id
    INNER JOIN cohort_sizes AS s ON s.cohort_week = c.cohort_week
    WHERE c.cohort_week >= toDateTime('${from}')
      AND c.cohort_week < toDateTime('${until}')
      AND dateDiff('week', c.cohort_week, a.active_week) BETWEEN 0 AND 8
    GROUP BY c.cohort_week, weeks_since_start
    ORDER BY cohort_week ASC, weeks_since_start ASC
    LIMIT 500`,
  };
}

export function rowsAsObjects(
  results: unknown,
  columns: string[],
): Array<Record<string, unknown>> {
  if (!Array.isArray(results)) return [];
  return results.flatMap((row) => {
    if (Array.isArray(row)) {
      return [Object.fromEntries(columns.map((column, index) => [column, row[index]]))];
    }
    if (row && typeof row === "object") return [row as Record<string, unknown>];
    return [];
  });
}

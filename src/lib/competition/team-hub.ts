/**
 * Team hub rules (references IMG_0533, IMG_0535, IMG_0536, IMG_0538, IMG_0540).
 * Pure functions: data loading and permissions live in the route and the database.
 */
import { buildStandings, DEFAULT_POINTS, type PointsRules } from "./standings";
import { completedMatches, type MatchFixture, type MatchResult } from "./player-matches";

export type HubTeam = { id: string; name: string };

/** Only completed fixtures with a confirmed result count (same rule as My Results and the squad RPC). */
export function publishedResults(fixtures: readonly MatchFixture[], results: readonly MatchResult[]): MatchResult[] {
  const completed = new Set(fixtures.filter((f) => f.status === "completed").map((f) => f.id));
  return results.filter((r) => r.confirmed_at && completed.has(r.fixture_id));
}

export type TeamSummary = { position: number | null; points: number; played: number; won: number; drawn: number; lost: number };

/** League position (shared on equal points, D7), points and record for one team. */
export function teamSummary(teamId: string, teams: readonly HubTeam[], fixtures: readonly MatchFixture[], results: readonly MatchResult[], points: PointsRules = DEFAULT_POINTS): TeamSummary {
  const standing = buildStandings([...teams], [...fixtures], publishedResults(fixtures, results), points).find((row) => row.id === teamId);
  if (!standing) return { position: null, points: 0, played: 0, won: 0, drawn: 0, lost: 0 };
  return { position: standing.played > 0 ? standing.position : null, points: standing.points, played: standing.played, won: standing.won, drawn: standing.drawn, lost: standing.lost };
}

export function ordinal(position: number): string {
  const tens = position % 100;
  if (tens >= 11 && tens <= 13) return `${position}th`;
  return `${position}${({ 1: "st", 2: "nd", 3: "rd" } as Record<number, string>)[position % 10] ?? "th"}`;
}

const kickOff = (f: MatchFixture) => (f.scheduled_at ? Date.parse(f.scheduled_at) : Number.POSITIVE_INFINITY);

export type ScheduleEntry = { fixture: MatchFixture; result: MatchResult | null };

/** The team's full season schedule in kick-off order; results attached only when published. */
export function teamSchedule(teamId: string, fixtures: readonly MatchFixture[], results: readonly MatchResult[]): ScheduleEntry[] {
  const published = new Map(publishedResults(fixtures, results).map((r) => [r.fixture_id, r]));
  return fixtures
    .filter((f) => f.home_team_id === teamId || f.away_team_id === teamId)
    .sort((a, b) => kickOff(a) - kickOff(b) || a.gameweek - b.gameweek || a.id.localeCompare(b.id))
    .map((fixture) => ({ fixture, result: published.get(fixture.id) ?? null }));
}

/** 1-based page holding the next fixture still to be played ("Current Gameweek", IMG_0540). */
export function currentGameweekPage(schedule: readonly ScheduleEntry[], pageSize: number): number {
  const index = schedule.findIndex((entry) => entry.fixture.status !== "completed" && entry.fixture.status !== "cancelled");
  return index < 0 ? Math.max(1, Math.ceil(schedule.length / pageSize)) : Math.floor(index / pageSize) + 1;
}

export function nextFixture(schedule: readonly ScheduleEntry[]): ScheduleEntry | null {
  return schedule.find((entry) => entry.fixture.status === "scheduled" || entry.fixture.status === "postponed") ?? null;
}

export function latestResult(teamId: string, fixtures: readonly MatchFixture[], results: readonly MatchResult[]) {
  return completedMatches(fixtures, results, teamId)[0] ?? null;
}

export type SquadMember = {
  competition_player_id: string; player_name: string; squad_number: number | null; is_captain: boolean;
  appearances: number; goals: number; assists: number; clean_sheets: number; motm_awards: number;
};

export type ClubLeader = { label: string; unit: string; player: SquadMember; value: number };

/** Club leaders (IMG_0536): highest non-zero total; ties resolved by name for a stable display. */
export function clubLeaders(squad: readonly SquadMember[]): ClubLeader[] {
  const categories: [string, string, keyof SquadMember][] = [
    ["Top scorer", "Goals", "goals"], ["Top assists", "Assists", "assists"],
    ["Clean sheets", "Clean sheets", "clean_sheets"], ["Man of the Match", "Awards", "motm_awards"],
  ];
  return categories.flatMap(([label, unit, key]) => {
    const best = [...squad].filter((p) => Number(p[key]) > 0)
      .sort((a, b) => Number(b[key]) - Number(a[key]) || a.player_name.localeCompare(b.player_name))[0];
    return best ? [{ label, unit, player: best, value: Number(best[key]) }] : [];
  });
}

export function filterByName<T>(items: readonly T[], query: string, name: (item: T) => string): T[] {
  const needle = query.trim().toLocaleLowerCase("en-GB");
  return needle ? items.filter((item) => name(item).toLocaleLowerCase("en-GB").includes(needle)) : [...items];
}

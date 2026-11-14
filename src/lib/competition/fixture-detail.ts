/**
 * Fixture detail and match report rules (audit plan step 4).
 * Pure functions only: loading and permissions live in the route, RLS and
 * `get_public_fixture_match_report`, which stays authoritative for what is published.
 */
import { teamOutcome, type MatchFixture, type MatchResult, type Outcome } from "./player-matches";
import { publishedResults } from "./team-hub";

export type TeamSide = "home" | "away";

export type FixtureState =
  | "upcoming"
  | "in_progress"
  | "postponed"
  | "cancelled"
  | "awaiting_result"
  | "result";

/** A score is only shown once the fixture is completed and the result confirmed. */
export function publishedResultFor(fixture: MatchFixture, results: readonly MatchResult[]): MatchResult | null {
  return publishedResults([fixture], results).find((r) => r.fixture_id === fixture.id) ?? null;
}

export function fixtureState(fixture: MatchFixture, result: MatchResult | null): FixtureState {
  switch (fixture.status) {
    case "completed": return result && result.confirmed_at ? "result" : "awaiting_result";
    case "in_progress": return "in_progress";
    case "postponed": return "postponed";
    case "cancelled": return "cancelled";
    default: return "upcoming";
  }
}

export const FIXTURE_STATE_LABEL: Record<FixtureState, string> = {
  upcoming: "Upcoming",
  in_progress: "In progress",
  postponed: "Postponed",
  cancelled: "Cancelled",
  awaiting_result: "Result pending",
  result: "Full time",
};

const kickOff = (f: MatchFixture) => (f.scheduled_at ? Date.parse(f.scheduled_at) : Number.POSITIVE_INFINITY);

/** Order used everywhere for "before this fixture": kick-off, then gameweek, then id. */
function isBefore(a: MatchFixture, b: MatchFixture): boolean {
  return kickOff(a) - kickOff(b) < 0 || (kickOff(a) === kickOff(b) && (a.gameweek - b.gameweek < 0 || (a.gameweek === b.gameweek && a.id < b.id)));
}

/**
 * Form guide: the team's last `limit` published results played before this fixture,
 * oldest first so it reads left to right like a league table form column.
 * Title finals are included; they are real matches even though they carry no league points.
 */
export function formBefore(
  teamId: string,
  fixture: MatchFixture,
  fixtures: readonly MatchFixture[],
  results: readonly MatchResult[],
  limit = 5,
): Outcome[] {
  const published = new Map(publishedResults(fixtures, results).map((r) => [r.fixture_id, r]));
  return fixtures
    .filter((f) => f.id !== fixture.id && (f.home_team_id === teamId || f.away_team_id === teamId) && published.has(f.id) && isBefore(f, fixture))
    .sort((a, b) => (isBefore(a, b) ? -1 : 1))
    .slice(-limit)
    .map((f) => teamOutcome(teamId, f, published.get(f.id)!));
}

export type Meeting = { fixture: MatchFixture; result: MatchResult | null };

/** Other fixtures between the same two teams in this season, in kick-off order. */
export function seasonMeetings(fixture: MatchFixture, fixtures: readonly MatchFixture[], results: readonly MatchResult[]): Meeting[] {
  const pair = new Set([fixture.home_team_id, fixture.away_team_id]);
  const published = new Map(publishedResults(fixtures, results).map((r) => [r.fixture_id, r]));
  return fixtures
    .filter((f) => f.id !== fixture.id && pair.has(f.home_team_id) && pair.has(f.away_team_id) && f.home_team_id !== f.away_team_id)
    .sort((a, b) => (isBefore(a, b) ? -1 : 1))
    .map((f) => ({ fixture: f, result: published.get(f.id) ?? null }));
}

/* ── Match report (server payload from get_public_fixture_match_report) ── */

export type ReportGoal = { team_side: TeamSide; scorer_name: string; assist_name: string | null; is_own_goal: boolean };
export type ReportMotm = { team_side: TeamSide; player_name: string };
export type ReportAppearance = { team_side: TeamSide; player_name: string; role: "starter" | "substitute"; is_goalkeeper: boolean; squad_number: number | null };
export type MatchReport = { published: boolean; goals: ReportGoal[]; motm: ReportMotm[]; lineups: ReportAppearance[] };

const isSide = (v: unknown): v is TeamSide => v === "home" || v === "away";
const isText = (v: unknown): v is string => typeof v === "string" && v.trim().length > 0;
const asArray = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const asRecord = (v: unknown): Record<string, unknown> => (v && typeof v === "object" ? (v as Record<string, unknown>) : {});

/**
 * Validates the RPC payload. Malformed entries are dropped rather than rendered, and an
 * unrecognisable payload returns null so the page shows an error instead of a blank report.
 */
export function parseMatchReport(raw: unknown): MatchReport | null {
  const data = asRecord(raw);
  if (typeof data.published !== "boolean") return null;
  const goals = asArray(data.goals).map(asRecord).flatMap((g): ReportGoal[] =>
    isSide(g.team_side) && isText(g.scorer_name)
      ? [{ team_side: g.team_side, scorer_name: g.scorer_name, assist_name: isText(g.assist_name) ? g.assist_name : null, is_own_goal: g.is_own_goal === true }]
      : []);
  const motm = asArray(data.motm).map(asRecord).flatMap((m): ReportMotm[] =>
    isSide(m.team_side) && isText(m.player_name) ? [{ team_side: m.team_side, player_name: m.player_name }] : []);
  const lineups = asArray(data.lineups).map(asRecord).flatMap((p): ReportAppearance[] =>
    isSide(p.team_side) && isText(p.player_name) && (p.role === "starter" || p.role === "substitute")
      ? [{
        team_side: p.team_side, player_name: p.player_name, role: p.role, is_goalkeeper: p.is_goalkeeper === true,
        squad_number: typeof p.squad_number === "number" && Number.isInteger(p.squad_number) ? p.squad_number : null,
      }]
      : []);
  // An unpublished report must never carry events, whatever the payload says.
  if (!data.published) return { published: false, goals: [], motm: [], lineups: [] };
  return { published: true, goals, motm, lineups };
}

export type ScorerLine = { name: string; goals: number; isOwnGoal: boolean; assists: string[] };

/**
 * Goals credited to one side, grouped by scorer. Goal records carry no match minute, so the
 * report lists scorers rather than inventing a timeline. Own goals are credited to the side
 * that benefited and are listed separately from that player's ordinary goals.
 */
export function scorersFor(goals: readonly ReportGoal[], side: TeamSide): ScorerLine[] {
  const lines = new Map<string, ScorerLine>();
  for (const goal of goals) {
    if (goal.team_side !== side) continue;
    const key = `${goal.is_own_goal ? "og" : "g"}:${goal.scorer_name}`;
    const line = lines.get(key) ?? { name: goal.scorer_name, goals: 0, isOwnGoal: goal.is_own_goal, assists: [] };
    line.goals += 1;
    if (goal.assist_name) line.assists.push(goal.assist_name);
    lines.set(key, line);
  }
  return [...lines.values()].sort((a, b) => b.goals - a.goals || Number(a.isOwnGoal) - Number(b.isOwnGoal) || a.name.localeCompare(b.name));
}

export type Lineup = { starters: ReportAppearance[]; substitutes: ReportAppearance[] };

export function lineupFor(lineups: readonly ReportAppearance[], side: TeamSide): Lineup {
  const players = lineups.filter((p) => p.team_side === side);
  return { starters: players.filter((p) => p.role === "starter"), substitutes: players.filter((p) => p.role === "substitute") };
}

/** Number of goals the report attributes to each side; never more than the confirmed score. */
export function reportIsConsistent(report: MatchReport, result: MatchResult): boolean {
  const count = (side: TeamSide) => report.goals.filter((g) => g.team_side === side).length;
  return count("home") <= result.home_score && count("away") <= result.away_score;
}

/** Directions link for a venue; uses only the venue's public name and address. */
export function venueDirectionsUrl(venue: { name: string; address: string | null }): string {
  const query = [venue.name, venue.address].filter(isText).join(", ");
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}`;
}

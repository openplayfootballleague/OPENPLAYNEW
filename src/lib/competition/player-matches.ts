/**
 * Player Hub "My Fixtures" / "My Results" rules (spec join-open-play-and-player-screens
 * sections 11-12, visual references IMG_0572 / IMG_0573).
 */

export type MatchFixture = {
  id: string;
  gameweek: number;
  scheduled_at: string | null;
  status: "scheduled" | "in_progress" | "completed" | "postponed" | "cancelled";
  home_team_id: string;
  away_team_id: string;
  venue_id?: string | null;
  is_title_final?: boolean | null;
};

export type MatchResult = { fixture_id: string; home_score: number; away_score: number; confirmed_at: string | null };

export type Outcome = "win" | "draw" | "loss";

/** Outcome from the selected team's perspective, never from home/away position. */
export function teamOutcome(teamId: string, fixture: MatchFixture, result: MatchResult): Outcome {
  const isHome = fixture.home_team_id === teamId;
  const ours = isHome ? result.home_score : result.away_score;
  const theirs = isHome ? result.away_score : result.home_score;
  if (ours > theirs) return "win";
  if (ours < theirs) return "loss";
  return "draw";
}

const kickOff = (f: MatchFixture) => (f.scheduled_at ? Date.parse(f.scheduled_at) : Number.POSITIVE_INFINITY);

/**
 * Upcoming list: everything not yet completed, chronological ascending, with a stable
 * tie-break so pages never duplicate or skip. Cancelled fixtures stay visible with
 * their own state rather than silently disappearing.
 */
export function upcomingFixtures(fixtures: readonly MatchFixture[], teamId: string): MatchFixture[] {
  return fixtures
    .filter((f) => (f.home_team_id === teamId || f.away_team_id === teamId) && f.status !== "completed")
    .sort((a, b) => kickOff(a) - kickOff(b) || a.gameweek - b.gameweek || a.id.localeCompare(b.id));
}

export type CompletedMatch = { fixture: MatchFixture; result: MatchResult; outcome: Outcome };

/** Completed list: only published (confirmed) results, newest first. */
export function completedMatches(fixtures: readonly MatchFixture[], results: readonly MatchResult[], teamId: string): CompletedMatch[] {
  const byFixture = new Map(results.filter((r) => r.confirmed_at).map((r) => [r.fixture_id, r]));
  return fixtures
    .filter((f) => (f.home_team_id === teamId || f.away_team_id === teamId) && f.status === "completed" && byFixture.has(f.id))
    .map((fixture) => {
      const result = byFixture.get(fixture.id)!;
      return { fixture, result, outcome: teamOutcome(teamId, fixture, result) };
    })
    .sort((a, b) => kickOff(b.fixture) - kickOff(a.fixture) || b.fixture.gameweek - a.fixture.gameweek || a.fixture.id.localeCompare(b.fixture.id));
}

export type Page<T> = { items: T[]; from: number; to: number; total: number; page: number; pages: number; hasPrevious: boolean; hasNext: boolean };

/** 1-based pagination; out-of-range pages clamp to the nearest valid page. */
export function paginate<T>(items: readonly T[], page: number, size: number): Page<T> {
  const total = items.length;
  const pages = Math.max(1, Math.ceil(total / size));
  const current = Math.min(Math.max(1, Math.floor(page) || 1), pages);
  const start = (current - 1) * size;
  const slice = items.slice(start, start + size);
  return {
    items: slice,
    from: total === 0 ? 0 : start + 1,
    to: start + slice.length,
    total,
    page: current,
    pages,
    hasPrevious: current > 1,
    hasNext: current < pages,
  };
}

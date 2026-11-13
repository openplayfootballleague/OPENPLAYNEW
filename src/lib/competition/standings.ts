export type StandingInputTeam = { id: string; name: string };
/** `is_title_final` fixtures decide a shared first place (owner decision D7) and never add league points. */
export type StandingInputFixture = { id: string; home_team_id: string; away_team_id: string; is_title_final?: boolean | null };
export type StandingInputResult = { fixture_id: string; home_score: number; away_score: number };
export type Standing = { id: string; name: string; played: number; won: number; drawn: number; lost: number; for: number; against: number; points: number; position: number };

/** Open Play uses 3/1/0 points. Teams level on points share a position; goal difference and goals scored are informational only. */
export function buildStandings(teams: StandingInputTeam[], fixtures: StandingInputFixture[], results: StandingInputResult[]): Standing[] {
  const rows = new Map<string, Omit<Standing, "position">>();
  for (const team of teams) rows.set(team.id, { id: team.id, name: team.name, played: 0, won: 0, drawn: 0, lost: 0, for: 0, against: 0, points: 0 });
  const resultByFixture = new Map(results.map((result) => [result.fixture_id, result]));
  for (const fixture of fixtures) {
    if (fixture.is_title_final) continue;
    const result = resultByFixture.get(fixture.id);
    if (!result) continue;
    const home = rows.get(fixture.home_team_id), away = rows.get(fixture.away_team_id);
    if (!home || !away) continue;
    home.played++; away.played++;
    home.for += result.home_score; home.against += result.away_score;
    away.for += result.away_score; away.against += result.home_score;
    if (result.home_score > result.away_score) { home.won++; home.points += 3; away.lost++; }
    else if (result.home_score < result.away_score) { away.won++; away.points += 3; home.lost++; }
    else { home.drawn++; away.drawn++; home.points++; away.points++; }
  }
  const ordered = [...rows.values()].sort((a,b) => b.points-a.points || a.name.localeCompare(b.name));
  let position=0, previousPoints:number|null=null;
  return ordered.map((standing,index) => {
    if (standing.points !== previousPoints) position=index+1;
    previousPoints=standing.points;
    return {...standing,position};
  });
}

/** Return the tied leaders only when a final is required to decide first place.
 * Mirrors `public.season_joint_leaders`: before anyone has scored a point every team shares
 * position 1, which is not a title tie. */
export function getJointFirstTeams<T extends { position: number; points?: number }>(teams: T[]): T[] {
  const leaders = teams.filter((team) => team.position === 1);
  if (leaders.length > 0 && leaders.every((team) => team.points === 0)) return [];
  return leaders.length > 1 ? leaders : [];
}

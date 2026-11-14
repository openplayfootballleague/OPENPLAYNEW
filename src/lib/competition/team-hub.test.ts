import { describe, expect, it } from "vitest";
import { clubLeaders, currentGameweekPage, filterByName, nextFixture, ordinal, publishedResults, teamSchedule, teamSummary, type SquadMember } from "./team-hub";
import type { MatchFixture, MatchResult } from "./player-matches";

const fx = (id: string, gw: number, home: string, away: string, status: MatchFixture["status"], day: number): MatchFixture =>
  ({ id, gameweek: gw, home_team_id: home, away_team_id: away, status, scheduled_at: `2026-10-${String(day).padStart(2, "0")}T19:00:00Z` });
const teams = [{ id: "A", name: "Alpha" }, { id: "B", name: "Bravo" }, { id: "C", name: "Charlie" }];
const fixtures = [fx("1", 1, "A", "B", "completed", 1), fx("2", 2, "C", "A", "completed", 8), fx("3", 3, "A", "C", "completed", 15), fx("4", 4, "B", "A", "scheduled", 22), fx("5", 5, "A", "B", "scheduled", 29)];
const results: MatchResult[] = [
  { fixture_id: "1", home_score: 2, away_score: 0, confirmed_at: "2026-10-01T21:00:00Z" },
  { fixture_id: "2", home_score: 1, away_score: 1, confirmed_at: "2026-10-08T21:00:00Z" },
  { fixture_id: "3", home_score: 0, away_score: 3, confirmed_at: null },
];

describe("team hub", () => {
  it("counts only completed fixtures with a confirmed result", () => {
    expect(publishedResults(fixtures, results).map((r) => r.fixture_id)).toEqual(["1", "2"]);
    expect(teamSummary("A", teams, fixtures, results)).toEqual({ position: 1, points: 4, played: 2, won: 1, drawn: 1, lost: 0 });
  });

  it("uses the season's points rules and shares positions on equal points", () => {
    expect(teamSummary("A", teams, fixtures, results, { win: 2, draw: 1, loss: 0 }).points).toBe(3);
    expect(teamSummary("B", teams, fixtures, results).position).toBe(3);
    expect(teamSummary("C", teams, fixtures, results).position).toBe(2);
  });

  it("has no position before a team has played", () => {
    expect(teamSummary("A", teams, [], []).position).toBeNull();
  });

  it("formats ordinal positions", () => {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 103].map(ordinal)).toEqual(["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "103rd"]);
  });

  it("builds the schedule in kick-off order and finds the current gameweek page", () => {
    const schedule = teamSchedule("A", fixtures, results);
    expect(schedule.map((e) => e.fixture.id)).toEqual(["1", "2", "3", "4", "5"]);
    expect(schedule[2].result).toBeNull();
    expect(currentGameweekPage(schedule, 3)).toBe(2);
    expect(nextFixture(schedule)?.fixture.id).toBe("4");
  });

  it("picks club leaders by non-zero totals with a stable tie-break", () => {
    const member = (name: string, over: Partial<SquadMember>): SquadMember => ({ competition_player_id: name, player_name: name, squad_number: null, is_captain: false, appearances: 1, goals: 0, assists: 0, clean_sheets: 0, motm_awards: 0, ...over });
    const leaders = clubLeaders([member("Zed", { goals: 3 }), member("Amy", { goals: 3, assists: 1 }), member("Ben", { clean_sheets: 2 })]);
    expect(leaders.map((l) => `${l.label}:${l.player.player_name}:${l.value}`)).toEqual(["Top scorer:Amy:3", "Top assists:Amy:1", "Clean sheets:Ben:2"]);
  });

  it("filters by name, ignoring case and surrounding spaces", () => {
    expect(filterByName(teams, "  ALP ", (t) => t.name).map((t) => t.id)).toEqual(["A"]);
    expect(filterByName(teams, "", (t) => t.name)).toHaveLength(3);
  });
});

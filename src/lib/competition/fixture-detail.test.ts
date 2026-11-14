import { describe, expect, it } from "vitest";
import {
  fixtureState, formBefore, lineupFor, parseMatchReport, publishedResultFor, reportIsConsistent,
  scorersFor, seasonMeetings, venueDirectionsUrl, type ReportGoal,
} from "./fixture-detail";
import type { MatchFixture, MatchResult } from "./player-matches";

const A = "team-a", B = "team-b", C = "team-c";
const fx = (id: string, gameweek: number, day: number | null, home: string, away: string, status: MatchFixture["status"] = "completed", extra: Partial<MatchFixture> = {}): MatchFixture => ({
  id, gameweek, scheduled_at: day === null ? null : new Date(Date.UTC(2026, 9, day, 19)).toISOString(), status, home_team_id: home, away_team_id: away, ...extra,
});
const res = (fixture_id: string, home_score: number, away_score: number, confirmed = true): MatchResult => ({ fixture_id, home_score, away_score, confirmed_at: confirmed ? "2026-10-30T00:00:00Z" : null });

describe("fixtureState and published results", () => {
  it("shows a score only for completed fixtures with a confirmed result", () => {
    const f = fx("f1", 1, 1, A, B);
    expect(publishedResultFor(f, [res("f1", 2, 1)])).not.toBeNull();
    expect(publishedResultFor(f, [res("f1", 2, 1, false)])).toBeNull();
    expect(publishedResultFor(fx("f1", 1, 1, A, B, "scheduled"), [res("f1", 2, 1)])).toBeNull();
  });
  it("maps every fixture status to a state", () => {
    expect(fixtureState(fx("f", 1, 1, A, B, "scheduled"), null)).toBe("upcoming");
    expect(fixtureState(fx("f", 1, 1, A, B, "in_progress"), null)).toBe("in_progress");
    expect(fixtureState(fx("f", 1, 1, A, B, "postponed"), null)).toBe("postponed");
    expect(fixtureState(fx("f", 1, 1, A, B, "cancelled"), null)).toBe("cancelled");
    expect(fixtureState(fx("f", 1, 1, A, B, "completed"), null)).toBe("awaiting_result");
    expect(fixtureState(fx("f", 1, 1, A, B, "completed"), res("f", 0, 0))).toBe("result");
    expect(fixtureState(fx("f", 1, 1, A, B, "completed"), res("f", 0, 0, false))).toBe("awaiting_result");
  });
});

describe("formBefore", () => {
  const fixtures = [
    fx("g1", 1, 1, A, B), fx("g2", 2, 8, C, A), fx("g3", 3, 15, A, C), fx("g4", 4, 22, B, A),
    fx("g5", 5, 29, A, B, "scheduled"), fx("g6", 6, 30, A, C), fx("g0", 0, null, A, C),
  ];
  const results = [res("g1", 2, 0), res("g2", 1, 1), res("g3", 0, 3), res("g4", 1, 2), res("g6", 1, 0, false), res("g0", 5, 0)];

  it("lists published results before the fixture, oldest first, from the team's perspective", () => {
    expect(formBefore(A, fixtures[4], fixtures, results)).toEqual(["win", "draw", "loss", "win"]);
    expect(formBefore(B, fixtures[4], fixtures, results)).toEqual(["loss", "loss"]);
  });
  it("excludes later matches, unconfirmed results and undated fixtures", () => {
    expect(formBefore(A, fixtures[2], fixtures, results)).toEqual(["win", "draw"]);
    expect(formBefore(A, fixtures[5], fixtures, results)).not.toContain(undefined);
    expect(formBefore(A, fixtures[5], fixtures, results)).toHaveLength(4);
  });
  it("keeps only the most recent results when limited", () => {
    expect(formBefore(A, fixtures[4], fixtures, results, 2)).toEqual(["loss", "win"]);
  });
});

describe("seasonMeetings", () => {
  it("returns the other fixtures between the same teams with published scores only", () => {
    const fixtures = [fx("m1", 1, 1, A, B), fx("m2", 2, 8, B, A, "scheduled"), fx("m3", 3, 15, A, C), fx("m4", 4, 22, A, B)];
    const meetings = seasonMeetings(fixtures[3], fixtures, [res("m1", 3, 1), res("m4", 0, 0)]);
    expect(meetings.map((m) => m.fixture.id)).toEqual(["m1", "m2"]);
    expect(meetings[0].result?.home_score).toBe(3);
    expect(meetings[1].result).toBeNull();
  });
});

describe("parseMatchReport", () => {
  it("accepts a well-formed payload", () => {
    const report = parseMatchReport({
      published: true,
      goals: [{ team_side: "home", scorer_name: "Sam", assist_name: "Lee", is_own_goal: false }],
      motm: [{ team_side: "away", player_name: "Jo" }],
      lineups: [{ team_side: "home", player_name: "Sam", role: "starter", is_goalkeeper: false, squad_number: 9 }],
    });
    expect(report?.goals).toHaveLength(1);
    expect(report?.motm[0].player_name).toBe("Jo");
    expect(report?.lineups[0].squad_number).toBe(9);
  });
  it("drops malformed entries and rejects unrecognisable payloads", () => {
    expect(parseMatchReport(null)).toBeNull();
    expect(parseMatchReport({ goals: [] })).toBeNull();
    const report = parseMatchReport({
      published: true,
      goals: [{ team_side: "middle", scorer_name: "X" }, { team_side: "home", scorer_name: " " }, { team_side: "away", scorer_name: "Y", assist_name: "" }],
      motm: "nope",
      lineups: [{ team_side: "home", player_name: "Z", role: "captain" }, { team_side: "home", player_name: "Q", role: "substitute", squad_number: 4.5 }],
    });
    expect(report?.goals).toEqual([{ team_side: "away", scorer_name: "Y", assist_name: null, is_own_goal: false }]);
    expect(report?.motm).toEqual([]);
    expect(report?.lineups).toEqual([{ team_side: "home", player_name: "Q", role: "substitute", is_goalkeeper: false, squad_number: null }]);
  });
  it("never exposes events for an unpublished report", () => {
    const report = parseMatchReport({ published: false, goals: [{ team_side: "home", scorer_name: "Leak" }], motm: [], lineups: [] });
    expect(report).toEqual({ published: false, goals: [], motm: [], lineups: [] });
  });
});

describe("scorersFor and lineupFor", () => {
  const goals: ReportGoal[] = [
    { team_side: "home", scorer_name: "Sam", assist_name: "Lee", is_own_goal: false },
    { team_side: "home", scorer_name: "Ash", assist_name: null, is_own_goal: false },
    { team_side: "home", scorer_name: "Sam", assist_name: null, is_own_goal: false },
    { team_side: "away", scorer_name: "Sam", assist_name: null, is_own_goal: true },
  ];
  it("groups goals per scorer for one side, most goals first", () => {
    expect(scorersFor(goals, "home")).toEqual([
      { name: "Sam", goals: 2, isOwnGoal: false, assists: ["Lee"] },
      { name: "Ash", goals: 1, isOwnGoal: false, assists: [] },
    ]);
  });
  it("credits own goals to the benefiting side and keeps them separate", () => {
    expect(scorersFor(goals, "away")).toEqual([{ name: "Sam", goals: 1, isOwnGoal: true, assists: [] }]);
  });
  it("splits a side's appearances into starters and substitutes", () => {
    const lineup = lineupFor([
      { team_side: "home", player_name: "GK", role: "starter", is_goalkeeper: true, squad_number: 1 },
      { team_side: "home", player_name: "Sub", role: "substitute", is_goalkeeper: false, squad_number: null },
      { team_side: "away", player_name: "Other", role: "starter", is_goalkeeper: false, squad_number: 5 },
    ], "home");
    expect(lineup.starters.map((p) => p.player_name)).toEqual(["GK"]);
    expect(lineup.substitutes.map((p) => p.player_name)).toEqual(["Sub"]);
  });
  it("detects a report that attributes more goals than the confirmed score", () => {
    const report = { published: true, goals, motm: [], lineups: [] };
    expect(reportIsConsistent(report, res("f", 3, 1))).toBe(true);
    expect(reportIsConsistent(report, res("f", 2, 1))).toBe(false);
  });
});

describe("venueDirectionsUrl", () => {
  it("encodes only the venue name and address", () => {
    expect(venueDirectionsUrl({ name: "Bideford Astro", address: "Kingsley Rd & Co" }))
      .toBe("https://www.google.com/maps/search/?api=1&query=Bideford%20Astro%2C%20Kingsley%20Rd%20%26%20Co");
    expect(venueDirectionsUrl({ name: "Pitch 1", address: null })).toBe("https://www.google.com/maps/search/?api=1&query=Pitch%201");
  });
});

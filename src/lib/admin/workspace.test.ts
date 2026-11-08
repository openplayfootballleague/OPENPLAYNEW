import { describe, expect, it } from "vitest";
import { resolveAdminWorkspace } from "./workspace";

const setup = {
  leagues: [
    { id: "league-bideford", location_id: "bideford" },
    { id: "league-barnstaple", location_id: "barnstaple" },
  ],
  seasons: [
    { id: "season-bideford-1", league_id: "league-bideford" },
    { id: "season-bideford-2", league_id: "league-bideford" },
    { id: "season-barnstaple-1", league_id: "league-barnstaple" },
  ],
  seasonTeams: [
    { id: "team-bideford-1", season_id: "season-bideford-1" },
    { id: "team-bideford-2", season_id: "season-bideford-2" },
    { id: "team-barnstaple-1", season_id: "season-barnstaple-1" },
  ],
};

describe("admin location and season workspace", () => {
  it("shows all locations and seasons when both selectors are set to all", () => {
    const result = resolveAdminWorkspace(setup, "all", "all");
    expect(result.workspaceLeagues.map((x) => x.id)).toEqual(["league-bideford", "league-barnstaple"]);
    expect(result.workspaceSeasons.map((x) => x.id)).toEqual(["season-bideford-1", "season-bideford-2", "season-barnstaple-1"]);
    expect(result.workspaceTeams.map((x) => x.id)).toEqual(["team-bideford-1", "team-bideford-2", "team-barnstaple-1"]);
  });

  it("filters leagues, seasons and teams to the selected location", () => {
    const result = resolveAdminWorkspace(setup, "bideford", "all");
    expect(result.workspaceLeagues.map((x) => x.id)).toEqual(["league-bideford"]);
    expect(result.workspaceSeasons.map((x) => x.id)).toEqual(["season-bideford-1", "season-bideford-2"]);
    expect(result.workspaceTeams.map((x) => x.id)).toEqual(["team-bideford-1", "team-bideford-2"]);
  });

  it("filters teams to the selected season without leaking another location", () => {
    const result = resolveAdminWorkspace(setup, "bideford", "season-bideford-2");
    expect(result.workspaceSeasons.map((x) => x.id)).toEqual(["season-bideford-1", "season-bideford-2"]);
    expect(result.workspaceTeams.map((x) => x.id)).toEqual(["team-bideford-2"]);
  });

  it("returns no data for an unknown location", () => {
    const result = resolveAdminWorkspace(setup, "unknown-location", "all");
    expect(result.workspaceLeagues).toEqual([]);
    expect(result.workspaceSeasons).toEqual([]);
    expect(result.workspaceTeams).toEqual([]);
  });

  it("returns no teams when the selected season is outside the selected location", () => {
    const result = resolveAdminWorkspace(setup, "bideford", "season-barnstaple-1");
    expect(result.workspaceLeagues.map((x) => x.id)).toEqual(["league-bideford"]);
    expect(result.workspaceSeasons.map((x) => x.id)).toEqual(["season-bideford-1", "season-bideford-2"]);
    expect(result.workspaceTeams).toEqual([]);
  });
});

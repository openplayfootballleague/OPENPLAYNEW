import { describe, expect, it } from "vitest";
import {
  getPreferredPlayerSeason,
  resolvePlayerCompetitionSelection,
  type PlayerLocationOption,
  type PlayerSeasonOption,
} from "./player-context";

function season(
  id: string,
  status: PlayerSeasonOption["status"],
  starts_on = "2026-01-01",
  location_id = "bideford",
): PlayerSeasonOption {
  return {
    id,
    name: id,
    league_id: "league-1",
    league_name: "Open Play",
    location_id,
    location_name: "Bideford",
    status,
    recruitment_status: status === "registration_open" ? "open" : "closed",
    starts_on,
  };
}

describe("player competition context", () => {
  it("prefers a registration-open season over active and completed seasons", () => {
    const selected = getPreferredPlayerSeason([
      season("completed", "completed", "2026-10-01"),
      season("active", "active", "2026-11-01"),
      season("registration", "registration_open", "2026-12-01"),
    ]);
    expect(selected?.id).toBe("registration");
  });

  it("falls back to an active season when registration is closed", () => {
    const selected = getPreferredPlayerSeason([
      season("completed", "completed"),
      season("active", "active"),
    ]);
    expect(selected?.id).toBe("active");
  });

  it("uses the first published season as a final fallback", () => {
    const selected = getPreferredPlayerSeason([season("completed", "completed")]);
    expect(selected?.id).toBe("completed");
  });

  it("returns null when the selected location has no public seasons", () => {
    expect(getPreferredPlayerSeason([])).toBeNull();
  });

  it("uses a closed upcoming season when no active or registration-open season exists", () => {
    const selected = getPreferredPlayerSeason([
      season("upcoming", "draft", "2027-01-01"),
      season("completed", "completed", "2026-10-01"),
    ]);
    expect(selected?.id).toBe("upcoming");
    expect(selected?.recruitment_status).toBe("closed");
  });

  it("retains a saved location and season only when both are still available", () => {
    const locations: PlayerLocationOption[] = [
      { id: "bideford", name: "Bideford", town: "Bideford", region: "Devon" },
      { id: "barnstaple", name: "Barnstaple", town: "Barnstaple", region: "Devon" },
    ];
    const seasons = [
      season("bideford-active", "active", "2026-11-01", "bideford"),
      season("barnstaple-open", "registration_open", "2026-12-01", "barnstaple"),
    ];

    expect(resolvePlayerCompetitionSelection(locations, seasons, {
      locationId: "barnstaple",
      seasonId: "barnstaple-open",
    })).toEqual({
      selectedLocationId: "barnstaple",
      selectedSeasonId: "barnstaple-open",
    });
  });

  it("does not retain a season belonging to a different saved location", () => {
    const locations: PlayerLocationOption[] = [
      { id: "bideford", name: "Bideford", town: "Bideford", region: "Devon" },
      { id: "barnstaple", name: "Barnstaple", town: "Barnstaple", region: "Devon" },
    ];
    const seasons = [
      season("bideford-active", "active", "2026-11-01", "bideford"),
      season("barnstaple-open", "registration_open", "2026-12-01", "barnstaple"),
    ];

    expect(resolvePlayerCompetitionSelection(locations, seasons, {
      locationId: "bideford",
      seasonId: "barnstaple-open",
    })).toEqual({
      selectedLocationId: "bideford",
      selectedSeasonId: "bideford-active",
    });
  });

  it("falls back to the first available location and its preferred season when saved context is stale", () => {
    const locations: PlayerLocationOption[] = [
      { id: "bideford", name: "Bideford", town: "Bideford", region: "Devon" },
    ];
    const seasons = [
      season("completed", "completed", "2026-10-01"),
      season("active", "active", "2026-11-01"),
    ];

    expect(resolvePlayerCompetitionSelection(locations, seasons, {
      locationId: "inactive-location",
      seasonId: "removed-season",
    })).toEqual({
      selectedLocationId: "bideford",
      selectedSeasonId: "active",
    });
  });

  it("returns an empty selection when no active locations are available", () => {
    expect(resolvePlayerCompetitionSelection([], [], {
      locationId: "bideford",
      seasonId: "active",
    })).toEqual({
      selectedLocationId: "",
      selectedSeasonId: "",
    });
  });
});

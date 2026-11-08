import { describe, expect, it } from "vitest";
import { getPreferredPlayerSeason, type PlayerSeasonOption } from "./player-context";

function season(id: string, status: PlayerSeasonOption["status"], starts_on = "2026-01-01"): PlayerSeasonOption {
  return {
    id,
    name: id,
    league_id: "league-1",
    league_name: "Open Play",
    location_id: "bideford",
    location_name: "Bideford",
    status,
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
});

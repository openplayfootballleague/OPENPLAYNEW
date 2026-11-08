import { describe, expect, it, vi } from "vitest";
import {
  captureOpenPlayEvent,
  sanitizeAnalyticsProperties,
  type AnalyticsCaptureClient,
} from "./events";

const locationId = "123e4567-e89b-42d3-a456-426614174000";

describe("Open Play analytics property governance", () => {
  it("keeps only allow-listed, validated, non-sensitive properties", () => {
    expect(sanitizeAnalyticsProperties({
      route_category: "player_hub",
      feature: "player_hub",
      device_type: "mobile",
      app_version: "1.2.3",
      competition_format: "six_a_side",
      outcome: "success",
      error_code: "network_error",
      location_id: locationId,
      email: "person@example.com",
      phone: "07123456789",
      full_name: "Example Player",
      message_body: "private message",
      raw_url: "https://example.test/path?token=secret",
      arbitrary: "unreviewed",
    })).toEqual({
      route_category: "player_hub",
      feature: "player_hub",
      device_type: "mobile",
      app_version: "1.2.3",
      competition_format: "six_a_side",
      outcome: "success",
      error_code: "network_error",
      location_id: locationId,
    });
  });

  it("rejects invalid enum values, malformed IDs and arbitrary error text", () => {
    expect(sanitizeAnalyticsProperties({
      route_category: "/player?email=person@example.com",
      feature: "custom-user-feature",
      device_type: "iPhone 16",
      competition_format: "five_a_side",
      outcome: "success; user@example.com",
      error_code: "Error: email person@example.com",
      app_version: "1.2",
      season_id: "not-a-uuid",
    })).toEqual({});
  });

  it("drops null and undefined properties", () => {
    expect(sanitizeAnalyticsProperties({
      feature: null,
      route_category: undefined,
    })).toEqual({});
  });
});

describe("consent and role-gated analytics capture", () => {
  const client: AnalyticsCaptureClient = { capture: vi.fn() };

  it("does not capture before explicit consent", () => {
    expect(captureOpenPlayEvent(client, "unset", false, "player", "player_profile_completed")).toBe(false);
    expect(client.capture).not.toHaveBeenCalled();
  });

  it("does not capture when consent is denied or GPC is enabled", () => {
    expect(captureOpenPlayEvent(client, "denied", false, "player", "player_profile_completed")).toBe(false);
    expect(captureOpenPlayEvent(client, "granted", true, "player", "player_profile_completed")).toBe(false);
    expect(client.capture).not.toHaveBeenCalled();
  });

  it.each(["admin", "super_admin", "finance_admin", "league_admin", "unknown"] as const)(
    "excludes privileged or unverified actor %s",
    actor => {
      expect(captureOpenPlayEvent(client, "granted", false, actor, "feature_opened")).toBe(false);
    },
  );

  it("captures a consented player event with sanitised properties only", () => {
    const capture = vi.fn();
    const allowedClient: AnalyticsCaptureClient = { capture };
    expect(captureOpenPlayEvent(
      allowedClient,
      "granted",
      false,
      "player",
      "fixture_viewed",
      { feature: "fixtures", location_id: locationId, email: "private@example.com" },
    )).toBe(true);
    expect(capture).toHaveBeenCalledWith("fixture_viewed", {
      feature: "fixtures",
      location_id: locationId,
    });
  });

  it("allows anonymous product events after explicit consent", () => {
    const capture = vi.fn();
    expect(captureOpenPlayEvent(
      { capture },
      "granted",
      false,
      "anonymous",
      "location_selected",
      { route_category: "home" },
    )).toBe(true);
    expect(capture).toHaveBeenCalledOnce();
  });

  it("fails closed when no SDK client is available", () => {
    expect(captureOpenPlayEvent(null, "granted", false, "player", "fixture_viewed")).toBe(false);
  });
});

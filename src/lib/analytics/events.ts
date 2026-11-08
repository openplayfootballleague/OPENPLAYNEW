import { isAnalyticsAllowed, type AnalyticsConsent } from "./consent";

export const OPEN_PLAY_ANALYTICS_EVENTS = [
  "account_signup_started",
  "account_signup_completed",
  "account_verification_completed",
  "player_registration_started",
  "player_registration_submitted",
  "player_profile_completed",
  "onboarding_completed",
  "team_registration_started",
  "team_registration_submitted",
  "player_join_request_submitted",
  "location_selected",
  "location_switched",
  "season_selected",
  "season_switched",
  "navigation_section_viewed",
  "fixture_viewed",
  "result_viewed",
  "league_table_viewed",
  "team_profile_viewed",
  "player_profile_viewed",
  "gallery_viewed",
  "announcement_viewed",
  "feature_opened",
  "feature_action_completed",
  "feature_action_failed",
  "application_error",
  "workflow_error",
  "data_load_failed",
] as const;

export type OpenPlayAnalyticsEvent = (typeof OPEN_PLAY_ANALYTICS_EVENTS)[number];
export type AnalyticsActor =
  | "anonymous"
  | "account_user"
  | "player"
  | "captain"
  | "admin"
  | "super_admin"
  | "finance_admin"
  | "league_admin"
  | "unknown";

export type AnalyticsProperties = Record<string, string | number | boolean | null | undefined>;
export type SafeAnalyticsProperties = Record<string, string | number | boolean>;

export interface AnalyticsCaptureClient {
  capture(event: OpenPlayAnalyticsEvent, properties?: SafeAnalyticsProperties): void;
}

const ALLOWED_PROPERTIES = new Set([
  "route_category",
  "feature",
  "device_type",
  "app_version",
  "competition_format",
  "outcome",
  "error_code",
  "location_id",
  "league_id",
  "season_id",
]);

const ROUTE_CATEGORIES = new Set([
  "home", "player_hub", "match_centre", "teams", "registration",
  "notifications", "gallery", "account", "other",
]);
const FEATURES = new Set([
  "player_hub", "match_centre", "team_directory", "team_registration",
  "player_registration", "team_membership", "fixtures", "results",
  "league_table", "gallery", "announcements", "location_selector",
  "season_selector", "notifications", "profile",
]);
const DEVICE_TYPES = new Set(["mobile", "tablet", "desktop", "unknown"]);
const COMPETITION_FORMATS = new Set(["six_a_side", "seven_a_side"]);
const OUTCOMES = new Set(["success", "failure", "cancelled"]);
const ERROR_CODES = new Set([
  "network_error", "validation_error", "permission_denied",
  "not_found", "rate_limited", "unexpected_error",
]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const APP_VERSION = /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/;

function safeProperty(key: string, value: AnalyticsProperties[string]): string | number | boolean | undefined {
  if (!ALLOWED_PROPERTIES.has(key) || value === null || value === undefined) return undefined;
  if (key === "route_category") return typeof value === "string" && ROUTE_CATEGORIES.has(value) ? value : undefined;
  if (key === "feature") return typeof value === "string" && FEATURES.has(value) ? value : undefined;
  if (key === "device_type") return typeof value === "string" && DEVICE_TYPES.has(value) ? value : undefined;
  if (key === "competition_format") return typeof value === "string" && COMPETITION_FORMATS.has(value) ? value : undefined;
  if (key === "outcome") return typeof value === "string" && OUTCOMES.has(value) ? value : undefined;
  if (key === "error_code") return typeof value === "string" && ERROR_CODES.has(value) ? value : undefined;
  if (key === "app_version") return typeof value === "string" && APP_VERSION.test(value) ? value : undefined;
  if (key === "location_id" || key === "league_id" || key === "season_id") {
    return typeof value === "string" && UUID.test(value) ? value : undefined;
  }
  return undefined;
}

/** Allow-list event properties; arbitrary values and direct identifiers are discarded. */
export function sanitizeAnalyticsProperties(properties: AnalyticsProperties = {}): SafeAnalyticsProperties {
  const safe: SafeAnalyticsProperties = {};
  for (const [key, value] of Object.entries(properties)) {
    const result = safeProperty(key, value);
    if (result !== undefined) safe[key] = result;
  }
  return safe;
}

/**
 * Capture only after explicit consent, without GPC, and only for public/player
 * actors. Admin and finance activity is deliberately excluded from product analytics.
 */
export function captureOpenPlayEvent(
  client: AnalyticsCaptureClient | null | undefined,
  consent: AnalyticsConsent,
  globalPrivacyControl: boolean,
  actor: AnalyticsActor,
  event: OpenPlayAnalyticsEvent,
  properties: AnalyticsProperties = {},
): boolean {
  if (!client || !isAnalyticsAllowed(consent, globalPrivacyControl)) return false;
  if (actor !== "anonymous" && actor !== "account_user" && actor !== "player" && actor !== "captain") return false;
  client.capture(event, sanitizeAnalyticsProperties(properties));
  return true;
}

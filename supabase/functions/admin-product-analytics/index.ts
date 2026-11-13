import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  buildProductAnalyticsQueries,
  validateProductAnalyticsFilters,
  rowsAsObjects,
} from "./policy.ts";

type Setup = {
  locations?: Array<{ id: string }>;
  leagues?: Array<{ id: string; location_id: string }>;
  seasons?: Array<{ id: string; league_id: string; location_id: string }>;
};

type RequestFilters = {
  fromDate?: unknown;
  toDate?: unknown;
  locationId?: unknown;
  leagueId?: unknown;
  seasonId?: unknown;
};

const json = (body: unknown, status = 200, origin = "*") =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Vary": "Origin",
    },
  });

function dateOnly(value: Date) {
  return value.toISOString().slice(0, 10);
}

function defaultRange() {
  const to = new Date();
  const from = new Date(to);
  from.setUTCDate(from.getUTCDate() - 83);
  return { fromDate: dateOnly(from), toDate: dateOnly(to) };
}

function isOptionalId(value: unknown): value is string | undefined {
  return value === undefined || value === null || value === "" ||
    (typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value));
}

function safeNumber(value: unknown) {
  const number = Number(value ?? 0);
  return Number.isFinite(number) && number >= 0 ? number : 0;
}

async function runHogQL(
  host: string,
  projectId: string,
  apiKey: string,
  query: string,
  name: string,
) {
  const response = await fetch(`${host}/api/projects/${projectId}/query/`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ query: { kind: "HogQLQuery", query }, name }),
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error("PostHog query failed");
  const payload = await response.json() as { results?: unknown; error?: unknown; detail?: unknown };
  if (payload.error || payload.detail || !Array.isArray(payload.results)) {
    throw new Error("PostHog query returned an invalid response");
  }
  return payload.results;
}

Deno.serve(async (request: Request) => {
  const configuredOrigin = Deno.env.get("APP_ORIGIN")?.trim();
  const requestOrigin = request.headers.get("origin") ?? "";
  const localOrigin = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(requestOrigin);
  const allowedOrigin = configuredOrigin
    ? (requestOrigin === configuredOrigin || localOrigin ? requestOrigin : configuredOrigin)
    : "*";

  if (request.method === "OPTIONS") return json({ ok: true }, 200, allowedOrigin);
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405, allowedOrigin);
  if (configuredOrigin && requestOrigin && requestOrigin !== configuredOrigin && !localOrigin) {
    return json({ error: "Origin not allowed" }, 403, allowedOrigin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const posthogKey = Deno.env.get("POSTHOG_PERSONAL_API_KEY");
  const projectId = Deno.env.get("POSTHOG_PROJECT_ID");
  const hostValue = Deno.env.get("POSTHOG_APP_HOST") ?? "https://eu.posthog.com";
  if (!supabaseUrl || !anonKey) {
    return json({ error: "Administrator analytics service is not configured" }, 503, allowedOrigin);
  }
  const token = (request.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "Sign in to continue" }, 401, allowedOrigin);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "Your session is invalid or expired" }, 401, allowedOrigin);

  let input: RequestFilters;
  try {
    input = await request.json() as RequestFilters;
  } catch {
    return json({ error: "Invalid request body" }, 400, allowedOrigin);
  }
  if (!isOptionalId(input.locationId) || !isOptionalId(input.leagueId) || !isOptionalId(input.seasonId)) {
    return json({ error: "Invalid reporting context" }, 400, allowedOrigin);
  }

  const defaults = defaultRange();
  const fromDate = typeof input.fromDate === "string" && input.fromDate ? input.fromDate : defaults.fromDate;
  const toDate = typeof input.toDate === "string" && input.toDate ? input.toDate : defaults.toDate;

  // This RPC is the authority for the caller's administrator role and accessible
  // competition scope. Never trust location, league or season IDs supplied by UI.
  const { data: setupData, error: setupError } = await userClient.rpc("get_admin_competition_setup");
  if (setupError || !setupData || typeof setupData !== "object") {
    return json({ error: "Administrator reporting access is required" }, 403, allowedOrigin);
  }
  const setup = setupData as Setup;
  const locations = Array.isArray(setup.locations) ? setup.locations : [];
  const leagues = Array.isArray(setup.leagues) ? setup.leagues : [];
  const seasons = Array.isArray(setup.seasons) ? setup.seasons : [];

  if (input.locationId && !locations.some((item) => item.id === input.locationId)) {
    return json({ error: "You do not have access to this location" }, 403, allowedOrigin);
  }
  const scopedLeagues = leagues.filter((item) =>
    (!input.locationId || item.location_id === input.locationId) &&
    (!input.leagueId || item.id === input.leagueId),
  );
  if (input.leagueId && !scopedLeagues.some((item) => item.id === input.leagueId)) {
    return json({ error: "You do not have access to this league" }, 403, allowedOrigin);
  }
  const leagueIds = new Set(scopedLeagues.map((item) => item.id));
  const scopedSeasons = seasons.filter((item) =>
    leagueIds.has(item.league_id) &&
    (!input.seasonId || item.id === input.seasonId),
  );
  if (input.seasonId && !scopedSeasons.some((item) => item.id === input.seasonId)) {
    return json({ error: "You do not have access to this season" }, 403, allowedOrigin);
  }

  const filters = {
    fromDate,
    toDate,
    seasonIds: scopedSeasons.map((item) => item.id),
  };
  const validationError = validateProductAnalyticsFilters(filters);
  if (validationError) {
    return json({ error: validationError }, 400, allowedOrigin);
  }
  if (filters.seasonIds.length === 0) {
    return json({
      status: "no_data",
      range: { fromDate, toDate },
      weeklyActivity: [],
      retention: [],
      features: [],
      definitions: {
        engagedUser: "A consented, authenticated player who viewed available fixtures, results, league standings, player statistics or the approved team directory.",
        retention: "Weekly recurring return to one of those meaningful competition-content actions. Cohort entry is first observed activity within the selected reporting window.",
      },
    }, 200, allowedOrigin);
  }

  if (!posthogKey || !projectId || !/^\\d+$/.test(projectId)) {
    return json({
      error: "PostHog reporting is not configured. Add a project-scoped personal API key with query read access and the PostHog project ID to Supabase function secrets.",
      code: "posthog_not_configured",
    }, 503, allowedOrigin);
  }

  let host: string;
  try {
    const parsed = new URL(hostValue);
    const supportedCloudHost = parsed.hostname === "eu.posthog.com" || parsed.hostname === "us.posthog.com";
    if (parsed.protocol !== "https:" || !supportedCloudHost || parsed.username || parsed.password ||
      parsed.pathname !== "/" || parsed.search || parsed.hash) {
      throw new Error("Invalid PostHog host");
    }
    host = parsed.origin;
  } catch {
    return json({ error: "PostHog reporting host is invalid" }, 503, allowedOrigin);
  }

  const posthogQueries = buildProductAnalyticsQueries(filters);
  try {
    const [weeklyResult, retentionResult, featureResult] = await Promise.all([
      runHogQL(host, projectId, posthogKey, posthogQueries.weeklyActivity, "Open Play weekly engaged users"),
      runHogQL(host, projectId, posthogKey, posthogQueries.retention, "Open Play weekly engagement retention"),
      runHogQL(host, projectId, posthogKey, posthogQueries.featurePerformance, "Open Play feature performance"),
    ]);

    const weeklyActivity = rowsAsObjects(weeklyResult, ["week_start", "active_users", "value_actions"]).map((row) => ({
      week_start: String(row.week_start ?? ""),
      active_users: safeNumber(row.active_users),
      value_actions: safeNumber(row.value_actions),
    }));
    const retention = rowsAsObjects(retentionResult, [
      "cohort_week", "weeks_since_start", "cohort_users", "retained_users", "retention_rate",
    ]).map((row) => ({
      cohort_week: String(row.cohort_week ?? ""),
      weeks_since_start: safeNumber(row.weeks_since_start),
      cohort_users: safeNumber(row.cohort_users),
      retained_users: safeNumber(row.retained_users),
      retention_rate: Math.min(100, safeNumber(row.retention_rate)),
    }));
    const features = rowsAsObjects(featureResult, ["feature", "unique_users", "value_actions"])
      .filter((row) => ["fixtures", "results", "league_table", "player_statistics", "team_directory"].includes(String(row.feature)))
      .map((row) => ({
        feature: String(row.feature),
        unique_users: safeNumber(row.unique_users),
        value_actions: safeNumber(row.value_actions),
      }));

    return json({
      status: weeklyActivity.length || retention.length || features.length ? "ready" : "no_data",
      range: { fromDate, toDate },
      weeklyActivity,
      retention,
      features,
      definitions: {
        engagedUser: "A consented, authenticated player who viewed available fixtures, results, league standings, player statistics or the approved team directory.",
        retention: "Weekly recurring return to one of those meaningful competition-content actions. Cohort entry is first observed activity within the selected reporting window; the current incomplete week is excluded.",
        featurePerformance: "Unique consented players and meaningful content views by feature. It is not a count of raw page loads.",
      },
    }, 200, allowedOrigin);
  } catch {
    return json({ error: "PostHog product analytics could not be loaded. Check the read-only query credential and project configuration." }, 502, allowedOrigin);
  }
});

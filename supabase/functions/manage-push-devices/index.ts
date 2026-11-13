import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { sanitisePushDevice } from "../_shared/onesignal-push-policy.ts";

type OneSignalSubscription = {
  id?: unknown;
  type?: unknown;
  enabled?: unknown;
  device_model?: unknown;
  device_os?: unknown;
  created_at?: unknown;
  last_active?: unknown;
};

function json(body: unknown, status = 200, allowedOrigin = "null") {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Access-Control-Allow-Origin": allowedOrigin,
      "Vary": "Origin",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-api-version",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Content-Type": "application/json",
    },
  });
}

function isPushSubscription(subscription: OneSignalSubscription): boolean {
  const type = typeof subscription.type === "string" ? subscription.type.toLowerCase() : "";
  return type.length > 0 && type !== "email" && type !== "sms";
}

async function getOneSignalUser(appId: string, apiKey: string, externalId: string) {
  const response = await fetch(
    `https://api.onesignal.com/apps/${appId}/users/by/external_id/${encodeURIComponent(externalId)}`,
    { headers: { Authorization: `Key ${apiKey}` } },
  );
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`OneSignal user lookup returned ${response.status}`);
  const body = await response.json() as { subscriptions?: unknown };
  return Array.isArray(body.subscriptions)
    ? body.subscriptions.filter((item): item is OneSignalSubscription => Boolean(item && typeof item === "object"))
    : [];
}

async function deleteOneSignalSubscription(appId: string, apiKey: string, subscriptionId: string) {
  const response = await fetch(
    `https://api.onesignal.com/apps/${appId}/subscriptions/${subscriptionId}`,
    { method: "DELETE", headers: { Authorization: `Key ${apiKey}` } },
  );
  if (!response.ok && response.status !== 404) {
    throw new Error(`OneSignal subscription removal returned ${response.status}`);
  }
}

Deno.serve(async (request: Request) => {
  const configuredOrigin = Deno.env.get("APP_ORIGIN");
  let allowedOrigin = "null";
  const respond = (body: unknown, status = 200) => json(body, status, allowedOrigin);
  try {
    if (configuredOrigin) {
      const parsedOrigin = new URL(configuredOrigin);
      if ((parsedOrigin.protocol !== "https:" && parsedOrigin.hostname !== "localhost" && parsedOrigin.hostname !== "127.0.0.1") ||
          parsedOrigin.pathname !== "/" || parsedOrigin.search || parsedOrigin.hash || parsedOrigin.username || parsedOrigin.password) {
        return respond({ error: "Push app origin is not configured correctly" }, 503);
      }
      allowedOrigin = parsedOrigin.origin;
    }
  } catch {
    return respond({ error: "Push app origin is not configured correctly" }, 503);
  }
  if (request.method === "OPTIONS") return respond({ ok: true });
  if (!configuredOrigin) return respond({ error: "Push app origin is not configured" }, 503);
  const requestOrigin = request.headers.get("Origin");
  if (requestOrigin && requestOrigin !== allowedOrigin) return respond({ error: "Origin not allowed" }, 403);
  if (request.method !== "POST") return respond({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) return respond({ error: "Authentication required" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const appId = Deno.env.get("ONESIGNAL_APP_ID");
  const apiKey = Deno.env.get("ONESIGNAL_REST_API_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) return respond({ error: "Push device service is not configured" }, 503);
  if (!appId || !apiKey) return respond({ error: "OneSignal push is not configured. Add the app ID and REST API key to Supabase Function Secrets." }, 503);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser(token);
  if (authError || !user) return respond({ error: "A valid signed-in account is required" }, 401);

  let input: { action?: unknown; subscriptionId?: unknown };
  try {
    const body = await request.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) return respond({ error: "Invalid request body" }, 400);
    input = body as { action?: unknown; subscriptionId?: unknown };
  } catch {
    return respond({ error: "Invalid request body" }, 400);
  }

  const action = input.action;
  if (action !== "list" && action !== "enable" && action !== "disable" && action !== "revoke") {
    return respond({ error: "Unsupported push device action" }, 400);
  }
  if (action === "revoke" && (typeof input.subscriptionId !== "string" || !/^[0-9a-f-]{36}$/i.test(input.subscriptionId))) {
    return respond({ error: "A valid subscription ID is required" }, 400);
  }

  const service = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: profile, error: profileError } = await service.from("profiles")
    .select("account_retention_status").eq("id", user.id).maybeSingle();
  if (profileError || !profile) return respond({ error: "Unable to verify account status" }, 403);
  if (action === "enable" && profile.account_retention_status !== "active") {
    return respond({ error: "Push notifications are unavailable for this account status" }, 403);
  }

  try {
    const subscriptions = await getOneSignalUser(appId, apiKey, user.id) ?? [];
    const pushSubscriptions = subscriptions.filter(isPushSubscription);

    if (action === "list") {
      const { data: preference } = await service.from("notification_preferences")
        .select("push_enabled").eq("user_id", user.id).maybeSingle();
      return respond({
        pushEnabled: preference?.push_enabled === true,
        devices: pushSubscriptions.map(sanitisePushDevice).filter((item) => item !== null),
      });
    }

    if (action === "enable") {
      if (!pushSubscriptions.some((item) => item.enabled === true)) {
        return respond({ error: "Allow notifications on this browser first, then try again." }, 409);
      }
      const { error } = await service.from("notification_preferences").upsert(
        { user_id: user.id, push_enabled: true, updated_at: new Date().toISOString() },
        { onConflict: "user_id" },
      );
      if (error) return respond({ error: "Unable to save push notification preference" }, 500);
      return respond({ pushEnabled: true, devices: pushSubscriptions.map(sanitisePushDevice).filter((item) => item !== null) });
    }

    if (action === "disable") {
      const { error: preferenceError } = await service.from("notification_preferences").upsert(
        { user_id: user.id, push_enabled: false, updated_at: new Date().toISOString() },
        { onConflict: "user_id" },
      );
      if (preferenceError) return respond({ error: "Unable to disable push notifications" }, 500);
      const results = await Promise.allSettled(
        pushSubscriptions.filter((item) => typeof item.id === "string")
          .map((item) => deleteOneSignalSubscription(appId, apiKey, item.id as string)),
      );
      if (results.some((result) => result.status === "rejected")) {
        return respond({ error: "Push was disabled for this account, but one or more device subscriptions could not be removed. Try again." }, 502);
      }
      return respond({ pushEnabled: false, devices: [] });
    }

    const subscriptionId = input.subscriptionId as string;
    const ownedSubscription = pushSubscriptions.find((item) => item.id === subscriptionId);
    if (!ownedSubscription) return respond({ error: "That device is not registered to this account" }, 404);

    await deleteOneSignalSubscription(appId, apiKey, subscriptionId);
    const remaining = pushSubscriptions.filter((item) => item.id !== subscriptionId && item.enabled === true);
    const pushEnabled = remaining.length > 0;
    const { error: preferenceError } = await service.from("notification_preferences").upsert(
      { user_id: user.id, push_enabled: pushEnabled, updated_at: new Date().toISOString() },
      { onConflict: "user_id" },
    );
    if (preferenceError) return respond({ error: "Device removed but push preference could not be updated" }, 500);

    return respond({
      pushEnabled,
      devices: remaining.map(sanitisePushDevice).filter((item) => item !== null),
    });
  } catch {
    return respond({ error: "Unable to manage OneSignal push devices right now" }, 502);
  }
});

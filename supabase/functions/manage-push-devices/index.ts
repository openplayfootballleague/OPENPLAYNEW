import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { sanitisePushDevice } from "../deliver-notifications/push-policy.ts";

type OneSignalSubscription = {
  id?: unknown;
  type?: unknown;
  enabled?: unknown;
  device_model?: unknown;
  device_os?: unknown;
  created_at?: unknown;
  last_active?: unknown;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Content-Type": "application/json",
    },
  });
}

function isPushSubscription(subscription: OneSignalSubscription): boolean {
  const type = typeof subscription.type === "string" ? subscription.type.toLowerCase() : "";
  return type !== "email" && type !== "sms";
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
  if (request.method === "OPTIONS") return json({ ok: true });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Authentication required" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const appId = Deno.env.get("ONESIGNAL_APP_ID");
  const apiKey = Deno.env.get("ONESIGNAL_REST_API_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) return json({ error: "Push device service is not configured" }, 503);
  if (!appId || !apiKey) return json({ error: "OneSignal push is not configured. Add the app ID and REST API key to Supabase Function Secrets." }, 503);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser(token);
  if (authError || !user) return json({ error: "A valid signed-in account is required" }, 401);

  let input: { action?: unknown; subscriptionId?: unknown };
  try {
    const body = await request.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) return json({ error: "Invalid request body" }, 400);
    input = body as { action?: unknown; subscriptionId?: unknown };
  } catch {
    return json({ error: "Invalid request body" }, 400);
  }

  const action = input.action;
  if (action !== "list" && action !== "enable" && action !== "disable" && action !== "revoke") {
    return json({ error: "Unsupported push device action" }, 400);
  }
  if (action === "revoke" && (typeof input.subscriptionId !== "string" || !/^[0-9a-f-]{36}$/i.test(input.subscriptionId))) {
    return json({ error: "A valid subscription ID is required" }, 400);
  }

  const service = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const subscriptions = await getOneSignalUser(appId, apiKey, user.id) ?? [];
    const pushSubscriptions = subscriptions.filter(isPushSubscription);

    if (action === "list") {
      const { data: preference } = await service.from("notification_preferences")
        .select("push_enabled").eq("user_id", user.id).maybeSingle();
      return json({
        pushEnabled: preference?.push_enabled === true,
        devices: pushSubscriptions.map(sanitisePushDevice).filter((item) => item !== null),
      });
    }

    if (action === "enable") {
      if (!pushSubscriptions.some((item) => item.enabled === true)) {
        return json({ error: "Allow notifications on this browser first, then try again." }, 409);
      }
      const { error } = await service.from("notification_preferences").upsert(
        { user_id: user.id, push_enabled: true },
        { onConflict: "user_id" },
      );
      if (error) return json({ error: "Unable to save push notification preference" }, 500);
      return json({ pushEnabled: true, devices: pushSubscriptions.map(sanitisePushDevice).filter((item) => item !== null) });
    }

    if (action === "disable") {
      const { error: preferenceError } = await service.from("notification_preferences").upsert(
        { user_id: user.id, push_enabled: false },
        { onConflict: "user_id" },
      );
      if (preferenceError) return json({ error: "Unable to disable push notifications" }, 500);
      const results = await Promise.allSettled(
        pushSubscriptions.filter((item) => typeof item.id === "string")
          .map((item) => deleteOneSignalSubscription(appId, apiKey, item.id as string)),
      );
      if (results.some((result) => result.status === "rejected")) {
        return json({ error: "Push was disabled for this account, but one or more device subscriptions could not be removed. Try again." }, 502);
      }
      return json({ pushEnabled: false, devices: [] });
    }

    const subscriptionId = input.subscriptionId as string;
    const ownedSubscription = pushSubscriptions.find((item) => item.id === subscriptionId);
    if (!ownedSubscription) return json({ error: "That device is not registered to this account" }, 404);

    await deleteOneSignalSubscription(appId, apiKey, subscriptionId);
    const remaining = pushSubscriptions.filter((item) => item.id !== subscriptionId && item.enabled === true);
    const pushEnabled = remaining.length > 0;
    const { error: preferenceError } = await service.from("notification_preferences").upsert(
      { user_id: user.id, push_enabled: pushEnabled },
      { onConflict: "user_id" },
    );
    if (preferenceError) return json({ error: "Device removed but push preference could not be updated" }, 500);

    return json({
      pushEnabled,
      devices: remaining.map(sanitisePushDevice).filter((item) => item !== null),
    });
  } catch {
    return json({ error: "Unable to manage OneSignal push devices right now" }, 502);
  }
});

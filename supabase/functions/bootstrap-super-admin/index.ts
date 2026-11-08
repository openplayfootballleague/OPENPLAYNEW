import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Headers": "authorization, content-type, x-openplay-bootstrap-token",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function constantTimeEqual(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  let difference = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let i = 0; i < length; i += 1) {
    difference |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return difference === 0;
}

function json(status: number, body: Record<string, unknown>, origin: string | null, allowedOrigin: string) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Access-Control-Allow-Origin": origin && origin === allowedOrigin ? origin : "null",
      Vary: "Origin",
    },
  });
}

Deno.serve(async (request: Request) => {
  const allowedOrigin = Deno.env.get("OPENPLAY_APP_ORIGIN") ?? "";
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") {
    if (!allowedOrigin || origin !== allowedOrigin) return new Response("Forbidden", { status: 403 });
    return new Response("ok", { headers: { ...corsHeaders, "Access-Control-Allow-Origin": allowedOrigin, Vary: "Origin" } });
  }
  if (request.method !== "POST") return json(405, { error: "Method not allowed" }, origin, allowedOrigin);
  if (!allowedOrigin || origin !== allowedOrigin) return json(403, { error: "Origin not allowed" }, origin, allowedOrigin);

  const expectedEmail = (Deno.env.get("OPENPLAY_BOOTSTRAP_OWNER_EMAIL") ?? "").trim().toLowerCase();
  const expectedToken = Deno.env.get("OPENPLAY_BOOTSTRAP_TOKEN") ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!expectedEmail || expectedToken.length < 32 || !supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(503, { error: "Bootstrap is not configured" }, origin, allowedOrigin);
  }

  const suppliedToken = request.headers.get("x-openplay-bootstrap-token") ?? "";
  if (!constantTimeEqual(suppliedToken, expectedToken)) {
    return json(403, { error: "Bootstrap authorization failed" }, origin, allowedOrigin);
  }

  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return json(401, { error: "Authentication required" }, origin, allowedOrigin);
  }

  const caller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await caller.auth.getUser();
  if (userError || !user || user.email?.trim().toLowerCase() !== expectedEmail || !user.email_confirmed_at) {
    return json(403, { error: "Only the configured, email-verified bootstrap owner may continue" }, origin, allowedOrigin);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await admin.rpc("bootstrap_initial_super_admin", {
    p_target_user_id: user.id,
    p_bootstrap_actor_user_id: user.id,
  });
  if (error) {
    return json(409, { error: "Initial administrator bootstrap was not completed" }, origin, allowedOrigin);
  }

  return json(200, { ok: true, role: "super_admin", user_id: user.id, result: data }, origin, allowedOrigin);
});

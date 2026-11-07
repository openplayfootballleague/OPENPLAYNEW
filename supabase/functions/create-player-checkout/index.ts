import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": Deno.env.get("APP_ORIGIN") ?? "https://openplayfootball.lovable.app",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const origin = req.headers.get("origin");
  const allowedOrigin = Deno.env.get("APP_ORIGIN") ?? "https://openplayfootball.lovable.app";
  if (origin && origin !== allowedOrigin) return json({ error: "Origin not allowed" }, 403);

  const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const appOrigin = Deno.env.get("APP_ORIGIN");
  if (!stripeKey || !supabaseUrl || !anonKey || !serviceKey || !appOrigin) {
    return json({ error: "Payment service is not configured" }, 503);
  }
  if (!stripeKey.startsWith("sk_test_")) return json({ error: "Only Stripe test mode is enabled" }, 503);

  const token = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Sign in to continue" }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "Your session is invalid or expired" }, 401);

  let input: { fixture_id?: string; season_team_id?: string };
  try { input = await req.json(); } catch { return json({ error: "Invalid request body" }, 400); }
  if (!input.fixture_id || !input.season_team_id) return json({ error: "Fixture and team are required" }, 400);

  const { data: paymentRows, error: paymentError } = await userClient.rpc("create_player_fixture_payment", {
    p_fixture_id: input.fixture_id,
    p_season_team_id: input.season_team_id,
  });
  if (paymentError) return json({ error: paymentError.message }, 400);
  const payment = Array.isArray(paymentRows) ? paymentRows[0] : paymentRows;
  if (!payment?.payment_record_id || !Number.isSafeInteger(payment.amount_pence)) {
    return json({ error: "Unable to prepare this payment" }, 500);
  }
  if (payment.already_paid) return json({ paid: true, message: "This fixture has already been paid." });

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: record, error: recordError } = await admin.from("payment_records")
    .select("id,amount_pence,currency,status,stripe_checkout_session_id")
    .eq("id", payment.payment_record_id).single();
  if (recordError || !record) return json({ error: "Payment record could not be loaded" }, 500);
  if (record.status === "paid") return json({ paid: true, message: "This fixture has already been paid." });
  if (record.status !== "pending" && record.status !== "processing") {
    return json({ error: "This payment cannot be checked out" }, 409);
  }

  const form = new URLSearchParams();
  form.set("mode", "payment");
  form.set("success_url", `${appOrigin}/payment/success?session_id={CHECKOUT_SESSION_ID}`);
  form.set("cancel_url", `${appOrigin}/payment/cancelled?payment_id=${record.id}`);
  form.set("client_reference_id", record.id);
  form.set("line_items[0][quantity]", "1");
  form.set("line_items[0][price_data][currency]", record.currency);
  form.set("line_items[0][price_data][unit_amount]", String(record.amount_pence));
  form.set("line_items[0][price_data][product_data][name]", "Open Play fixture match fee");
  form.set("line_items[0][price_data][product_data][description]", "One-off player match fee");
  form.set("metadata[payment_record_id]", record.id);
  form.set("metadata[player_user_id]", authData.user.id);
  form.set("payment_intent_data[metadata][payment_record_id]", record.id);

  const stripeResponse = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${stripeKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": `openplay-checkout-${record.id}`,
    },
    body: form,
  });
  const session = await stripeResponse.json().catch(() => ({}));
  if (!stripeResponse.ok || !session.url) {
    return json({ error: "Stripe could not create a Checkout session" }, 502);
  }

  const { error: updateError } = await admin.from("payment_records").update({
    status: "processing",
    stripe_checkout_session_id: session.id,
  }).eq("id", record.id).in("status", ["pending", "processing"]);
  if (updateError) return json({ error: "Checkout was created but payment state could not be saved. Contact Open Play before retrying." }, 500);

  return json({ checkout_url: session.url, payment_record_id: record.id });
});

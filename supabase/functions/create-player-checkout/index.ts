import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { classifyCheckoutWithoutSession, classifyExistingCheckoutSession, nextCheckoutAttempt } from "../../../src/lib/payments/stripe-settlement.ts";

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
  const { data: loadedRecord, error: recordError } = await admin.from("payment_records")
    .select("id,amount_pence,currency,status,stripe_checkout_session_id,checkout_attempt")
    .eq("id", payment.payment_record_id).single();
  if (recordError || !loadedRecord) return json({ error: "Payment record could not be loaded" }, 500);
  let record = loadedRecord;
  if (record.status === "paid") return json({ paid: true, message: "This fixture has already been paid." });

  // Reuse an existing open session rather than creating duplicate Checkout pages.
  // A new attempt is claimed with a compare-and-set update, so simultaneous
  // retries cannot increment the same attempt twice.
  if (record.stripe_checkout_session_id) {
    const existingResponse = await fetch(
      `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(record.stripe_checkout_session_id)}`,
      { headers: { Authorization: `Bearer ${stripeKey}` } },
    );
    const existingSession = await existingResponse.json().catch(() => ({}));
    if (!existingResponse.ok) return json({ error: "Existing Checkout session could not be verified" }, 502);
    if (existingSession.status === "open" && typeof existingSession.url === "string") {
      return json({ checkout_url: existingSession.url, payment_record_id: record.id });
    }
    if (existingSession.status === "complete" && existingSession.payment_status === "paid") {
      return json({ paid: true, message: "This fixture has already been paid." });
    }
    const sessionAction = classifyExistingCheckoutSession(record.status, String(existingSession.status ?? ""), String(existingSession.payment_status ?? ""));
    if (sessionAction !== "retry") return json({ error: "This Checkout is still processing. Refresh the Player Hub shortly." }, 409);
  } else if (classifyCheckoutWithoutSession(record.status) === "blocked") {
    return json({ error: "This payment cannot be checked out" }, 409);
  }

  const retryRequired = Boolean(record.stripe_checkout_session_id) ||
    record.status === "failed" || record.status === "cancelled";
  if (retryRequired) {
    const previousStatus = record.status;
    const previousAttempt = record.checkout_attempt;
    const nextAttempt = nextCheckoutAttempt(previousAttempt);
    if (nextAttempt === null) return json({ error: "Checkout attempt limit reached. Contact Open Play." }, 409);
    let claim = admin.from("payment_records").update({
      status: "pending",
      checkout_attempt: nextAttempt,
      stripe_checkout_session_id: null,
      stripe_payment_intent_id: null,
    }).eq("id", record.id).eq("status", previousStatus).eq("checkout_attempt", previousAttempt);
    claim = record.stripe_checkout_session_id
      ? claim.eq("stripe_checkout_session_id", record.stripe_checkout_session_id)
      : claim.is("stripe_checkout_session_id", null);
    const { data: claimedRecord, error: claimError } = await claim
      .select("id,amount_pence,currency,status,stripe_checkout_session_id,checkout_attempt")
      .maybeSingle();
    if (claimError) return json({ error: "Checkout retry could not be prepared" }, 500);
    if (!claimedRecord) return json({ error: "Another checkout attempt is already being prepared. Refresh and try again." }, 409);
    record = claimedRecord;
  } else if (record.status !== "pending") {
    return json({ error: "This payment cannot be checked out" }, 409);
  }

  const form = new URLSearchParams();
  form.set("mode", "payment");
  form.set("success_url", `${appOrigin}/player?checkout=success`);
  form.set("cancel_url", `${appOrigin}/player?checkout=cancelled`);
  form.set("client_reference_id", record.id);
  form.set("line_items[0][quantity]", "1");
  form.set("line_items[0][price_data][currency]", record.currency);
  form.set("line_items[0][price_data][unit_amount]", String(record.amount_pence));
  form.set("line_items[0][price_data][product_data][name]", "Open Play fixture match fee");
  form.set("line_items[0][price_data][product_data][description]", "One-off player match fee");
  form.set("metadata[payment_record_id]", record.id);
  form.set("metadata[player_user_id]", authData.user.id);
  form.set("metadata[checkout_attempt]", String(record.checkout_attempt));
  form.set("payment_intent_data[metadata][payment_record_id]", record.id);
  form.set("payment_intent_data[metadata][checkout_attempt]", String(record.checkout_attempt));

  const stripeResponse = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${stripeKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": `openplay-checkout-${record.id}-${record.checkout_attempt}`,
    },
    body: form,
  });
  const session = await stripeResponse.json().catch(() => ({}));
  if (!stripeResponse.ok || !session.url) {
    return json({ error: "Stripe could not create a Checkout session" }, 502);
  }

  // Persist only if this attempt is still current and no other session was stored.
  const { data: savedRecord, error: updateError } = await admin.from("payment_records").update({
    stripe_checkout_session_id: session.id,
  }).eq("id", record.id).eq("checkout_attempt", record.checkout_attempt)
    .in("status", ["pending", "processing"]).is("stripe_checkout_session_id", null)
    .select("id").maybeSingle();
  if (updateError) return json({ error: "Checkout was created but payment state could not be saved. Refresh the Player Hub before retrying." }, 500);
  if (!savedRecord) {
    const { data: latestRecord } = await admin.from("payment_records")
      .select("status,stripe_checkout_session_id,checkout_attempt")
      .eq("id", record.id).maybeSingle();
    if (latestRecord?.status === "paid") return json({ paid: true, message: "This fixture has already been paid." });
    if (latestRecord?.stripe_checkout_session_id === session.id && latestRecord.checkout_attempt === record.checkout_attempt &&
      ["pending", "processing"].includes(latestRecord.status)) {
      return json({ checkout_url: session.url, payment_record_id: record.id });
    }
    return json({ error: "Payment state changed while Checkout was being created. Refresh before trying again." }, 409);
  }

  return json({ checkout_url: session.url, payment_record_id: record.id });
});

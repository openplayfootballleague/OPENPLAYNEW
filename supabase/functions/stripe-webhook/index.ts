import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}
function hexBytes(hex: string): Uint8Array | null {
  if (!/^[a-f0-9]+$/i.test(hex) || hex.length % 2) return null;
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return out;
}
async function verifySignature(raw: string, header: string, secret: string): Promise<boolean> {
  const parts = header.split(",").map((part) => part.split("=", 2));
  const timestamp = parts.find(([key]) => key === "t")?.[1];
  const signatures = parts.filter(([key]) => key === "v1").map(([, value]) => value);
  if (!timestamp || !/^\d+$/.test(timestamp) || Math.abs(Date.now() / 1000 - Number(timestamp)) > 300) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const expected = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${timestamp}.${raw}`)));
  return signatures.some((signature) => {
    const candidate = hexBytes(signature);
    return candidate !== null && constantTimeEqual(expected, candidate);
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!stripeKey?.startsWith("sk_test_") || !webhookSecret || !supabaseUrl || !serviceKey) {
    return new Response("Webhook service is not configured for test mode", { status: 503 });
  }
  const raw = await req.text();
  const signature = req.headers.get("stripe-signature") ?? "";
  if (!await verifySignature(raw, signature, webhookSecret)) {
    return new Response("Invalid Stripe signature", { status: 400 });
  }

  let event: Record<string, unknown>;
  try { event = JSON.parse(raw); } catch { return new Response("Invalid event payload", { status: 400 }); }
  if (event.livemode !== false) return new Response("Live-mode events are disabled", { status: 400 });

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const object = (event.data as Record<string, unknown> | undefined)?.object as Record<string, unknown> | undefined;
  const metadata = object?.metadata as Record<string, unknown> | undefined;
  const paymentId = String(metadata?.payment_record_id ?? object?.client_reference_id ?? "");
  const eventId = String(event.id ?? "");
  const eventType = String(event.type ?? "");
  if (!eventId || !eventType) return new Response("Incomplete event", { status: 400 });

  const { error: eventInsertError } = await admin.from("stripe_webhook_events")
    .insert({ id: eventId, event_type: eventType, payment_record_id: paymentId || null, livemode: false })
    .select("id").single();
  if (eventInsertError) {
    if (eventInsertError.code !== "23505") return new Response("Could not record webhook event", { status: 500 });
    const { data: priorEvent, error: priorError } = await admin.from("stripe_webhook_events")
      .select("processed_at").eq("id", eventId).maybeSingle();
    if (priorError) return new Response("Could not inspect webhook retry state", { status: 500 });
    if (priorEvent?.processed_at) return Response.json({ received: true, duplicate: true });
    // An earlier attempt failed before completion. Continue processing the same event.
  }

  let resolvedPaymentId = paymentId;
  if (!resolvedPaymentId && eventType === "charge.refunded") {
    const intentId = typeof object?.payment_intent === "string" ? object.payment_intent : "";
    if (intentId) {
      const { data: linkedPayment, error: lookupError } = await admin.from("payment_records")
        .select("id").eq("stripe_payment_intent_id", intentId).maybeSingle();
      if (lookupError) return new Response("Could not map refund to payment", { status: 500 });
      resolvedPaymentId = linkedPayment?.id ?? "";
    }
  }

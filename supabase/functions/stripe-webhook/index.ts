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
  if (!resolvedPaymentId && (eventType === "charge.refunded" || eventType === "charge.succeeded")) {
    const intentId = typeof object?.payment_intent === "string" ? object.payment_intent : "";
    if (intentId) {
      const { data: linkedPayment, error: lookupError } = await admin.from("payment_records")
        .select("id").eq("stripe_payment_intent_id", intentId).maybeSingle();
      if (lookupError) return new Response("Could not map refund to payment", { status: 500 });
      resolvedPaymentId = linkedPayment?.id ?? "";
    }
  }

  const paymentEvents = new Set([
    "checkout.session.completed",
    "checkout.session.async_payment_succeeded",
    "checkout.session.async_payment_failed",
    "checkout.session.expired",
    "charge.refunded",
  ]);
  if (paymentEvents.has(eventType) && !resolvedPaymentId) {
    await admin.from("stripe_webhook_events").update({
      processing_error: "No matching Open Play payment record",
    }).eq("id", eventId);
    return new Response("Payment record not found", { status: 500 });
  }

  if (paymentEvents.has(eventType)) {
    const patch: Record<string, unknown> = {
      last_stripe_event_at: new Date(Number(event.created ?? Date.now() / 1000) * 1000).toISOString(),
    };

    if (eventType.startsWith("checkout.session.")) {
      const sessionId = typeof object?.id === "string" ? object.id : null;
      const intentId = typeof object?.payment_intent === "string" ? object.payment_intent : null;
      if (sessionId) patch.stripe_checkout_session_id = sessionId;
      if (intentId) patch.stripe_payment_intent_id = intentId;

      if (eventType === "checkout.session.completed") {
        if (object?.payment_status === "paid") {
          patch.status = "paid";
          patch.paid_at = new Date().toISOString();
        } else {
          patch.status = "processing";
        }
      } else if (eventType === "checkout.session.async_payment_succeeded") {
        patch.status = "paid";
        patch.paid_at = new Date().toISOString();
      } else if (eventType === "checkout.session.async_payment_failed") {
        patch.status = "failed";
      } else if (eventType === "checkout.session.expired") {
        patch.status = "cancelled";
      }
    } else if (eventType === "charge.succeeded") {
      const balanceTransaction = object?.balance_transaction;
      const balanceTransactionId = typeof balanceTransaction === "string"
        ? balanceTransaction
        : typeof balanceTransaction === "object" && balanceTransaction !== null && typeof (balanceTransaction as Record<string, unknown>).id === "string"
          ? String((balanceTransaction as Record<string, unknown>).id)
          : "";
      if (!balanceTransactionId) {
        await admin.from("stripe_webhook_events").update({
          processing_error: "Charge has no balance transaction yet",
        }).eq("id", eventId);
        return new Response("Balance transaction not available", { status: 500 });
      }
      const balanceResponse = await fetch(`https://api.stripe.com/v1/balance_transactions/${encodeURIComponent(balanceTransactionId)}`, {
        headers: { Authorization: `Bearer ${stripeKey}` },
      });
      const balance = await balanceResponse.json().catch(() => ({}));
      if (!balanceResponse.ok || !Number.isSafeInteger(balance?.fee) || !Number.isSafeInteger(balance?.net) || balance.fee < 0 || balance.net < 0) {
        await admin.from("stripe_webhook_events").update({
          processing_error: "Could not verify Stripe balance transaction fee and net",
        }).eq("id", eventId);
        return new Response("Balance transaction lookup failed", { status: 500 });
      }
      patch.stripe_fee_pence = balance.fee;
      patch.net_amount_pence = balance.net;
      if (typeof object?.payment_intent === "string") patch.stripe_payment_intent_id = object.payment_intent;
    } else if (eventType === "charge.refunded") {
      const refunded = Number(object?.amount_refunded ?? 0);
      const total = Number(object?.amount ?? 0);
      if (!Number.isSafeInteger(refunded) || !Number.isSafeInteger(total) || refunded < 0 || total <= 0 || refunded > total) {
        await admin.from("stripe_webhook_events").update({
          processing_error: "Invalid refund amounts in Stripe event",
        }).eq("id", eventId);
        return new Response("Invalid refund amounts", { status: 400 });
      }
      patch.amount_refunded_pence = refunded;
      patch.status = refunded >= total ? "refunded" : "partially_refunded";
      if (refunded >= total) patch.refunded_at = new Date().toISOString();
      if (typeof object?.payment_intent === "string") patch.stripe_payment_intent_id = object.payment_intent;
    }

    const { error: paymentUpdateError } = await admin.from("payment_records")
      .update(patch).eq("id", resolvedPaymentId);
    if (paymentUpdateError) {
      await admin.from("stripe_webhook_events").update({
        processing_error: paymentUpdateError.message,
      }).eq("id", eventId);
      return new Response("Could not update payment record", { status: 500 });
    }
    await admin.from("stripe_webhook_events").update({
      payment_record_id: resolvedPaymentId,
      processed_at: new Date().toISOString(),
      processing_error: null,
    }).eq("id", eventId);
  } else {
    await admin.from("stripe_webhook_events").update({
      processed_at: new Date().toISOString(),
      processing_error: null,
    }).eq("id", eventId);
  }

  return Response.json({ received: true });
});

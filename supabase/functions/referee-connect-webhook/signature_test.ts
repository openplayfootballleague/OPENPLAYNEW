import { assert, assertFalse } from "jsr:@std/assert@1";
import { verifyStripeSignature } from "./signature.ts";

const encoder = new TextEncoder();

async function signatureFor(body: string, secret: string, timestamp: number): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, encoder.encode(`${timestamp}.${body}`)),
  );
  const hex = Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
  return `t=${timestamp},v1=${hex}`;
}

Deno.test("accepts a valid Stripe signature for the exact raw body", async () => {
  const body = JSON.stringify({ id: "evt_test_1", type: "account.updated" });
  const now = 1_800_000_000_000;
  const timestamp = Math.floor(now / 1000);
  const header = await signatureFor(body, "whsec_test_secret", timestamp);
  assert(await verifyStripeSignature(body, header, "whsec_test_secret", now));
});

Deno.test("rejects a body changed after Stripe signed it", async () => {
  const body = '{"id":"evt_test_1"}';
  const now = 1_800_000_000_000;
  const header = await signatureFor(body, "whsec_test_secret", Math.floor(now / 1000));
  assertFalse(await verifyStripeSignature('{"id":"evt_test_2"}', header, "whsec_test_secret", now));
});

Deno.test("rejects a signature created with a different endpoint secret", async () => {
  const body = '{"id":"evt_test_1"}';
  const now = 1_800_000_000_000;
  const header = await signatureFor(body, "whsec_original", Math.floor(now / 1000));
  assertFalse(await verifyStripeSignature(body, header, "whsec_wrong", now));
});

Deno.test("rejects signatures outside Stripe's five-minute tolerance", async () => {
  const body = '{"id":"evt_test_1"}';
  const now = 1_800_000_000_000;
  const timestamp = Math.floor(now / 1000) - 301;
  const header = await signatureFor(body, "whsec_test_secret", timestamp);
  assertFalse(await verifyStripeSignature(body, header, "whsec_test_secret", now));
});

Deno.test("rejects malformed timestamps and missing v1 signatures", async () => {
  const now = 1_800_000_000_000;
  assertFalse(await verifyStripeSignature("{}", "t=1e3,v1=abcd", "whsec_test_secret", now));
  assertFalse(await verifyStripeSignature("{}", "t=1800000000", "whsec_test_secret", now));
  assertFalse(await verifyStripeSignature("{}", "", "whsec_test_secret", now));
});

Deno.test("accepts any valid v1 signature when Stripe sends multiple signatures", async () => {
  const body = '{"id":"evt_test_1"}';
  const now = 1_800_000_000_000;
  const timestamp = Math.floor(now / 1000);
  const valid = await signatureFor(body, "whsec_test_secret", timestamp);
  const header = valid.replace(",v1=", ",v1=" + "0".repeat(64) + ",v1=");
  assert(await verifyStripeSignature(body, header, "whsec_test_secret", now));
});

import { assertEquals } from "jsr:@std/assert@1";
import { canMarkStripeTransferFailed, stripeTransferIdempotencyKey } from "./stripe-transfer-policy.ts";

Deno.test("ambiguous Stripe transfer responses remain processing", () => {
  for (const status of [408, 409, 429, 500, 502, 503, 504]) {
    assertEquals(canMarkStripeTransferFailed(status), false, `HTTP ${status}`);
  }
});

Deno.test("definitive Stripe client errors may fail a payout", () => {
  for (const status of [400, 401, 403, 404, 422]) {
    assertEquals(canMarkStripeTransferFailed(status), true, `HTTP ${status}`);
  }
});

Deno.test("successful HTTP responses are never classified as failures", () => {
  for (const status of [200, 201, 202, 204]) {
    assertEquals(canMarkStripeTransferFailed(status), false, `HTTP ${status}`);
  }
});

Deno.test("Stripe idempotency keys are stable for the same payout attempt", () => {
  const first = stripeTransferIdempotencyKey("match_report", "payout-123", 1);
  const retry = stripeTransferIdempotencyKey("match_report", "payout-123", 1);
  assertEquals(first, "openplay-referee-match_report-payout-123-attempt-1");
  assertEquals(retry, first);
});

Deno.test("a new reconciled attempt receives a different idempotency key", () => {
  const first = stripeTransferIdempotencyKey("match_report", "payout-123", 1);
  const second = stripeTransferIdempotencyKey("match_report", "payout-123", 2);
  assertEquals(first === second, false);
});

Deno.test("invalid payout identities cannot produce Stripe idempotency keys", () => {
  let invalidType = false;
  let invalidAttempt = false;
  try { stripeTransferIdempotencyKey("other", "payout-123", 1); } catch { invalidType = true; }
  try { stripeTransferIdempotencyKey("match_report", "payout-123", 0); } catch { invalidAttempt = true; }
  assertEquals(invalidType, true);
  assertEquals(invalidAttempt, true);
});

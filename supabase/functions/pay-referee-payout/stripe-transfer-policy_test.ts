import { assertEquals } from "jsr:@std/assert@1";
import { canMarkStripeTransferFailed } from "./stripe-transfer-policy.ts";

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
    assertEquals(canMarkStripeTransferFailed(status), true, `HTTP ${status}`);
  }
});

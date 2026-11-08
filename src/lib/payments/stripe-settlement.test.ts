import { describe, expect, it } from "vitest";
import { checkoutAttemptFromIntentMetadata, classifyCheckoutWithoutSession, classifyExistingCheckoutSession, isFinalizedPaymentStatus, isRefundedPaymentStatus, nextCheckoutAttempt, paymentRecordIdFromIntentMetadata, validateChargeSettlement, validateCheckoutSettlement, type PaymentSettlementRecord } from "./stripe-settlement";

const record: PaymentSettlementRecord = {
  id: "payment-1",
  amount_pence: 350,
  currency: "gbp",
  stripe_checkout_session_id: "cs_test_123",
  stripe_payment_intent_id: "pi_123",
  checkout_attempt: 0,
};

describe("Stripe checkout settlement validation", () => {
  it("accepts the matching checkout session, amount, currency and intent", () => {
    expect(validateCheckoutSettlement(record, {
      id: "cs_test_123",
      client_reference_id: "payment-1",
      metadata: { payment_record_id: "payment-1", checkout_attempt: "0" },
      amount_total: 350,
      currency: "gbp",
      payment_intent: "pi_123",
    })).toEqual({ ok: true });
  });

  it("rejects a different checkout session", () => {
    expect(validateCheckoutSettlement(record, {
      id: "cs_test_other",
      client_reference_id: "payment-1",
      metadata: { payment_record_id: "payment-1" },
    }).ok).toBe(false);
  });

  it("rejects a different payment record in session metadata", () => {
    expect(validateCheckoutSettlement(record, {
      id: "cs_test_123",
      client_reference_id: "payment-2",
      metadata: { payment_record_id: "payment-2", checkout_attempt: "0" },
    }).ok).toBe(false);
  });

  it("rejects an amount mismatch", () => {
    expect(validateCheckoutSettlement(record, {
      id: "cs_test_123",
      client_reference_id: "payment-1",
      metadata: { payment_record_id: "payment-1" },
      amount_total: 351,
      currency: "gbp",
    }).ok).toBe(false);
  });

  it("rejects a currency mismatch", () => {
    expect(validateCheckoutSettlement(record, {
      id: "cs_test_123",
      client_reference_id: "payment-1",
      metadata: { payment_record_id: "payment-1" },
      amount_total: 350,
      currency: "usd",
    }).ok).toBe(false);
  });

  it("rejects a paid checkout session when the amount is missing", () => {
    expect(validateCheckoutSettlement(record, {
      id: "cs_test_123",
      client_reference_id: "payment-1",
      metadata: { payment_record_id: "payment-1" },
      payment_status: "paid",
      currency: "gbp",
    }).ok).toBe(false);
  });

  it("accepts a charge.succeeded-only event when the charge matches", () => {
    expect(validateChargeSettlement(record, {
      payment_intent: "pi_123",
      amount: 350,
      currency: "gbp",
      paid: true,
    }, { payment_record_id: "payment-1", checkout_attempt: "0" })).toEqual({ ok: true });
  });

  it("rejects an unconfirmed or mismatched charge", () => {
    expect(validateChargeSettlement(record, {
      payment_intent: "pi_other",
      amount: 350,
      currency: "gbp",
      paid: false,
    }, { payment_record_id: "payment-1", checkout_attempt: "0" }).ok).toBe(false);
  });
});

describe("Stripe payment state ordering", () => {
  it("preserves partial and full refund states when a late success event arrives", () => {
    expect(isRefundedPaymentStatus("partially_refunded")).toBe(true);
    expect(isRefundedPaymentStatus("refunded")).toBe(true);
  });

  it("allows a valid success event to settle non-refunded states", () => {
    expect(isRefundedPaymentStatus("pending")).toBe(false);
    expect(isRefundedPaymentStatus("processing")).toBe(false);
    expect(isRefundedPaymentStatus("paid")).toBe(false);
  });
});

describe("Stripe PaymentIntent record mapping", () => {
  it("reads the server-created payment record metadata", () => {
    expect(paymentRecordIdFromIntentMetadata({ payment_record_id: "payment-1" })).toBe("payment-1");
  });

  it("rejects absent, malformed or blank mapping metadata", () => {
    expect(paymentRecordIdFromIntentMetadata(null)).toBeNull();
    expect(paymentRecordIdFromIntentMetadata([])).toBeNull();
    expect(paymentRecordIdFromIntentMetadata({ payment_record_id: "  " })).toBeNull();
  });
});

describe("Stripe checkout attempt metadata", () => {
  it("parses a non-negative integer attempt", () => {
    expect(checkoutAttemptFromIntentMetadata({ checkout_attempt: "2" })).toBe(2);
  });

  it("rejects malformed attempt values", () => {
    expect(checkoutAttemptFromIntentMetadata({ checkout_attempt: "2x" })).toBeNull();
    expect(checkoutAttemptFromIntentMetadata(null)).toBeNull();
  });
});

describe("Stripe retry attempt isolation", () => {
  const retryRecord: PaymentSettlementRecord = {
    ...record,
    stripe_checkout_session_id: null,
    stripe_payment_intent_id: null,
    checkout_attempt: 1,
  };

  it("accepts the current attempt even before its session id is persisted", () => {
    expect(validateCheckoutSettlement(retryRecord, {
      id: "cs_test_attempt_1",
      client_reference_id: "payment-1",
      metadata: { payment_record_id: "payment-1", checkout_attempt: "1" },
    })).toEqual({ ok: true });
  });

  it("rejects a delayed event from the previous attempt", () => {
    expect(validateCheckoutSettlement(retryRecord, {
      id: "cs_test_attempt_0",
      client_reference_id: "payment-1",
      metadata: { payment_record_id: "payment-1", checkout_attempt: "0" },
    }).ok).toBe(false);
  });

  it("rejects a charge from the previous PaymentIntent attempt", () => {
    expect(validateChargeSettlement(retryRecord, {
      payment_intent: "pi_old",
      amount: 350,
      currency: "gbp",
      paid: true,
    }, { payment_record_id: "payment-1", checkout_attempt: "0" }).ok).toBe(false);
  });
});

describe("Stripe checkout retry state machine", () => {
  it("reuses an open session", () => {
    expect(classifyExistingCheckoutSession("pending", "open", "unpaid")).toBe("reuse");
  });

  it("recognises an already-paid completed session", () => {
    expect(classifyExistingCheckoutSession("processing", "complete", "paid")).toBe("paid");
  });

  it("retries an expired session", () => {
    expect(classifyExistingCheckoutSession("pending", "expired", "unpaid")).toBe("retry");
  });

  it("retries a completed asynchronous failure only after the ledger marks it failed", () => {
    expect(classifyExistingCheckoutSession("failed", "complete", "unpaid")).toBe("retry");
    expect(classifyExistingCheckoutSession("processing", "complete", "unpaid")).toBe("processing");
  });

  it("creates the initial pending attempt without incrementing it", () => {
    expect(classifyCheckoutWithoutSession("pending")).toBe("create");
  });

  it("allows retry after a failed or cancelled record without a session", () => {
    expect(classifyCheckoutWithoutSession("failed")).toBe("retry");
    expect(classifyCheckoutWithoutSession("cancelled")).toBe("retry");
  });

  it("blocks paid or processing records without a session", () => {
    expect(classifyCheckoutWithoutSession("paid")).toBe("blocked");
    expect(classifyCheckoutWithoutSession("processing")).toBe("blocked");
  });

  it("increments only valid non-negative attempt counters", () => {
    expect(nextCheckoutAttempt(0)).toBe(1);
    expect(nextCheckoutAttempt(3)).toBe(4);
    expect(nextCheckoutAttempt(-1)).toBeNull();
    expect(nextCheckoutAttempt(Number.MAX_SAFE_INTEGER)).toBeNull();
  });
});

describe("Stripe finalized payment state", () => {
  it("prevents paid and refunded states being downgraded by late events", () => {
    expect(isFinalizedPaymentStatus("paid")).toBe(true);
    expect(isFinalizedPaymentStatus("partially_refunded")).toBe(true);
    expect(isFinalizedPaymentStatus("refunded")).toBe(true);
  });

  it("allows non-final states to progress through checkout", () => {
    expect(isFinalizedPaymentStatus("pending")).toBe(false);
    expect(isFinalizedPaymentStatus("processing")).toBe(false);
    expect(isFinalizedPaymentStatus("failed")).toBe(false);
    expect(isFinalizedPaymentStatus("cancelled")).toBe(false);
  });
});

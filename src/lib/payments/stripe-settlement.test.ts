import { describe, expect, it } from "vitest";
import { isRefundedPaymentStatus, paymentRecordIdFromIntentMetadata, validateChargeSettlement, validateCheckoutSettlement, type PaymentSettlementRecord } from "./stripe-settlement";

const record: PaymentSettlementRecord = {
  id: "payment-1",
  amount_pence: 350,
  currency: "gbp",
  stripe_checkout_session_id: "cs_test_123",
  stripe_payment_intent_id: "pi_123",
};

describe("Stripe checkout settlement validation", () => {
  it("accepts the matching checkout session, amount, currency and intent", () => {
    expect(validateCheckoutSettlement(record, {
      id: "cs_test_123",
      client_reference_id: "payment-1",
      metadata: { payment_record_id: "payment-1" },
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
      metadata: { payment_record_id: "payment-2" },
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
    })).toEqual({ ok: true });
  });

  it("rejects an unconfirmed or mismatched charge", () => {
    expect(validateChargeSettlement(record, {
      payment_intent: "pi_other",
      amount: 350,
      currency: "gbp",
      paid: false,
    }).ok).toBe(false);
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

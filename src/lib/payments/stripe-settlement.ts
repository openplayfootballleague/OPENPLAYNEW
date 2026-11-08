export type PaymentSettlementRecord = {
  id: string;
  amount_pence: number;
  currency: string;
  stripe_checkout_session_id: string | null;
  stripe_payment_intent_id: string | null;
  checkout_attempt: number;
};

type StripeObject = Record<string, unknown>;
export type SettlementValidation = { ok: true } | { ok: false; reason: string };

export function validateCheckoutSettlement(record: PaymentSettlementRecord, object: StripeObject): SettlementValidation {
  const sessionId = typeof object.id === "string" ? object.id : "";
  const metadata = object.metadata as Record<string, unknown> | undefined;
  const paymentId = String(metadata?.payment_record_id ?? object.client_reference_id ?? "");
  const metadataAttempt = checkoutAttemptFromIntentMetadata(metadata);
  const attemptMatches = metadataAttempt === null ? record.checkout_attempt === 0 : metadataAttempt === record.checkout_attempt;
  if (!sessionId || (record.stripe_checkout_session_id && record.stripe_checkout_session_id !== sessionId) ||
    paymentId !== record.id || !attemptMatches) {
    return { ok: false, reason: "Checkout session identity mismatch; held for finance review" };
  }
  if (object.payment_status === "paid" || object.amount_total !== undefined) {
    const amount = object.amount_total;
    const currency = String(object.currency ?? "").toLowerCase();
    const intentId = typeof object.payment_intent === "string" ? object.payment_intent : "";
    if (!Number.isSafeInteger(amount) || Number(amount) !== record.amount_pence ||
      currency !== record.currency.toLowerCase() ||
      (record.stripe_payment_intent_id && intentId && record.stripe_payment_intent_id !== intentId)) {
      return { ok: false, reason: "Checkout amount, currency or payment intent mismatch; held for finance review" };
    }
  }
  return { ok: true };
}

export function validateChargeSettlement(record: PaymentSettlementRecord, object: StripeObject, intentMetadata?: unknown): SettlementValidation {
  const intentId = typeof object.payment_intent === "string" ? object.payment_intent : "";
  const amount = object.amount;
  const currency = String(object.currency ?? "").toLowerCase();
  const metadataPaymentId = paymentRecordIdFromIntentMetadata(intentMetadata);
  const metadataAttempt = checkoutAttemptFromIntentMetadata(intentMetadata);
  const attemptMatches = metadataAttempt === null ? record.checkout_attempt === 0 : metadataAttempt === record.checkout_attempt;
  if (!intentId || metadataPaymentId !== record.id || !attemptMatches ||
    (record.stripe_payment_intent_id && record.stripe_payment_intent_id !== intentId) ||
    !Number.isSafeInteger(amount) || Number(amount) !== record.amount_pence ||
    currency !== record.currency.toLowerCase() || object.paid !== true) {
    return { ok: false, reason: "Charge amount, currency or payment intent mismatch; held for finance review" };
  }
  return { ok: true };
}

export function isRefundedPaymentStatus(status: string): boolean {
  return status === "refunded" || status === "partially_refunded";
}

export function paymentRecordIdFromIntentMetadata(metadata: unknown): string | null {
  if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)) return null;
  const value = (metadata as Record<string, unknown>).payment_record_id;
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

export function checkoutAttemptFromIntentMetadata(metadata: unknown): number | null {
  if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)) return null;
  const value = (metadata as Record<string, unknown>).checkout_attempt;
  if (typeof value !== "string" || !/^\d+$/.test(value)) return null;
  const attempt = Number(value);
  return Number.isSafeInteger(attempt) && attempt >= 0 ? attempt : null;
}

export type CheckoutSessionAction = "reuse" | "paid" | "retry" | "processing";
export function classifyExistingCheckoutSession(recordStatus: string, sessionStatus: string, paymentStatus: string): CheckoutSessionAction {
  if (sessionStatus === "open") return "reuse";
  if (sessionStatus === "complete" && paymentStatus === "paid") return "paid";
  if (sessionStatus === "expired" ||
    (sessionStatus === "complete" && ["failed", "cancelled"].includes(recordStatus) && paymentStatus !== "paid")) return "retry";
  return "processing";
}

export type CheckoutWithoutSessionAction = "create" | "retry" | "blocked";
export function classifyCheckoutWithoutSession(recordStatus: string): CheckoutWithoutSessionAction {
  if (recordStatus === "pending") return "create";
  if (recordStatus === "failed" || recordStatus === "cancelled") return "retry";
  return "blocked";
}

export function nextCheckoutAttempt(attempt: number): number | null {
  return Number.isSafeInteger(attempt) && attempt >= 0 && attempt < Number.MAX_SAFE_INTEGER ? attempt + 1 : null;
}

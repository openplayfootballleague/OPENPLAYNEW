export type PaymentSettlementRecord = {
  id: string;
  amount_pence: number;
  currency: string;
  stripe_checkout_session_id: string | null;
  stripe_payment_intent_id: string | null;
};

type StripeObject = Record<string, unknown>;
export type SettlementValidation = { ok: true } | { ok: false; reason: string };

export function validateCheckoutSettlement(record: PaymentSettlementRecord, object: StripeObject): SettlementValidation {
  const sessionId = typeof object.id === "string" ? object.id : "";
  const metadata = object.metadata as Record<string, unknown> | undefined;
  const paymentId = String(metadata?.payment_record_id ?? object.client_reference_id ?? "");
  if (!sessionId || record.stripe_checkout_session_id !== sessionId || paymentId !== record.id) {
    return { ok: false, reason: "Checkout session identity mismatch; held for finance review" };
  }
  if (object.amount_total !== undefined) {
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

export function validateChargeSettlement(record: PaymentSettlementRecord, object: StripeObject): SettlementValidation {
  const intentId = typeof object.payment_intent === "string" ? object.payment_intent : "";
  const amount = object.amount;
  const currency = String(object.currency ?? "").toLowerCase();
  if (!intentId || (record.stripe_payment_intent_id && record.stripe_payment_intent_id !== intentId) ||
    !Number.isSafeInteger(amount) || Number(amount) !== record.amount_pence ||
    currency !== record.currency.toLowerCase() || object.paid !== true) {
    return { ok: false, reason: "Charge amount, currency or payment intent mismatch; held for finance review" };
  }
  return { ok: true };
}

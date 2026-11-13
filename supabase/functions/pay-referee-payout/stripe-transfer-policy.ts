// A failed HTTP response does not always prove that Stripe did not create a transfer.
export function canMarkStripeTransferFailed(status: number): boolean {
  return status >= 400 && status < 500 && status !== 408 && status !== 409 && status !== 429;
}

export function stripeTransferIdempotencyKey(
  payoutType: string,
  payoutId: string,
  attempt: number,
): string {
  if (payoutType !== "match_report" && payoutType !== "milestone") {
    throw new Error("A valid referee payout type is required");
  }
  if (!payoutId.trim() || !Number.isSafeInteger(attempt) || attempt < 1) {
    throw new Error("A valid payout ID and positive attempt number are required");
  }
  return `openplay-referee-${payoutType}-${payoutId}-attempt-${attempt}`;
}

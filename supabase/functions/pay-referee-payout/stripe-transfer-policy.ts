// A failed HTTP response does not always prove that Stripe did not create a transfer.
export function canMarkStripeTransferFailed(status: number): boolean {
  return status >= 400 && status < 500 && status !== 408 && status !== 409 && status !== 429;
}

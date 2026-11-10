export class PermanentDeliveryError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "PermanentDeliveryError";
  }
}

/** 408 and 429 are retryable; other provider 4xx responses are not. */
export function isPermanentProviderStatus(status: number): boolean {
  return status >= 400 && status < 500 && status !== 408 && status !== 429;
}

export function providerHttpError(provider: string, status: number, _body: unknown): Error {
  // Provider response bodies can contain recipient addresses or phone numbers.
  // Persist only the provider and HTTP status in the notification outbox.
  const message = `${provider} returned ${status}`;
  return isPermanentProviderStatus(status)
    ? new PermanentDeliveryError(message)
    : new Error(message);
}

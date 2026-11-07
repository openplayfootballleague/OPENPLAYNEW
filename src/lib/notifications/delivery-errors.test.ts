import { describe, expect, it } from "vitest";
import { isPermanentProviderStatus, PermanentDeliveryError, providerHttpError } from "../../../supabase/functions/deliver-notifications/shared/delivery-errors.ts";

describe("notification provider error classification", () => {
  it.each([400, 401, 403, 404, 422])("treats non-retryable provider status %i as permanent", status => {
    expect(isPermanentProviderStatus(status)).toBe(true);
    expect(providerHttpError("Provider", status, { error: "invalid" })).toBeInstanceOf(PermanentDeliveryError);
  });

  it.each([408, 429, 500, 502, 503, 504])("keeps transient provider status %i retryable", status => {
    expect(isPermanentProviderStatus(status)).toBe(false);
    expect(providerHttpError("Provider", status, { error: "temporary" })).not.toBeInstanceOf(PermanentDeliveryError);
  });

  it("classifies provider configuration and recipient failures explicitly through the permanent error type", () => {
    const error = new PermanentDeliveryError("Recipient address is invalid");
    expect(error.name).toBe("PermanentDeliveryError");
    expect(error.message).toContain("Recipient");
  });
});

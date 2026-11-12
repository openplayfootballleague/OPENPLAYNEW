const encoder = new TextEncoder();

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

/**
 * Verify Stripe's timestamped HMAC signature against the exact raw request body.
 * The optional clock argument keeps timestamp-tolerance tests deterministic.
 */
export async function verifyStripeSignature(
  rawBody: string,
  header: string,
  secret: string,
  nowMilliseconds = Date.now(),
): Promise<boolean> {
  if (!secret || !header) return false;

  const parts = header.split(",").map((part) => part.trim());
  const timestampText = parts.find((part) => part.startsWith("t="))?.slice(2);
  const signatures = parts
    .filter((part) => part.startsWith("v1="))
    .map((part) => part.slice(3).toLowerCase());

  if (!timestampText || !/^\d+$/.test(timestampText) || signatures.length === 0) {
    return false;
  }

  const timestamp = Number(timestampText);
  if (!Number.isSafeInteger(timestamp) || Math.abs(nowMilliseconds / 1000 - timestamp) > 300) {
    return false;
  }

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, encoder.encode(`${timestampText}.${rawBody}`)),
  );
  const expected = toHex(digest);

  return signatures.some((signature) => /^[a-f0-9]{64}$/.test(signature) && constantTimeEqual(signature, expected));
}

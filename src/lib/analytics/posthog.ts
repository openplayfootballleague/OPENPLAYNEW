const CONSENT_KEY = "openplay.analytics-consent.v1";
const ANON_ID_KEY = "openplay.analytics-anonymous-id.v1";

type Consent = "granted" | "denied" | null;

let activeUserId: string | null = null;
let anonymousId: string | null = null;

function configuredKey(): string {
  return import.meta.env.VITE_POSTHOG_KEY?.trim() ?? "";
}

function host(): string {
  const configured = import.meta.env.VITE_POSTHOG_HOST?.trim();
  return (configured || "https://eu.i.posthog.com").replace(/\/$/, "");
}

function consent(): Consent {
  if (typeof window === "undefined") return null;
  const value = window.localStorage.getItem(CONSENT_KEY);
  return value === "granted" || value === "denied" ? value : null;
}

function getAnonymousId(): string {
  if (anonymousId) return anonymousId;
  const existing = window.localStorage.getItem(ANON_ID_KEY);
  if (existing) {
    anonymousId = existing;
    return existing;
  }
  const created = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `anon-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  window.localStorage.setItem(ANON_ID_KEY, created);
  anonymousId = created;
  return created;
}

function rotateAnonymousId(): void {
  if (typeof window === "undefined") return;
  const created = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `anon-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  window.localStorage.setItem(ANON_ID_KEY, created);
  anonymousId = created;
  activeUserId = null;
}

async function capture(
  event: string,
  distinctId: string,
  properties: Record<string, unknown> = {},
): Promise<void> {
  const apiKey = configuredKey();
  if (consent() !== "granted" || !apiKey || typeof window === "undefined") return;

  try {
    await fetch(`${host()}/capture/?ip=0`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "omit",
      keepalive: true,
      body: JSON.stringify({
        api_key: apiKey,
        event,
        distinct_id: distinctId,
        properties: {
          ...properties,
          $process_person_profile: false,
        },
        timestamp: new Date().toISOString(),
      }),
    });
  } catch {
    // Analytics is optional: provider/network failures must never affect app use.
  }
}

export function getAnalyticsConsent(): Consent {
  return consent();
}

export function setAnalyticsConsent(allowed: boolean): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(CONSENT_KEY, allowed ? "granted" : "denied");
  if (allowed) {
    activeUserId = null;
    void capture("analytics_consent_granted", getAnonymousId());
  } else {
    rotateAnonymousId();
  }
}

export function setAnalyticsIdentity(userId: string | null): void {
  if (typeof window === "undefined" || consent() !== "granted") {
    activeUserId = null;
    return;
  }

  if (!userId) {
    if (activeUserId) rotateAnonymousId();
    return;
  }

  if (activeUserId === userId) return;
  const previousAnonymousId = getAnonymousId();
  activeUserId = userId;
  void capture("$identify", userId, {
    $anon_distinct_id: previousAnonymousId,
    $set: {},
  });
}

export function trackAnalyticsPageView(pathname: string): void {
  if (typeof window === "undefined" || consent() !== "granted") return;
  const safePath = pathname
    .split("/")
    .map((segment) =>
      /^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(segment) || /^\d+$/.test(segment)
        ? ":id"
        : segment,
    )
    .join("/");
  void capture("$pageview", activeUserId ?? getAnonymousId(), {
    $pathname: safePath || "/",
  });
}

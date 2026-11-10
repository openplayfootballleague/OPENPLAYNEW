import { getSupabaseClient } from "../supabase/client";

const CONSENT_KEY = "openplay.analytics-consent.v1";
const ANON_ID_KEY = "openplay.analytics-anonymous-id.v1";

type Consent = "granted" | "denied" | null;

let activeUserId: string | null = null;
let anonymousId: string | null = null;
let memoryConsent: Consent = null;

function configuredKey(): string {
  return import.meta.env.VITE_POSTHOG_KEY?.trim() ?? "";
}

function host(): string {
  const configured = import.meta.env.VITE_POSTHOG_HOST?.trim();
  return (configured || "https://eu.i.posthog.com").replace(/\/$/, "");
}

function consent(): Consent {
  if (typeof window === "undefined") return memoryConsent;
  try {
    const value = window.localStorage.getItem(CONSENT_KEY);
    memoryConsent = value === "granted" || value === "denied" ? value : null;
  } catch {
    // Keep the choice in memory if browser storage is unavailable.
  }
  return memoryConsent;
}

function getAnonymousId(): string {
  if (anonymousId) return anonymousId;
  let existing: string | null = null;
  try { existing = window.localStorage.getItem(ANON_ID_KEY); } catch { /* memory-only fallback */ }
  if (existing) {
    anonymousId = existing;
    return existing;
  }
  const created = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `anon-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  try { window.localStorage.setItem(ANON_ID_KEY, created); } catch { /* memory-only fallback */ }
  anonymousId = created;
  return created;
}

function rotateAnonymousId(): void {
  if (typeof window === "undefined") return;
  const created = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `anon-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  try { window.localStorage.setItem(ANON_ID_KEY, created); } catch { /* memory-only fallback */ }
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
  memoryConsent = allowed ? "granted" : "denied";
  try { window.localStorage.setItem(CONSENT_KEY, memoryConsent); } catch { /* memory-only fallback */ }
  if (allowed) {
    activeUserId = null;
    void capture("analytics_consent_granted", getAnonymousId());
    // If the person is already signed in when they opt in, identify only now.
    void getSupabaseClient().auth.getSession().then(({ data }) => {
      setAnalyticsIdentity(data.session?.user.id ?? null);
      trackAnalyticsPageView(window.location.pathname);
    }).catch(() => {
      // Consent is saved; analytics must remain non-essential and non-blocking.
    });
  } else {
    rotateAnonymousId();
  }
  window.dispatchEvent(new Event("openplay:analytics-consent"));
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

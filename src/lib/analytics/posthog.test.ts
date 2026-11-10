import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const values = new Map<string, string>();
const storage = {
  getItem: (key: string) => values.get(key) ?? null,
  setItem: (key: string, value: string) => { values.set(key, value); },
  removeItem: (key: string) => { values.delete(key); },
};

describe("optional PostHog analytics consent", () => {
  beforeEach(() => {
    vi.resetModules();
    values.clear();
    vi.stubEnv("VITE_POSTHOG_KEY", "test-project-key");
    vi.stubEnv("VITE_POSTHOG_HOST", "https://eu.i.posthog.com");
    vi.stubEnv("VITE_POSTHOG_CONSENT_ENABLED", "true");
    vi.stubGlobal("window", {
      localStorage: storage,
      dispatchEvent: vi.fn(),
    });
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true }));
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
    vi.restoreAllMocks();
  });

  it("sends no events before explicit opt-in", async () => {
    const analytics = await import("./posthog");
    analytics.trackAnalyticsPageView("/match-centre");
    analytics.setAnalyticsIdentity("auth-user-1");

    expect(fetch).not.toHaveBeenCalled();
  });

  it("keeps capture disabled when the release feature flag is off", async () => {
    vi.stubEnv("VITE_POSTHOG_CONSENT_ENABLED", "false");
    values.set("openplay.analytics-consent.v1", "granted");
    const analytics = await import("./posthog");
    analytics.trackAnalyticsPageView("/match-centre");
    expect(fetch).not.toHaveBeenCalled();
  });

  it("captures only opted-in page views with a sanitised path and IP disabled", async () => {
    const analytics = await import("./posthog");
    analytics.setAnalyticsConsent(true);
    analytics.trackAnalyticsPageView("/admin/123e4567-e89b-12d3-a456-426614174000");

    const calls = vi.mocked(fetch).mock.calls;
    expect(calls).toHaveLength(2);
    expect(String(calls[1][0])).toBe("https://eu.i.posthog.com/capture/?ip=0");
    const payload = JSON.parse(String((calls[1][1] as RequestInit).body));
    expect(payload.event).toBe("$pageview");
    expect(payload.properties.$pathname).toBe("/admin/:id");
    expect(payload.properties.$process_person_profile).toBe(false);
  });

  it("identifies the authenticated account only after consent and resets on logout", async () => {
    const analytics = await import("./posthog");
    analytics.setAnalyticsConsent(true);
    analytics.setAnalyticsIdentity("auth-user-1");
    analytics.trackAnalyticsPageView("/player");
    analytics.setAnalyticsIdentity(null);
    analytics.trackAnalyticsPageView("/");

    const payloads = vi.mocked(fetch).mock.calls.map((call) =>
      JSON.parse(String((call[1] as RequestInit).body)) as {
        event: string;
        distinct_id: string;
      },
    );
    const identify = payloads.find((payload) => payload.event === "$identify");
    const pageViews = payloads.filter((payload) => payload.event === "$pageview");

    expect(identify?.distinct_id).toBe("auth-user-1");
    expect(pageViews).toHaveLength(2);
    expect(pageViews[0].distinct_id).toBe("auth-user-1");
    expect(pageViews[1].distinct_id).not.toBe("auth-user-1");
  });

  it("stops capture immediately when consent is withdrawn", async () => {
    const analytics = await import("./posthog");
    analytics.setAnalyticsConsent(true);
    analytics.setAnalyticsConsent(false);
    analytics.trackAnalyticsPageView("/match-centre");

    expect(fetch).toHaveBeenCalledTimes(1);
    expect(analytics.getAnalyticsConsent()).toBe("denied");
  });
});

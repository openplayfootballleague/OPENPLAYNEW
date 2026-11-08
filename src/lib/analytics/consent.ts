export type AnalyticsConsent = "unset" | "granted" | "denied";

export interface ConsentStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

export const ANALYTICS_CONSENT_KEY = "open-play.analytics-consent.v1";

/** Read a browser-local analytics choice. GPC always overrides a saved opt-in. */
export function readAnalyticsConsent(
  storage: ConsentStorage | null | undefined,
  globalPrivacyControl = false,
): AnalyticsConsent {
  if (globalPrivacyControl) return "denied";
  try {
    const value = storage?.getItem(ANALYTICS_CONSENT_KEY);
    return value === "granted" || value === "denied" ? value : "unset";
  } catch {
    return "unset";
  }
}

/** Persist a choice without ever allowing opt-in to override Global Privacy Control. */
export function writeAnalyticsConsent(
  requested: Exclude<AnalyticsConsent, "unset">,
  storage: ConsentStorage | null | undefined,
  globalPrivacyControl = false,
): { consent: Exclude<AnalyticsConsent, "unset">; persisted: boolean } {
  const consent = globalPrivacyControl ? "denied" : requested;
  try {
    if (!storage) return { consent: "denied", persisted: false };
    storage.setItem(ANALYTICS_CONSENT_KEY, consent);
    return { consent, persisted: true };
  } catch {
    return { consent: "denied", persisted: false };
  }
}

/** Analytics are allowed only after explicit opt-in and while GPC is absent. */
export function isAnalyticsAllowed(
  consent: AnalyticsConsent,
  globalPrivacyControl = false,
): boolean {
  return consent === "granted" && !globalPrivacyControl;
}

export function isGlobalPrivacyControlEnabled(): boolean {
  if (typeof navigator === "undefined") return false;
  return (navigator as Navigator & { globalPrivacyControl?: boolean })
    .globalPrivacyControl === true;
}

export function readBrowserAnalyticsConsent(
  globalPrivacyControl = isGlobalPrivacyControlEnabled(),
): AnalyticsConsent {
  if (typeof window === "undefined") return "unset";
  try {
    return readAnalyticsConsent(window.localStorage, globalPrivacyControl);
  } catch {
    return globalPrivacyControl ? "denied" : "unset";
  }
}

export function writeBrowserAnalyticsConsent(
  requested: Exclude<AnalyticsConsent, "unset">,
  globalPrivacyControl = isGlobalPrivacyControlEnabled(),
): { consent: Exclude<AnalyticsConsent, "unset">; persisted: boolean } {
  if (typeof window === "undefined") {
    return { consent: "denied", persisted: false };
  }
  try {
    return writeAnalyticsConsent(requested, window.localStorage, globalPrivacyControl);
  } catch {
    return { consent: "denied", persisted: false };
  }
}

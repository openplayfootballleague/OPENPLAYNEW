import { describe, expect, it } from "vitest";
import {
  ANALYTICS_CONSENT_KEY,
  isAnalyticsAllowed,
  readAnalyticsConsent,
  writeAnalyticsConsent,
  type ConsentStorage,
} from "./consent";

class MemoryStorage implements ConsentStorage {
  values = new Map<string, string>();
  failReads = false;
  failWrites = false;
  getItem(key: string) {
    if (this.failReads) throw new Error("Storage unavailable");
    return this.values.get(key) ?? null;
  }
  setItem(key: string, value: string) {
    if (this.failWrites) throw new Error("Storage unavailable");
    this.values.set(key, value);
  }
}

describe("analytics consent", () => {
  it("defaults to unset until a user makes an explicit choice", () => {
    expect(readAnalyticsConsent(new MemoryStorage())).toBe("unset");
    expect(isAnalyticsAllowed("unset")).toBe(false);
  });

  it("persists an explicit opt-in and allows analytics only after that choice", () => {
    const storage = new MemoryStorage();
    expect(writeAnalyticsConsent("granted", storage)).toEqual({ consent: "granted", persisted: true });
    expect(storage.getItem(ANALYTICS_CONSENT_KEY)).toBe("granted");
    expect(readAnalyticsConsent(storage)).toBe("granted");
    expect(isAnalyticsAllowed(readAnalyticsConsent(storage))).toBe(true);
  });

  it("persists an explicit opt-out and blocks analytics", () => {
    const storage = new MemoryStorage();
    expect(writeAnalyticsConsent("denied", storage)).toEqual({ consent: "denied", persisted: true });
    expect(readAnalyticsConsent(storage)).toBe("denied");
    expect(isAnalyticsAllowed("denied")).toBe(false);
  });

  it("treats unknown stored values as unset", () => {
    const storage = new MemoryStorage();
    storage.values.set(ANALYTICS_CONSENT_KEY, "yes");
    expect(readAnalyticsConsent(storage)).toBe("unset");
  });

  it("lets Global Privacy Control override a previously saved opt-in", () => {
    const storage = new MemoryStorage();
    storage.values.set(ANALYTICS_CONSENT_KEY, "granted");
    expect(readAnalyticsConsent(storage, true)).toBe("denied");
    expect(isAnalyticsAllowed("granted", true)).toBe(false);
    expect(writeAnalyticsConsent("granted", storage, true)).toEqual({ consent: "denied", persisted: true });
    expect(storage.getItem(ANALYTICS_CONSENT_KEY)).toBe("denied");
  });

  it("fails closed when browser storage cannot be read or written", () => {
    const storage = new MemoryStorage();
    storage.failReads = true;
    expect(readAnalyticsConsent(storage)).toBe("unset");
    storage.failReads = false;
    storage.failWrites = true;
    expect(writeAnalyticsConsent("granted", storage)).toEqual({ consent: "denied", persisted: false });
    expect(isAnalyticsAllowed("unset")).toBe(false);
  });

  it("does not allow analytics if consent is unset even when storage is unavailable", () => {
    expect(isAnalyticsAllowed(readAnalyticsConsent(null))).toBe(false);
    expect(writeAnalyticsConsent("granted", null)).toEqual({ consent: "granted", persisted: false });
  });
});

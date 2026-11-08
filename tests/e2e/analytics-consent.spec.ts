// Network interception is installed before navigation; no test traffic reaches the real PostHog service.
import { expect, test, type Page } from "@playwright/test";

const CONSENT_KEY = "open-play.analytics-consent.v1";

async function interceptPostHog(page: Page, requests: string[]) {
  // PostHog may use sendBeacon, which is not intercepted by page.route.
  // Stub it before app code runs and record the URL without network egress.
  await page.addInitScript(() => {
    (window as typeof window & { __openPlayPostHogBeacons?: string[] }).__openPlayPostHogBeacons = [];
    const originalSendBeacon = navigator.sendBeacon?.bind(navigator);
    navigator.sendBeacon = (url, data) => {
      const href = String(url);
      if (new URL(href, location.href).hostname.toLowerCase().endsWith("posthog.com")) {
        (window as typeof window & { __openPlayPostHogBeacons?: string[] }).__openPlayPostHogBeacons?.push(href);
        return true;
      }
      return originalSendBeacon ? originalSendBeacon(url, data) : false;
    };
  });

  await page.route("**/*", async (route) => {
    const url = route.request().url();
    const hostname = new URL(url).hostname.toLowerCase();
    if (!hostname.endsWith("posthog.com")) {
      await route.continue();
      return;
    }

    requests.push(url);
    const isScript = /\.js(?:\?|$)/i.test(url);
    await route.fulfill({
      status: 200,
      contentType: isScript ? "application/javascript" : "application/json",
      body: isScript ? "" : JSON.stringify({
        featureFlags: [],
        featureFlagPayloads: {},
        quotaLimited: false,
      }),
    });
  });
}

async function observedPostHogRequests(page: Page, routedRequests: string[]) {
  const beacons = await page.evaluate(() =>
    (window as typeof window & { __openPlayPostHogBeacons?: string[] }).__openPlayPostHogBeacons?.length ?? 0
  );
  return routedRequests.length + beacons;
}

test("does not contact PostHog before opt-in and stops after same-tab revocation", async ({ page }) => {
  const requests: string[] = [];
  await interceptPostHog(page, requests);

  await page.goto("/privacy-security");
  await expect(page.getByText("No choice saved")).toBeVisible();
  await expect(page.getByRole("complementary", { name: "Optional analytics preferences" })).toBeVisible();
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);
  await page.waitForTimeout(300);
  expect(await observedPostHogRequests(page, requests)).toBe(0);

  await page.locator(".account-security-section").getByRole("button", { name: "ALLOW OPTIONAL ANALYTICS" }).click();
  await expect.poll(() => page.evaluate((key) => localStorage.getItem(key), CONSENT_KEY)).toBe("granted");
  await expect(page.getByRole("complementary", { name: "Optional analytics preferences" })).toHaveCount(0);
  const probe = page.getByTestId("analytics-e2e-probe");
  await expect(probe).toBeVisible();
  await expect(probe).toHaveAttribute("data-posthog-loaded", "true");
  await expect(probe).toHaveAttribute("data-posthog-capturing", "true");
  await expect(probe).toHaveAttribute("data-posthog-opted-in", "true");
  await expect(probe).toHaveAttribute("data-posthog-token", "present");
  await expect(probe).toHaveAttribute("data-posthog-host", /posthog\\.com/);
  await probe.click();
  await expect(probe).toHaveAttribute("data-posthog-capture-called", "true");
  await expect.poll(() => observedPostHogRequests(page, requests), { timeout: 10_000 }).toBeGreaterThan(0);

  await page.getByRole("button", { name: "TURN OFF OPTIONAL ANALYTICS" }).click();
  await expect.poll(() => page.evaluate((key) => localStorage.getItem(key), CONSENT_KEY)).toBe("denied");
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);
  const requestsAfterRevocation = await observedPostHogRequests(page, requests);
  await page.waitForTimeout(300);
  expect(await observedPostHogRequests(page, requests)).toBe(requestsAfterRevocation);

  await page.reload();
  await expect(page.getByText("Declined on this device")).toBeVisible();
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);
  await page.waitForTimeout(500);
  expect(await observedPostHogRequests(page, requests)).toBe(requestsAfterRevocation);
});

test("Global Privacy Control overrides a previously saved opt-in", async ({ page }) => {
  const requests: string[] = [];
  await interceptPostHog(page, requests);
  await page.goto("/");
  await page.evaluate((key) => localStorage.setItem(key, "granted"), CONSENT_KEY);
  await page.addInitScript(() => {
    Object.defineProperty(navigator, "globalPrivacyControl", {
      configurable: true,
      value: true,
    });
  });

  await page.goto("/privacy-security");
  expect(await page.evaluate(() => navigator.globalPrivacyControl)).toBe(true);
  await expect(page.getByRole("complementary", { name: "Optional analytics preferences" })).toHaveCount(0);
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);
  await page.waitForTimeout(300);
  expect(await observedPostHogRequests(page, requests)).toBe(0);
});

test("cross-tab opt-in and revocation update the other tab", async ({ page, context }) => {
  const firstTabRequests: string[] = [];
  const secondTabRequests: string[] = [];
  const secondTab = await context.newPage();
  await interceptPostHog(page, firstTabRequests);
  await interceptPostHog(secondTab, secondTabRequests);

  await page.goto("/privacy-security");
  await secondTab.goto("/privacy-security");
  await page.waitForTimeout(200);
  expect(await observedPostHogRequests(page, firstTabRequests)).toBe(0);
  expect(await observedPostHogRequests(secondTab, secondTabRequests)).toBe(0);
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);

  // A localStorage write in one tab emits a native storage event in the other.
  await secondTab.evaluate((key) => localStorage.setItem(key, "granted"), CONSENT_KEY);
  const firstTabProbe = page.getByTestId("analytics-e2e-probe");
  await expect(firstTabProbe).toBeVisible();
  await page.waitForTimeout(100);
  await expect(firstTabProbe).toHaveAttribute("data-posthog-loaded", "true");
  await expect(firstTabProbe).toHaveAttribute("data-posthog-capturing", "true");
  await expect(firstTabProbe).toHaveAttribute("data-posthog-opted-in", "true");
  await expect(firstTabProbe).toHaveAttribute("data-posthog-token", "present");
  await expect(firstTabProbe).toHaveAttribute("data-posthog-host", /posthog\\.com/);
  await firstTabProbe.click();
  await expect(firstTabProbe).toHaveAttribute("data-posthog-capture-called", "true");
  await expect.poll(() => observedPostHogRequests(page, firstTabRequests), { timeout: 10_000 }).toBeGreaterThan(0);

  await secondTab.evaluate((key) => localStorage.setItem(key, "denied"), CONSENT_KEY);
  await expect(firstTabProbe).toHaveCount(0);
  const requestsAfterCrossTabRevocation = await observedPostHogRequests(page, firstTabRequests);
  await page.waitForTimeout(300);
  expect(await observedPostHogRequests(page, firstTabRequests)).toBe(requestsAfterCrossTabRevocation);

  await page.reload();
  await expect(page.getByText("Declined on this device")).toBeVisible();
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);
  await page.waitForTimeout(500);
  expect(await observedPostHogRequests(page, firstTabRequests)).toBe(requestsAfterCrossTabRevocation);
  await secondTab.close();
});

// Network interception is installed before navigation; no test traffic reaches the real PostHog service.
import { expect, test, type Page } from "@playwright/test";

const POSTHOG_ORIGIN = "https://eu.i.posthog.com";
const CONSENT_KEY = "open-play.analytics-consent.v1";

async function interceptPostHog(page: Page, requests: string[]) {
  await page.route("**/*", async (route) => {
    const url = route.request().url();
    const hostname = new URL(url).hostname.toLowerCase();
    if (!hostname.endsWith("posthog.com")) {
      await route.continue();
      return;
    }

    requests.push(url);
    const isScript = /\\.js(?:\\?|$)/i.test(url);
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

test("does not contact PostHog before opt-in and stops after same-tab revocation", async ({ page }) => {
  const requests: string[] = [];
  await interceptPostHog(page, requests);

  await page.goto("/privacy-security");
  await expect(page.getByText("No choice saved")).toBeVisible();
  await expect(page.getByRole("complementary", { name: "Optional analytics preferences" })).toBeVisible();
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);
  await page.waitForTimeout(300);
  expect(requests).toHaveLength(0);

  await page.locator(".account-security-section").getByRole("button", { name: "ALLOW OPTIONAL ANALYTICS" }).click();
  await expect.poll(() => page.evaluate((key) => localStorage.getItem(key), CONSENT_KEY)).toBe("granted");
  await expect(page.getByText("Allowed on this device")).toBeVisible();
  await expect(page.getByRole("complementary", { name: "Optional analytics preferences" })).toHaveCount(0);
  const probe = page.getByTestId("analytics-e2e-probe");
  await expect(probe).toBeVisible();
  await expect(probe).toHaveAttribute("data-posthog-loaded", "true");
  await expect(probe).toHaveAttribute("data-posthog-capturing", "true");
  await expect(probe).toHaveAttribute("data-posthog-opted-in", "true");
  await probe.click();
  await expect.poll(() => requests.length, { timeout: 10_000 }).toBeGreaterThan(0);

  await page.getByRole("button", { name: "TURN OFF OPTIONAL ANALYTICS" }).click();
  await expect.poll(() => page.evaluate((key) => localStorage.getItem(key), CONSENT_KEY)).toBe("denied");
  await expect(page.getByText("Declined on this device")).toBeVisible();
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);
  const requestsAfterRevocation = requests.length;
  await page.waitForTimeout(300);
  expect(requests).toHaveLength(requestsAfterRevocation);

  await page.reload();
  await expect(page.getByText("Declined on this device")).toBeVisible();
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);
  await page.waitForTimeout(500);
  expect(requests).toHaveLength(requestsAfterRevocation);
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
  await expect(page.getByText("Blocked by Global Privacy Control")).toBeVisible();
  await expect(page.getByRole("complementary", { name: "Optional analytics preferences" })).toHaveCount(0);
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);
  await page.waitForTimeout(300);
  expect(requests).toHaveLength(0);
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
  expect(firstTabRequests).toHaveLength(0);
  expect(secondTabRequests).toHaveLength(0);
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);

  // A localStorage write in one tab emits a native storage event in the other.
  await secondTab.evaluate((key) => localStorage.setItem(key, "granted"), CONSENT_KEY);
  const firstTabProbe = page.getByTestId("analytics-e2e-probe");
  await expect(firstTabProbe).toBeVisible();
  await page.waitForTimeout(100);
  await expect(firstTabProbe).toHaveAttribute("data-posthog-loaded", "true");
  await expect(firstTabProbe).toHaveAttribute("data-posthog-capturing", "true");
  await expect(firstTabProbe).toHaveAttribute("data-posthog-opted-in", "true");
  await firstTabProbe.click();
  await expect.poll(() => firstTabRequests.length, { timeout: 10_000 }).toBeGreaterThan(0);

  await secondTab.evaluate((key) => localStorage.setItem(key, "denied"), CONSENT_KEY);
  await expect(firstTabProbe).toHaveCount(0);
  const requestsAfterCrossTabRevocation = firstTabRequests.length;
  await page.waitForTimeout(300);
  expect(firstTabRequests).toHaveLength(requestsAfterCrossTabRevocation);

  await page.reload();
  await expect(page.getByText("Declined on this device")).toBeVisible();
  await expect(page.getByTestId("analytics-e2e-probe")).toHaveCount(0);
  await page.waitForTimeout(500);
  expect(firstTabRequests).toHaveLength(requestsAfterCrossTabRevocation);
  await secondTab.close();
});

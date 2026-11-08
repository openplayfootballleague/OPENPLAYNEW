// Network interception is installed before navigation; no test traffic reaches the real PostHog service.
import { expect, test, type Page } from "@playwright/test";

const POSTHOG_ORIGIN = "https://eu.i.posthog.com";
const CONSENT_KEY = "open-play.analytics-consent.v1";

async function interceptPostHog(page: Page, requests: string[]) {
  await page.route(`${POSTHOG_ORIGIN}/**`, async (route) => {
    requests.push(route.request().url());
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
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
  await page.waitForTimeout(300);
  expect(requests).toHaveLength(0);

  await page.locator(".account-security-section").getByRole("button", { name: "ALLOW OPTIONAL ANALYTICS" }).click();
  await expect.poll(() => page.evaluate((key) => localStorage.getItem(key), CONSENT_KEY)).toBe("granted");
  await expect(page.getByText("Allowed on this device")).toBeVisible();
  await expect(page.getByRole("complementary", { name: "Optional analytics preferences" })).toHaveCount(0);
  await expect.poll(() => requests.length).toBeGreaterThan(0);

  await page.getByRole("button", { name: "TURN OFF OPTIONAL ANALYTICS" }).click();
  await expect.poll(() => page.evaluate((key) => localStorage.getItem(key), CONSENT_KEY)).toBe("denied");
  await expect(page.getByText("Declined on this device")).toBeVisible();
  await page.waitForTimeout(300);
  const requestsAfterRevocation = requests.length;

  await page.reload();
  await expect(page.getByText("Declined on this device")).toBeVisible();
  await page.waitForTimeout(500);
  expect(requests).toHaveLength(requestsAfterRevocation);
});

test("Global Privacy Control overrides a previously saved opt-in", async ({ page }) => {
  const requests: string[] = [];
  await interceptPostHog(page, requests);
  await page.addInitScript((key) => {
    localStorage.setItem(key, "granted");
    Object.defineProperty(navigator, "globalPrivacyControl", {
      configurable: true,
      value: true,
    });
  }, CONSENT_KEY);

  await page.goto("/privacy-security");
  await expect(page.getByText("Blocked by Global Privacy Control")).toBeVisible();
  await expect(page.getByRole("complementary", { name: "Optional analytics preferences" })).toHaveCount(0);
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

  await secondTab.locator(".account-security-section").getByRole("button", { name: "ALLOW OPTIONAL ANALYTICS" }).click();
  await expect.poll(() => secondTab.evaluate((key) => localStorage.getItem(key), CONSENT_KEY)).toBe("granted");
  await expect(secondTab.getByText("Allowed on this device")).toBeVisible();
  await expect(secondTab.getByRole("complementary", { name: "Optional analytics preferences" })).toHaveCount(0);
  await expect.poll(() => firstTabRequests.length).toBeGreaterThan(0);

  await secondTab.getByRole("button", { name: "TURN OFF OPTIONAL ANALYTICS" }).click();
  await expect.poll(() => secondTab.evaluate((key) => localStorage.getItem(key), CONSENT_KEY)).toBe("denied");
  await expect(secondTab.getByText("Declined on this device")).toBeVisible();
  await page.waitForTimeout(300);
  const requestsAfterCrossTabRevocation = firstTabRequests.length;

  await page.reload();
  await expect(page.getByText("Declined on this device")).toBeVisible();
  await page.waitForTimeout(500);
  expect(firstTabRequests).toHaveLength(requestsAfterCrossTabRevocation);
  await secondTab.close();
});

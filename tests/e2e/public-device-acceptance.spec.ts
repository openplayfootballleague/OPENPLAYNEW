import { expect, test, type Page } from "@playwright/test";

const publicRoutes = ["/", "/match-centre", "/teams", "/join", "/more", "/sign-in"];
const viewports = [
  { name: "phone", width: 390, height: 844 },
  { name: "tablet", width: 820, height: 1180 },
  { name: "desktop", width: 1440, height: 900 },
];

async function mockSupabase(page: Page) {
  await page.route("http://127.0.0.1:54321/**", async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname.startsWith("/auth/v1/")) {
      if (url.pathname.endsWith("/session")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({ access_token: null, token_type: "bearer", user: null }),
        });
        return;
      }
      await route.fulfill({
        status: 401,
        contentType: "application/json",
        body: JSON.stringify({ message: "No test session", code: "not_authenticated" }),
      });
      return;
    }
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      headers: { "content-range": "0-0/0" },
      body: JSON.stringify([]),
    });
  });
}

for (const viewport of viewports) {
  for (const routePath of publicRoutes) {
    test(`${viewport.name}: ${routePath} renders without horizontal overflow`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await mockSupabase(page);
      const response = await page.goto(routePath);
      expect(response?.ok()).toBeTruthy();
      await expect(page.locator("body")).toBeVisible();
      await page.waitForLoadState("networkidle");
      const dimensions = await page.evaluate(() => ({
        viewport: document.documentElement.clientWidth,
        document: document.documentElement.scrollWidth,
        body: document.body.scrollWidth,
      }));
      expect(dimensions.document, `document overflow at ${routePath}: ${JSON.stringify(dimensions)}`)
        .toBeLessThanOrEqual(dimensions.viewport + 1);
      expect(dimensions.body, `body overflow at ${routePath}: ${JSON.stringify(dimensions)}`)
        .toBeLessThanOrEqual(dimensions.viewport + 1);
    });
  }
}

test("PWA manifest declares a standalone installable application", async ({ page }) => {
  await mockSupabase(page);
  await page.goto("/");
  const manifest = await page.evaluate(async () => {
    const response = await fetch("/manifest.webmanifest");
    if (!response.ok) throw new Error("PWA manifest could not be loaded");
    return response.json();
  });
  expect(manifest.name).toContain("Open Play");
  expect(manifest.display).toBe("standalone");
  expect(manifest.start_url).toBe("/");
  expect(manifest.icons.some((icon: { sizes: string }) => icon.sizes === "192x192")).toBeTruthy();
  expect(manifest.icons.some((icon: { sizes: string }) => icon.sizes === "512x512")).toBeTruthy();
});

test("service worker installs and the public home shell remains available offline", async ({ page, context }) => {
  await mockSupabase(page);
  await page.goto("/");
  await page.evaluate(async () => {
    if (!("serviceWorker" in navigator)) throw new Error("Service workers are unavailable");
    await navigator.serviceWorker.ready;
  });
  await page.reload();
  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
  });
  await context.setOffline(true);
  await page.goto("/", { waitUntil: "domcontentloaded" });
  await expect(page.locator("body")).toBeVisible();
  await expect(page.getByRole("heading").first()).toBeVisible();
});

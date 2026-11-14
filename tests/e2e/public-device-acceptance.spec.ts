import { expect, test, type Page } from "@playwright/test";

const publicRoutes = ["/", "/match-centre", "/teams", "/leagues", "/join", "/gallery", "/more", "/sign-in", "/sign-up", "/register-player", "/reset-password", "/privacy-security"];
// Owner specification section 16: 320, 375, 390 and 430 px phones, tablet and desktop.
const viewports = [
  { name: "phone-320", width: 320, height: 640 },
  { name: "phone-375", width: 375, height: 812 },
  { name: "phone", width: 390, height: 844 },
  { name: "phone-430", width: 430, height: 932 },
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
      const navigation = page.locator("nav.player-bottom-nav");
      if (await navigation.count()) {
        const layout = await navigation.evaluate((nav) => {
          const links = [...nav.querySelectorAll("a")];
          return {
            rows: new Set(links.map((link) => Math.round(link.getBoundingClientRect().top))).size,
            clipped: links.some((link) => [...link.querySelectorAll("span")].some((label) => label.scrollWidth > label.clientWidth + 1)),
            outside: links.some((link) => { const r = link.getBoundingClientRect(); return r.left < -1 || r.right > innerWidth + 1; }),
            labels: links.map((link) => link.textContent?.trim()),
          };
        });
        expect(layout.rows, `bottom navigation wraps at ${routePath}: ${JSON.stringify(layout)}`).toBe(1);
        expect(layout.clipped, `bottom navigation label clipped at ${routePath}`).toBe(false);
        expect(layout.outside, `bottom navigation item off-screen at ${routePath}`).toBe(false);
      }
      const header = page.locator("header.global-header");
      if (await header.count()) {
        const overlap = await header.evaluate((element) => {
          const boxes = [...element.querySelectorAll(".global-header-brand, .global-header-bell, .global-header-signin, .global-header-avatar, .global-header-location")]
            .map((child) => child.getBoundingClientRect()).filter((box) => box.width > 0);
          return boxes.some((a, i) => boxes.some((b, j) => j > i && a.right > b.left + 1 && b.right > a.left + 1 && a.bottom > b.top + 1 && b.bottom > a.top + 1));
        });
        expect(overlap, `header controls overlap at ${routePath}`).toBe(false);
      }
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

// Regression (2026-11-14): these routes were nested under parents without an <Outlet/> and rendered
// the parent page instead of their own. Each must show its own workspace label when signed out.
const ownPages: [string, RegExp][] = [
  ["/admin/analytics", /ADMIN ANALYTICS/i],
  ["/admin/referees", /REFEREE ADMIN/i],
  ["/admin/retention", /PLAYER RETENTION ADMIN/i],
  ["/admin/guardian-consents", /GUARDIAN CONSENT ADMIN/i],
  ["/referee/matchday", /REFEREE MATCHDAY/i],
  ["/referee/report/00000000-0000-4000-8000-000000000001", /REFEREE MATCH REPORT/i],
];
for (const [routePath, label] of ownPages) {
  test(`${routePath} renders its own page, not its parent's`, async ({ page }) => {
    await mockSupabase(page);
    await page.goto(routePath);
    await expect(page.getByText(label).first()).toBeVisible({ timeout: 15_000 });
  });
}

test("a team link opens the team hub, not the directory", async ({ page }) => {
  await mockSupabase(page);
  await page.goto("/teams/00000000-0000-4000-8000-000000000001");
  await expect(page.getByRole("heading", { name: /all teams in your league/i })).toHaveCount(0);
  await expect(page.getByText(/team is unavailable|couldn't load this team/i)).toBeVisible({ timeout: 15_000 });
});

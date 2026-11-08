import { defineConfig } from "@playwright/test";

const baseURL = "http://127.0.0.1:4173";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: false,
  workers: 1,
  timeout: 30_000,
  expect: { timeout: 5_000 },
  reporter: "list",
  use: {
    baseURL,
    browserName: "chromium",
    headless: true,
    serviceWorkers: "block",
    trace: "retain-on-failure",
  },
  webServer: {
    command: "npm run dev -- --host 127.0.0.1 --port 4173",
    url: `${baseURL}/privacy-security`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: {
      ...process.env,
      VITE_POSTHOG_PROJECT_TOKEN: "phc_openplay_browser_test_only",
      VITE_POSTHOG_HOST: "https://eu.i.posthog.com",
      VITE_POSTHOG_PRIVACY_SETTINGS_VERIFIED: "true",
      VITE_SUPABASE_URL: "http://127.0.0.1:54321",
      VITE_SUPABASE_ANON_KEY: "test-anon-key",
    },
  },
});

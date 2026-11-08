# Browser acceptance tests

The analytics-consent Playwright suite runs against the local Node-based TanStack Start dev server using a fake PostHog project token and an EU host URL. Every request to the PostHog host is intercepted by Playwright and fulfilled locally; no test event is sent to PostHog.

The suite verifies that the SDK makes no PostHog requests before explicit opt-in, that same-tab and cross-tab revocation stop further requests, and that Global Privacy Control overrides a previously saved opt-in.

Run with `npx playwright test --config=playwright.config.ts` after installing `@playwright/test` and Chromium.

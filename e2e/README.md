# Playwright end-to-end tests

This repository uses Playwright for browser-level smoke and journey tests. These tests are separate from the existing Vitest domain/unit tests.

## Install locally

```bash
npm install --no-save --package-lock=false @playwright/test
npx playwright install chromium
```

## Run

```bash
npx playwright test
```

The Playwright config starts the Vite development server automatically at http://127.0.0.1:4173. Set `PLAYWRIGHT_BASE_URL` to test an already-running deployment instead.

CI installs the Playwright runner without changing the committed application dependency lockfile, installs Chromium, and runs the browser smoke tests after the existing build checks. Add authenticated or destructive journeys only with dedicated test accounts and isolated test data.

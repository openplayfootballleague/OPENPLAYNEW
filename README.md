# Open Play

The official Open Play football league platform.

## Phase 1 — Application foundation

This repository is the clean foundation for the Open Play platform.

- **Framework:** TanStack Start (React + TypeScript)
- **Hosting target:** Cloudflare Workers
- **Backend:** Supabase Auth + Postgres (new Open Play project)
- **Repository:** openplayfootballleague/OPENPLAYNEW

## Local development

Requirements: Node.js 22+ and npm.

```bash
npm install
npm run dev
```

Open the local URL printed by Vite (normally http://localhost:3000).

## Automated verification

GitHub Actions installs the locked dependencies, runs domain tests, TypeScript and production builds, then validates the Cloudflare Worker bundle with a dry run. The dry run does not publish a deployment.

## Build and preview

```bash
npm run build
npm run preview
```

## Install Open Play as an app

The site includes a web app manifest, install icons and a service worker.

- On iPhone or iPad, open the site in Safari, use **Share**, then choose **Add to Home Screen**.
- On supported Android and desktop browsers, use the browser's **Install app** action.
- The service worker caches the public home page and static brand assets only. It does not cache sign-in, account, API or other private page responses.

## Cloudflare

The project is configured for Cloudflare Workers through the official Cloudflare Vite plugin.

```bash
npm run deploy
```

Deployment requires Cloudflare authentication and the project to be configured in the Cloudflare dashboard.

## Environment

Copy `.env.example` to `.env` for local development. It contains only the public Supabase URL and publishable key. Configure server-only secrets in Cloudflare Worker secrets; never commit service-role or secret keys.

## Account onboarding

- `/sign-up` creates an authenticated account and requires email verification when enabled in Supabase Auth.
- `/sign-in` supports email/password sign-in and password-reset email requests.
- `/register-player` calls the `register_player` database RPC for a signed-in user. Account creation alone does not create a player or grant a team role.
- Configure the Supabase Auth site URL and redirect allow-list to include the deployed Open Play origin and local development origin before testing email links.

## Project principles

- No production secrets or service-role keys in browser code.
- No fake authentication, payments, or database success states.
- All privileged actions must be enforced server-side.
- Supabase schema changes will be versioned as migrations.

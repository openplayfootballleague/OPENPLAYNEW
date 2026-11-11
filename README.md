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

## Production domain

The production Worker is configured to serve both custom domains:

- `https://openplayfootball.co.uk`
- `https://www.openplayfootball.co.uk`

Both hostnames are declared as Cloudflare Worker custom domains in `wrangler.jsonc`. Before deploying, the `openplayfootball.co.uk` zone must be active in the same Cloudflare account used by Wrangler. Authenticate with `npx wrangler login`, then run `npm run deploy`. Wrangler/Cloudflare provisions the custom-domain DNS records and TLS certificates; do not add conflicting A, AAAA, or CNAME records manually.

After deployment, update Supabase Authentication URL Configuration:

- Site URL: `https://openplayfootball.co.uk`
- Additional Redirect URLs: `https://openplayfootball.co.uk/**`, `https://www.openplayfootball.co.uk/**`, and the required local development URL.

Also update any external provider callback/return URL allow-lists to use the production origin. Do not remove existing working origins until sign-in, email verification, password reset, and payment return flows have been tested on the new domain.

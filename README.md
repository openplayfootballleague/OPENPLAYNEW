# Open Play

The official Open Play football league platform.

## Phase 1 — Application foundation

This repository is the clean foundation for the Open Play platform.

- **Framework:** TanStack Start (React + TypeScript)
- **Hosting target:** Cloudflare Workers
- **Backend target:** Supabase (connected in a later phase)
- **Repository:** openplayfootballleague/OPENPLAYNEW

## Local development

Requirements: Node.js 22+ and npm.

```bash
npm install
npm run dev
```

Open the local URL printed by Vite (normally http://localhost:3000).

## Automated verification

GitHub Actions installs the locked dependencies, runs TypeScript and production builds, then validates the Cloudflare Worker bundle with a dry run. The dry run does not publish a deployment.

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

Copy `.env.example` to `.env` when Supabase is connected. Never commit real credentials.

## Project principles

- No production secrets or service-role keys in browser code.
- No fake authentication, payments, or database success states.
- All privileged actions must be enforced server-side.
- Supabase schema changes will be versioned as migrations.

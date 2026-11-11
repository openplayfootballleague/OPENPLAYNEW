# Open Play New — PostHog integration and privacy plan

**Status:** consent foundation implemented; SDK integration and event capture not yet active  
**Date:** 8 November 2026  
**Application:** TanStack Start / React / Supabase / Cloudflare Workers

## 1. Verified PostHog project

The connected PostHog account exposes one project, so there is no project-selection ambiguity.

- Project name: `Default project`
- Project ID: `336500`
- Region: **EU Cloud**
- Ingestion host: `https://eu.i.posthog.com`
- Project token: available from the connected PostHog project configuration; do not copy it into Git or documentation.
- Project timezone: UTC.
- The project currently has an SDK integration in the development branch, but its runtime is deliberately gated off until the project-level console-log capture setting is disabled and verified. The presence of the PostHog project does not mean Open Play app events are being captured.

The active project is the sole project returned by the connected PostHog organization listing. Its name is generic; if a separately named production/staging project is created later, the app environment must be explicitly mapped to the correct project.

## 2. Repository baseline

The inspected application uses TanStack Start with React, Vite, Supabase and Cloudflare Workers. Before this work:
- no PostHog SDK package was present in `package.json`;
- no PostHog provider or SDK initialisation was present in `src/routes/__root.tsx`;
- no typed application event capture module was present;
- no PostHog environment variables were present.

The repository now has:
- `@posthog/react`, `posthog-js` and `posthog-node` installed through npm with a committed lockfile;
- `VITE_POSTHOG_PROJECT_TOKEN` placeholder in `.env.example`;
- `VITE_POSTHOG_HOST=https://eu.i.posthog.com` in `.env.example`;
- a local-device consent helper in `src/lib/analytics/consent.ts`;
- seven consent unit tests in `src/lib/analytics/consent.test.ts`;
- an allow-listed event contract and property sanitizer in `src/lib/analytics/events.ts`, with tests;
- a consent banner for visitors and a preference control in Privacy & Security;
- a conditional `PostHogProvider` at the TanStack root in `src/components/analytics-provider.tsx`.

No project token has been committed and no production environment variable has been configured. The provider stays unmounted unless the EU host and project token are present and the user has explicitly opted in.

## 3. Consent implementation

The new helper uses a versioned browser-local preference key: `open-play.analytics-consent.v1`.

Rules:
1. No saved choice means `unset`; analytics are not allowed.
2. Only an explicit `granted` choice permits analytics.
3. An explicit `denied` choice blocks analytics.
4. Global Privacy Control overrides any saved opt-in and forces denial.
5. If browser storage is unavailable, the implementation fails closed and does not grant analytics.
6. The Privacy & Security screen explains that the preference is stored on this device.
7. The screen states clearly that analytics capture is not yet active in this build.

The root now mounts `PostHogProvider` only when the EU host/token are configured and the local preference is explicitly granted with GPC absent. It sets `opt_out_capturing_by_default` and then opts in only from the consent-aware child. Revocation broadcasts a same-tab event; the active SDK opts out before the provider is unmounted. Cross-tab storage changes and page visibility changes are also rechecked. No user identification is performed.

## 4. Data collection policy

Open Play analytics must measure product usage, not operate as a second source of truth.

Allowed event properties should be limited to non-sensitive operational metadata such as:
- feature/action name;
- route category or allow-listed route template (never arbitrary query strings);
- success/failure category and non-sensitive error code;
- competition format or location identifier only where necessary and permission-safe;
- coarse device class where useful.

Never send:
- names, email addresses, phone numbers, dates of birth or emergency contacts;
- player registration answers, fitness/medical information or private profile fields;
- message bodies, support case contents or report details;
- passwords, authentication tokens, session cookies or request headers;
- payment card details, bank information, payment references or financial ledger records;
- raw URLs containing query strings, invitation codes or other identifiers.

Supabase remains the authority for player registration, memberships, fixtures, results, finance and audit data. PostHog is only for consented product usage and journey analysis.

Do not identify users with email, name, phone or other direct identifiers. Any future pseudonymous stable identifier must be justified, consent-gated and reviewed against the data minimisation requirement. Privileged admin/finance activity must be excluded from ordinary product analytics.

## 5. Session replay and automatic collection

The connected PostHog project settings currently show session recording, heatmaps, web-vitals, console-log and performance collection as enabled/opted-in at the project level. This repository does not currently initialise the SDK, so these settings alone are not evidence that Open Play app data is being captured.

The current provider explicitly configures:
- `autocapture: false`;
- `capture_pageview: false` and `capture_pageleave: false` (navigation is tracked only through the allow-listed custom event);
- `capture_dead_clicks: false` and `rageclick: false`;
- `capture_exceptions: false`;
- `capture_heatmaps: false`;
- `capture_performance: false` (disables web-vitals and network timing);
- `disable_session_recording: true`;
- `logs.captureConsoleLogs: false`;
- `opt_out_capturing_by_default: true`;
- feature flags, surveys, product tours and conversations disabled until required.

The initial route tracker emits only `navigation_section_viewed`, using a fixed route-category allow-list. It resolves the actor from Supabase: anonymous visitors and approved, non-banned players may be included after consent; admin, super_admin, finance_admin, league_admin and unresolved actors are excluded. The event helper drops unknown properties, direct identifiers, arbitrary URLs and free-form error text.

Do not enable session replay, heatmaps, web vitals, console logs, exception capture or broad autocapture by changing project defaults. Any future change requires a separate privacy purpose, consent and masking review.

## 6. Planned SDK setup

The current PostHog TanStack Start guidance recommends `@posthog/react` for the browser and `posthog-node` for server-side events. Install through npm in a network-enabled workspace and commit the resulting lockfile; do not hand-edit the lockfile.

Environment:
- `VITE_POSTHOG_PROJECT_TOKEN`: public project ingestion token from the selected PostHog project; set locally/deployment-side only.
- `VITE_POSTHOG_HOST`: `https://eu.i.posthog.com`.

The provider must be conditional on the consent state. Keep default pageview/autocapture/replay options explicit rather than inheriting broad project defaults. Server-side capture, if added, must be limited to non-spoofable business events and must use the same consent/identity policy; do not emit authentication, payment or sensitive profile payloads.

## 7. Event taxonomy and instrumentation status

The typed allow-list in `src/lib/analytics/events.ts` defines the permitted event names. Current client call sites instrument:
- `navigation_section_viewed` (fixed route categories only);
- `account_signup_started` and `account_signup_completed`;
- `player_registration_started` and `player_registration_submitted`;
- `team_registration_started` and `team_registration_submitted`;
- `player_join_request_submitted`;
- `fixture_viewed` and `result_viewed`;
- `team_profile_viewed` and `player_profile_viewed`;
- `workflow_error` with a generic allow-listed error code only.

The event contract also reserves names for later implementation, including email verification, onboarding completion, location/season selection, gallery/announcement views, feature interactions and data-load failures. They are not claimed as captured until real call sites are added and verified.

No administrative approval, finance action, role-management, support-message or moderation event is captured. These privileged workflows remain in the authoritative Supabase audit trail, not ordinary product analytics.

Do not treat account creation as player registration. Do not record event properties containing personal data, message content, payment data or direct identifiers.


## 9. Latest implementation verification

- GitHub Actions run `42483814025` completed successfully for the consent-aware provider/event implementation: 12 test files / 96 tests passed, Deno Edge Function type-check passed, Vite client and SSR production builds passed, TypeScript passed, and Cloudflare Worker dry-run passed.
- The later direct `posthog-js` dependency/lockfile update was generated with npm in a branch-scoped GitHub Actions workflow; that temporary workflow has been removed.
- A fresh full CI run is still required for the final lockfile head.
- Deployment-side `VITE_POSTHOG_PROJECT_TOKEN` and `VITE_POSTHOG_HOST` are not yet configured.
- The connected PostHog project has `capture_console_log_opt_in=true`. PostHog documentation states project-level console-log capture can enable collection independently of the SDK's local logs option. The project-settings update tool requires user confirmation before changing project settings, so this was not changed.
- The app now additionally requires `VITE_POSTHOG_PRIVACY_SETTINGS_VERIFIED=true` before mounting the SDK or showing the consent banner. The example value is `false`. Only set it to true after the project-level console-log setting is disabled and independently verified. Until the token, host and privacy gate are configured, no Open Play events are sent.
- No server-side events are implemented; `posthog-node` is installed for the later server-side integration, which must remain consent/identity gated and must not emit sensitive business data.

## 8. Verification and release gates

Before enabling PostHog in any deployed environment:
1. Install SDK packages through npm and verify the committed lockfile.
2. Add provider initialisation only after explicit consent; verify no network request or event before opt-in.
3. Verify opt-out and GPC suppress events and revoke the SDK session.
4. Verify admin/finance users and protected admin routes are excluded.
5. Verify no PII, message content, private registration data or payment data appears in captured properties.
6. Verify the correct EU ingestion host and selected project token are used.
7. Verify server-side events do not trust client-supplied identity or event properties.
8. Run unit tests, TypeScript, production build and Cloudflare Worker dry-run.
9. Inspect the PostHog live events schema after an approved test event, then build the Analytics & Reports workspace against verified event names.

No PostHog event has been sent by this repository implementation. No PostHog project setting, secret, production environment variable or deployment was changed as part of this work.

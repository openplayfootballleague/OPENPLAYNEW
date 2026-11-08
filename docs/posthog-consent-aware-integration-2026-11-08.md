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
- The project currently has no Open Play app SDK integration in this repository, so the presence of the PostHog project does not mean Open Play app events are being captured.

The active project is the sole project returned by the connected PostHog organization listing. Its name is generic; if a separately named production/staging project is created later, the app environment must be explicitly mapped to the correct project.

## 2. Repository baseline

The inspected application uses TanStack Start with React, Vite, Supabase and Cloudflare Workers. Before this work:
- no PostHog SDK package was present in `package.json`;
- no PostHog provider or SDK initialisation was present in `src/routes/__root.tsx`;
- no typed application event capture module was present;
- no PostHog environment variables were present.

The repository now has:
- `VITE_POSTHOG_PROJECT_TOKEN` placeholder in `.env.example`;
- `VITE_POSTHOG_HOST=https://eu.i.posthog.com` in `.env.example`;
- a local-device consent helper in `src/lib/analytics/consent.ts`;
- seven unit tests in `src/lib/analytics/consent.test.ts`;
- a user-facing preference control in Privacy & Security.

No project token has been committed. No SDK dependency has been added yet because the available execution environment cannot reach npm/GitHub to generate and verify the lockfile; the package manager install must be completed in a network-enabled development environment.

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

The helper deliberately does not initialise PostHog. It is the prerequisite consent gate; the SDK must be mounted/initialised only after the helper confirms an explicit grant and GPC is absent. Revocation must immediately stop capture, opt the user out, and reset any identified session state.

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

When the SDK is installed:
- do not initialise the provider before explicit consent;
- disable autocapture by default;
- disable session replay, heatmaps, console logs and performance capture unless a separate purpose, consent and masking review explicitly approves them;
- never capture message/support content or private registration forms;
- exclude all privileged administrator and finance screens from product analytics;
- disable automatic exception capture unless the event payload is demonstrably free of personal/sensitive data;
- do not use session replay as a default or silently enable it through PostHog project defaults.

The initial integration should use minimal custom events only and should not turn on session replay or broad autocapture.

## 6. Planned SDK setup

The current PostHog TanStack Start guidance recommends `@posthog/react` for the browser and `posthog-node` for server-side events. Install through npm in a network-enabled workspace and commit the resulting lockfile; do not hand-edit the lockfile.

Environment:
- `VITE_POSTHOG_PROJECT_TOKEN`: public project ingestion token from the selected PostHog project; set locally/deployment-side only.
- `VITE_POSTHOG_HOST`: `https://eu.i.posthog.com`.

The provider must be conditional on the consent state. Keep default pageview/autocapture/replay options explicit rather than inheriting broad project defaults. Server-side capture, if added, must be limited to non-spoofable business events and must use the same consent/identity policy; do not emit authentication, payment or sensitive profile payloads.

## 7. Event taxonomy to implement after SDK installation

Candidate minimal events:
- `account_signup_completed` (no email or identity fields);
- `email_verification_completed`;
- `player_registration_started`;
- `player_registration_submitted`;
- `player_registration_decision_viewed`;
- `team_registration_started`;
- `team_registration_submitted`;
- `team_membership_request_submitted`;
- `team_membership_decision_recorded` (only safe aggregate metadata; exclude privileged actor data);
- `location_season_selected`;
- `fixture_details_viewed`;
- `notification_preferences_updated`.

Event names and properties must be reviewed against the actual code paths before capture is added. Do not treat account creation as player registration. Do not record event properties containing personal data or private IDs.

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

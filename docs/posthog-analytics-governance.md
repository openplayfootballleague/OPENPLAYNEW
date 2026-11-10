# Open Play consent-first product analytics

## Release gate

Browser analytics is disabled by default. The SDK is not initialized unless all three conditions hold:

1. A PostHog project token and host are supplied through environment variables.
2. The visitor explicitly opts in on this browser.
3. `VITE_POSTHOG_PRIVACY_SETTINGS_VERIFIED=true` is set only after the PostHog project privacy settings have been checked and approved.

The committed `.env.example` intentionally leaves the project token blank and the verification flag false. Do not change that flag in a production deployment until the privacy and data-flow review is signed off.

## Privacy controls

- EU Cloud ingestion host is configured through `VITE_POSTHOG_HOST`; no token or host is hard-coded in source.
- IP anonymisation is enabled in the PostHog project.
- The SDK explicitly disables autocapture, rage clicks, dead clicks, pageviews/pageleave, exception capture, heatmaps, performance capture, session replay, surveys, product tours, conversations and console-log capture.
- Consent is stored locally as `open-play.analytics-consent.v1`; storage failures fail closed.
- Global Privacy Control overrides a saved opt-in. Same-tab changes, cross-tab storage changes and foreground visibility changes are observed.
- Revocation opts out and resets the SDK identity.
- Only a stable Supabase UUID is used for an identified account. No email, phone, name, date of birth, private message, payment detail, raw URL or raw error text is sent.
- Analytics events use a fixed event-name set and an allow-list of validated low-risk properties.
- Admin, super-admin, finance-admin, league-admin, banned, disciplined-inactive, closed and unverified accounts are excluded from product analytics.

## Current event coverage

- Account signup started/completed.
- Player registration submitted.
- Player join request submitted.
- Team registration submitted.
- Navigation section viewed.
- Workflow errors use only a coarse allow-listed feature and error code.

The event helper is client-side and captures only after explicit consent. It is not an authoritative business ledger. Trusted server-side capture for security-sensitive or financially meaningful events remains outstanding and must be added before enabling production ingestion.

## Browser acceptance

`npm run test` covers consent state, GPC override, fail-closed storage, actor resolution and event-property sanitisation. The dedicated Playwright workflow uses a synthetic test token and intercepts all PostHog network traffic; it never sends test events to the real PostHog project.

## Remaining release tasks

- Verify and record PostHog project-level autocapture, exception, replay, console-log and retention settings.
- Complete legal/privacy review and confirm the controller identity/contact details.
- Implement authenticated trusted server-side event capture for approved server-confirmed events.
- Configure the production public project token and host only after review; keep the verification flag false until all gates pass.
- Confirm that a consent withdrawal on one device is handled according to the final privacy notice; browser-local consent is not account-wide consent.

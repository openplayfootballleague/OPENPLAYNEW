# PostHog consent and environment setup

Open Play uses the existing EU Cloud PostHog project only after a person explicitly opts in.

## Required environment values

Set these as public build-time variables in the application build environment (Cloudflare Pages/Workers or the deployment pipeline):

- `VITE_POSTHOG_KEY`: the project's public PostHog project API key.
- `VITE_POSTHOG_HOST`: `https://eu.i.posthog.com` for the retained EU Cloud project.

The project API key is designed for browser capture and is not a secret. Never put a personal API key or a server-side management key in a `VITE_*` variable.

## Current collection boundary

- No event is sent until explicit opt-in.
- A visitor can reject or withdraw consent from More → Analytics preferences.
- Only manually-triggered page-view events and the consent event are sent.
- Page paths are sent without query strings and UUID/numeric path segments are replaced with `:id`.
- After consent, the Supabase Auth UUID is used as the PostHog distinct ID; logout rotates to a fresh anonymous ID.
- Capture requests omit credentials and disable IP enrichment (`ip=0`).
- Person-profile processing is disabled.
- Autocapture, session replay, heatmaps and automatic pageview capture are not enabled.
- Analytics failures never block application functionality.

## Release prerequisites

1. Confirm the configured key belongs to the retained EU Cloud project.
2. Verify the app's privacy notice explains purpose, lawful basis, recipients, international transfers (if any), retention and withdrawal.
3. Use a disposable account to verify no network capture occurs before consent, rejection persists, opt-in begins capture, Auth identity is used after consent, logout resets identity, and withdrawal stops subsequent capture.
4. Confirm the existing 749 historical events remain untouched and follow the project's configured retention.
5. Complete privacy/legal review before production release.

This client-side integration does not yet implement trusted server-side event capture. Do not enable session replay or autocapture as part of environment setup.

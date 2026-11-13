# OneSignal push notifications — deployment and privacy setup

## What is implemented

- The browser SDK is loaded only when `VITE_ONESIGNAL_APP_ID` is present. The root provider links the signed-in Supabase user UUID as the OneSignal external ID; it never asks for browser permission automatically.
- A user explicitly enables push from Privacy & Security. The browser permission prompt is initiated only by that button.
- OneSignal external IDs support multiple browser/device subscriptions per Open Play account. The device manager lists safe display metadata and verifies that a subscription belongs to the signed-in user before revoking it.
- Push preference is written server-side only after OneSignal confirms at least one active push subscription. Removing the last active device turns the account push preference off.
- The notification outbox can queue `push` alongside email and SMS. Category preferences are stored per user and applied before events are enqueued; critical account-security events are deliberately not category-switchable.
- Push content is generic on lock screens. Detailed reasons, names, phone numbers, email addresses, dates of birth and raw event payloads are not included.
- Deep links are restricted to known in-app destinations (Messages, Match Centre, Player Hub, Referee Workspace or Notifications).
- Outbox retry/backoff is retained. OneSignal receives the notification event UUID as its idempotency key, preventing duplicate sends when a provider response is uncertain.
- The existing PWA service worker is reused. OneSignal's worker import is optional so a CDN outage cannot prevent the offline app shell from installing.

## Required configuration (not set by this change)

Set the public app ID in the web build environment:

- `VITE_ONESIGNAL_APP_ID`

Set these Supabase Edge Function Secrets:

- `ONESIGNAL_APP_ID`
- `ONESIGNAL_REST_API_KEY` — use a least-privilege REST API key that can create notifications and manage users/subscriptions for this app.
- `APP_ORIGIN` — the exact canonical HTTPS origin used for push deep links, without a path, query or fragment.

The public app ID is not a secret. The REST API key must never be exposed to the browser, committed to Git, written to logs or placed in Vite environment variables.

## OneSignal dashboard setup

1. Create/configure a OneSignal Web Push app for the exact Open Play HTTPS origin.
2. Confirm the browser platform and web push domain are correct.
3. Keep the app's external ID alias enabled; Open Play uses the signed-in Supabase Auth UUID as that external ID.
4. Configure the service worker path as `/onesignal/OneSignalSDKWorker.js` with scope `/onesignal/`. This is separate from the root-scoped Open Play PWA worker.
5. Use a project-scoped REST API key with only the access required for notification creation and subscription/user management.
6. Add the three server-side secrets and the public build variable above. Do not use live credentials in CI.

## Notification categories

- Match & referee updates
- Team & membership updates
- Club messages
- Competition announcements
- Support updates

Critical account-security notifications are always retained in the in-app notification centre and cannot be disabled by category controls. Optional email, SMS and push channels still follow the account's channel preferences. Category controls apply to new notifications; changing a preference does not erase existing in-app history.

## Release gates

- No OneSignal App ID or REST API key has been added to this repository or Supabase.
- No push has been sent to a real device.
- The feature remains unavailable in environments without the public App ID and server secrets.
- CI validates SQL migration replay, category controls, device ownership policy, generic push payloads and deep-link construction without contacting OneSignal.
- A production delivery smoke test must be performed only after the user has configured the OneSignal app and explicitly approved a test notification.

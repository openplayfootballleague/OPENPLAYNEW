# Open Play browser and device acceptance campaign

## Automated CI coverage

The Playwright smoke suite runs against the production Vite build with an isolated mock Supabase endpoint. It does not use production credentials or data.

- Public route smoke: Home, Match Centre, Teams, Join Open Play, More and Sign In.
- Responsive viewport checks: 390px phone, 820px tablet and 1440px desktop.
- No horizontal document/body overflow.
- PWA manifest name, standalone display mode, start URL and icon sizes.
- Service-worker installation and offline public-home fallback.

## Physical-device acceptance matrix

These checks require real devices and must be recorded before public launch. A desktop browser emulation is not a substitute for iOS/Android push and installation testing.

| Platform | Required checks |
| --- | --- |
| iPhone Safari (iOS 16.4+) | Add to Home Screen, standalone launch, sign-in, keyboard/viewport behavior, push opt-in after a user gesture, lock-screen notification, deep-link return |
| iPad Safari (iPadOS 16.4+) | Add to Home Screen, portrait/landscape layouts, fixed navigation, team-sheet editing, push opt-in and delivery |
| Android Chrome | Install prompt, standalone launch, push opt-in, lock-screen delivery, offline/reconnect, deep links |
| Desktop Chrome / Edge | Installability, responsive layouts, auth, captain/admin workflows, notifications and payment checkout return |
| Desktop Firefox | Core public and authenticated navigation, forms, layout and error recovery |
| Desktop Safari | Core navigation, auth, forms, PWA shell behavior and privacy controls |

## Authenticated role-based acceptance

Use dedicated test accounts and non-production Stripe test mode.

- Player: registration, DOB/guardian flow, profile, team requests, transfer requests, team sheet visibility, season statistics, inbox and notification preferences.
- Captain: team creation, membership approvals, transfers, availability, team sheets, weekly payment deadline, grace-period countdown, payment success/cancel return, refund status.
- Referee: application, appointment availability, match report submission, rejected report correction, Connect onboarding and payout status.
- Administrator: location-scoped access, report approval and correction, fixture generation/editing, weather postponement, refunds, gameweek renumbering, payment exceptions and audit history.
- Finance administrator: payment ledger reconciliation, failed refunds and payout obligations.

## Security and privacy checks

- Confirm non-members cannot read private messages or team/payment records.
- Confirm direct message blocking, reporting, rate limits and role-based conversation access.
- Confirm analytics remains disabled until explicit consent; reject must prevent SDK initialization and event capture.
- Confirm message bodies, phone numbers, DOB, disciplinary details and payment data never enter analytics properties or push lock-screen previews.
- Confirm push/email/SMS respect individual preferences and consent.
- Confirm service worker never caches authenticated API, auth, inbox or payment responses.
- Confirm sign-out, account retention and reactivation gates work on each role.

## Sign-off status

- Automated Chromium public-route and PWA smoke: run by CI.
- SQL/RLS/domain regressions: run by CI.
- Physical iOS/iPadOS/Android push, installation and lock-screen checks: pending real-device execution.
- Live Stripe Connect and live payment acceptance: intentionally not run; test mode only until production credentials and finance approval are configured.

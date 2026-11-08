# Global Account Hub, Messaging and Notifications — Implementation Plan

Status: approved scope; staged implementation in progress
Repository: `openplayfootballleague/OPENPLAYNEW`
Stack: TanStack Start, Supabase, OneSignal, PostHog, installable PWA

## 1. Existing architecture inventory

### Authentication and routes
- Supabase Auth client is centralised in `src/lib/supabase/client.ts`.
- Existing routes provide sign-in, sign-up, reset-password and Player Hub flows.
- Account creation remains distinct from player registration and captain/admin roles.
- Shared header/navigation is `src/components/site-navigation.tsx`; it currently derives player, captain, admin and finance access from Supabase records.

### Identity and profile
- `public.profiles` is keyed by the authenticated user ID and already contains `avatar_path`.
- `public.players` is a separate registration/eligibility record; do not duplicate it.
- `profile-avatars` Storage bucket already accepts JPEG, PNG and WebP up to 5 MB.
- Storage policies permit public reads and authenticated writes/updates/deletes only within the user's own UUID folder.
- The Player Hub currently offers general identity fields for editing. The approved scope supersedes that UI: Edit Profile must become profile-picture-only. Official identity changes belong to a controlled support/admin correction workflow.

### Membership and permissions
- Existing `team_memberships`, `season_teams`, `players`, and `user_roles` structures remain authoritative.
- Active captain membership and role assignments must continue to control captain/admin navigation and access.
- Account creation, player registration, team registration and captain approval must remain separate.

### Notifications
- Existing `notification_events` is a per-recipient, per-channel event/outbox table with status, retry, deduplication, error and read timestamps.
- Existing `notification_preferences` currently has email, SMS and in-app preferences.
- Existing secure delivery Edge Function handles email/SMS; the notification outbox and database dispatch safeguards must be extended, not replaced.
- No existing conversations, messages or device-subscription tables were found in the inspected public schema.
- OneSignal integration and web-push device registration remain to be implemented/configured.

### PWA and analytics
- PWA manifest/service worker file locations and installation behaviour require a dedicated follow-up inspection; do not assume iOS push readiness.
- PostHog consent constraints remain mandatory: no analytics capture before explicit opt-in, no message contents or sensitive identity data, no replay/autocapture without explicit consent.

## 2. Target architecture and data boundaries

- Supabase Auth remains the account identity authority.
- `profiles.avatar_path` remains the single canonical avatar reference.
- `players` remains the official player registration/eligibility record.
- `team_memberships` and role records remain the authority for team and administrative access.
- Add conversation/message/participant/read-state tables only after designing membership lifecycle, support visibility, blocking/reporting and retention rules.
- Keep `notification_events` as the shared internal notification centre and delivery outbox. Add OneSignal delivery as another provider/channel through secure server-side processing, not a separate notification store.
- Add per-user device subscription records with unique provider subscription IDs, authenticated ownership, revocation and last-seen metadata.
- Notification delivery failure must never roll back an internal notification or persisted message.
- Never expose service-role or OneSignal REST credentials to the browser.

## 3. Controlled delivery phases

1. **Architecture inspection and plan** — complete initial inventory; inspect all relevant RLS policies, RPCs, auth settings, PWA files and route coverage before schema changes.
2. **Global account access** — signed-out icon, authenticated avatar, account menu, role-aware links, unread indicator, auth-state/profile synchronisation.
3. **My Account** — identity/status and real counts, linking to existing team and notification records; no fabricated values.
4. **Picture-only profile editor** — validated image selection, crop/preview/confirm, secure upload and central avatar refresh; remove general identity edits from this editor.
5. **Messaging** — schema/RLS/RPC design, conversations, participants, messages, read state, admin targeting, team access, support, rate limits and abuse controls.
6. **Notifications and devices** — event taxonomy, preference categories, OneSignal Edge Function, multi-device registration, deduplication/retries and deep links.
7. **Security and support** — verified email/phone change flows, device revocation, privacy settings, support workflows and audit records.
8. **Acceptance and release** — automated, isolated DB, role, browser, PWA/iOS/iPad and production deployment verification.

## 4. Security and acceptance gates

- Every new table has RLS enabled and tested with owner, unrelated user, captain, location admin, global admin, anonymous and service-role cases as applicable.
- Private messages/support threads are inaccessible to unrelated users.
- Message sends and broadcasts validate sender permission and recipient scope server-side.
- Device registration binds to the authenticated user; users cannot register or revoke another user's device.
- Avatar object paths are scoped to `auth.uid()`; profile updates cannot alter locked identity fields.
- Email/phone values remain unchanged until provider verification succeeds.
- Push permission is requested only after an explicit user action and supported PWA installation checks.
- Internal notification records remain available when OneSignal is unavailable.
- PostHog events contain only non-sensitive action metadata and are consent-gated.
- No production migration or deployment until isolated replay, role tests and CI pass.

## 5. Current code change

The shared header has an initial account button/menu implementation in the development branch. It reads the signed-in profile avatar, registered player status, active captain membership, platform roles and unread in-app notification count from existing Supabase records. This is source implementation only; CI, browser behaviour and the newly linked destination routes still require verification.

# Open Play secure messaging architecture

Status: design draft; **not approved for migration or production application**
Scope: direct messages, team conversations, league-admin announcements, support conversations, read state, blocking/reporting and abuse controls.

## Non-negotiable security invariants

1. Every conversation read is authorised by an active row in `conversation_participants`; possession of a UUID is never sufficient.
2. A sender can insert only as `auth.uid()`, while an active participant, when the conversation is open, and when the recipient has not blocked them.
3. Clients cannot create privileged conversation types, add arbitrary participants, promote participants, or broadcast announcements by writing tables directly.
4. Team conversation access is derived from current active `team_memberships` and the associated `season_teams`; leaving, suspension, transfer or removal revokes access. Historical message retention is a separate explicit product policy.
5. Support conversations are visible only to the requesting user and explicitly authorised support staff. General league-admin status is not automatically support access.
6. Announcement creation and recipient expansion happen in a server-side RPC/Edge Function after checking global or location-scoped authority. Recipient sets are snapshotted, and the sender cannot supply an arbitrary user ID list.
7. Blocking prevents new direct conversation messages in both directions; it does not silently erase historical messages or affect official league notices.
8. Message bodies are never sent to analytics, push payloads, logs, error telemetry or notification preview by default.
9. Rate limits are enforced server-side per sender and conversation. Client-side throttling is only a UX aid.
10. All new tables have RLS enabled, least-privilege grants, explicit indexes and automated positive/negative tests before migration.

## Proposed data model

### `conversations`
- `id uuid primary key`
- `kind text check in ('direct','team','announcement','support')`
- `created_by uuid references profiles(id)`
- `team_id uuid null` (the season-team identifier, FK to `season_teams(id)`, only for team conversations)
- `location_id uuid null` (only for scoped announcements; FK to the verified location table)
- `status text check in ('open','closed','archived')`
- `created_at`, `updated_at`, `last_message_at`
- Check constraints ensure team conversations have a team reference and other kinds cannot misuse it. Announcement/support scope must be explicit.

### `conversation_participants`
- `conversation_id uuid references conversations(id) on delete cascade`
- `user_id uuid references profiles(id)`
- `participant_role text check in ('member','requester','support_agent','moderator')`
- `joined_at timestamptz`, `left_at timestamptz null`
- `last_read_at timestamptz null`, `muted_at timestamptz null`
- Composite primary key `(conversation_id,user_id)`; indexes on user/conversation and active participant lookups.
- No client insert/update of privileged roles. Membership lifecycle changes go through guarded server-side functions.

### `messages`
- `id uuid primary key`
- `conversation_id uuid references conversations(id)`
- `sender_id uuid references profiles(id)`
- `body text` with trimmed length constraint (e.g. 1–4000 characters)
- `created_at timestamptz`, `edited_at timestamptz null`, `deleted_at timestamptz null`
- Optional `client_nonce uuid` unique per sender for safe retry/idempotency.
- Index `(conversation_id,created_at desc,id desc)`; sender index for abuse/rate-limit review.
- No attachment column until a separate private-storage threat model and malware/size controls are approved.

### `user_blocks`
- `blocker_id uuid`, `blocked_id uuid`, `created_at timestamptz`
- Composite key; reject self-block; only blocker can create/remove their block.
- Lookup index in both directions.

### `message_reports`
- `id uuid primary key`, `message_id uuid`, `reporter_id uuid`
- `reason_code` constrained to an allow-list, optional bounded context, `created_at`, `review_status`, `reviewed_by`, `reviewed_at`
- Reporter may create/read their own report; only authorised moderation role can review. Do not reveal reporter identity to the reported user.

### Announcement delivery
Use the existing `notification_events` outbox for a generic “new announcement” alert, but never include message body text in payload. Store the announcement as a conversation/message and add recipients server-side in a single controlled operation. Avoid a duplicate notification table.

## Access-control design

- `conversations SELECT`: caller is an active participant; support staff can access only support conversations assigned to them or within their explicit support scope; announcement visibility is via participant snapshot.
- `conversation_participants SELECT`: caller is an active participant in that conversation. A narrowly scoped RPC may expose only display-safe participant details.
- `messages SELECT`: caller is an active participant and conversation access remains valid. For team conversations, re-check active team membership, not only stale participant rows.
- `messages INSERT`: sender equals `auth.uid()`, active participant exists, conversation open, body valid, block check passes, and server-side rate limit passes. Prefer a `send_message` RPC to serialize rate-limit checks and message insert.
- `messages UPDATE/DELETE`: no direct client mutation. Use an author-only edit/delete RPC with a short edit window and audit metadata; moderation removal uses a separate privileged function.
- `conversation_participants INSERT/UPDATE/DELETE`: deny direct client writes. Guarded RPCs handle direct-conversation creation, team lifecycle synchronisation, support assignment and announcements.
- `user_blocks`: owner-only CRUD.
- `message_reports`: owner insert/read; moderation-only review.
- Revoke broad `anon` and `authenticated` grants where not needed; RLS is not a substitute for least-privilege grants.

## Required RPCs / server functions

1. `create_direct_conversation(target_user_id)`: authenticated caller; validates both users exist, are eligible to message, neither blocks the other; serialises duplicate direct-thread creation; inserts exactly two participants.
2. `send_message(conversation_id,body,client_nonce)`: validates sender and participant state, block rules and rate limits; inserts atomically; updates last-message metadata; creates recipient in-app notification without body preview.
3. `mark_conversation_read(conversation_id,last_seen_message_id)`: participant-only, monotonic read marker; cannot mark another conversation.
4. `create_team_conversation(season_team_id)`: captain or authorised league admin only; snapshots currently active members; membership lifecycle trigger/function synchronises access.
5. `create_announcement(scope,subject,body)`: global admin or location-assigned league admin with exact location match; server derives eligible recipient set; writes announcement and outbox records transactionally.
6. Support create/assign/close functions: requester can create and read own case; staff assignment is explicit; staff role/scope checked server-side.
7. Report/block functions: validate targets and prevent self-report/self-block; audit moderation decisions.

## Abuse, retention and operational requirements

- Initial configurable limits should be conservative (e.g. per-user send burst and daily caps), stored server-side and tested under concurrent requests. Final values require product sign-off after load testing.
- Add spam detection signals without reading message content in analytics.
- Support reporting, blocking and moderation audit before enabling unrestricted direct messages.
- Define retention and deletion behaviour for messages, reports, closed support cases and deleted accounts before launch. Preserve legally/operationally required moderation evidence with restricted access.
- Realtime publication includes only tables needed by the client; RLS is tested for Realtime separately. Never expose message rows through a public broadcast channel.
- Push payload contains a generic event and deep link only; preview text disabled by default.
- Delivery failure must not roll back the persisted message. Reuse existing notification outbox retry/deduplication.

## Acceptance test matrix

Run against a disposable Supabase-compatible database with real JWT role claims, not production:

| Actor / case | Expected |
|---|---|
| Anonymous reads any conversation/message | Denied |
| User A reads own active direct thread | Allowed |
| User B reads unrelated direct thread | Denied |
| User A forges sender_id = User B | Denied |
| Non-participant inserts message | Denied |
| Participant sends after conversation closed | Denied |
| Blocked pair sends new direct message | Denied in both directions |
| Team member reads team thread | Allowed while active |
| Removed/suspended team member reads/sends | Denied |
| Unrelated team member reads thread | Denied |
| Captain creates team thread for own active team | Allowed |
| Captain creates thread for another team | Denied |
| Location admin announces within assigned location | Allowed |
| Location admin announces to another location | Denied |
| League admin creates global announcement | Denied |
| Global admin creates global announcement | Allowed |
| Support agent reads unassigned unrelated support case | Denied |
| Assigned support agent reads assigned case | Allowed |
| Reporter reads own report | Allowed |
| Reported user reads reporter identity/report | Denied |
| Duplicate send retry with same nonce | One message only |
| Concurrent rate-limit burst | Server limit enforced |
| Realtime subscription by unrelated user | No private rows delivered |

## Implementation gate

The live project does not currently contain conversation/message tables. A Supabase database branch was unavailable under the current plan; no production migrations may be used as a test substitute. Do not apply this design until:
- disposable database is available;
- exact location and support-role schema has been confirmed;
- SQL migrations and tests replay cleanly from baseline;
- all positive and negative role tests pass;
- performance and RLS advisor review is complete.

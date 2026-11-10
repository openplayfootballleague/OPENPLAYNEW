# Open Play secure messaging

## Product scope

The messaging workspace is separate from the notification feed. It supports:

- Private direct conversations between active members of the same active team.
- One team group per active season-team, with membership changes synchronised automatically.
- Captain-only team announcements inside the team group.
- Private support conversations between a member and the administrator team.
- Read-only administrator broadcasts targeted at everyone, registered players, captains, admins, a location, a season, a team or one individual.
- Message reporting, administrator moderation, member blocking and unblocking.
- Read/unread counts, chronological message history and Supabase Realtime updates.

There is no unrestricted member directory or open DM capability. Recipient search returns only active teammates and never returns email addresses or phone numbers.

## Access and security

- Conversation, participant and message tables have RLS enabled.
- Authenticated clients have read-only table grants; all writes go through security-definer RPCs with a fixed search path.
- Direct messages require a shared active team and are denied if either participant has blocked the other.
- Team conversations enrol active team members. Leaving a team immediately removes access; a later active membership can restore access.
- Support threads are private to their opener and the administrator participants.
- Broadcast audiences are validated server-side. Location administrators are restricted to assigned locations; platform-wide audiences require a global administrator.
- Admin report review is location-scoped. Hiding a message and resolving a report requires an audit reason and is written to the audit log.
- Message bodies are plain text, limited to 2,000 characters. Senders are limited to 10 messages per minute and 100 per day; support threads are limited to five new requests per day; broadcasts are limited to ten per hour.
- Realtime publication includes messages and participant changes, with read access still enforced by RLS.

## Notifications

Every new message creates an in-app notification for the other active participants. New reports create a separate in-app alert for global administrators and administrators assigned to the conversation location. Email/SMS alerts are queued only where the member's existing notification preferences allow them. The email/SMS alert contains no message body; the member must sign in to read the private conversation. Delivery is not required for the message transaction to succeed.

## Retention and privacy

Sender identity references use `ON DELETE SET NULL`; when an auth account is deleted, its messages display as “Former member” rather than retaining a name snapshot. Message content is not automatically purged by this feature. No separate message-content retention duration has yet been approved. Do not deploy a timed message purge until that policy is explicitly agreed. Attachments are not supported in this initial release.

## Release gates

1. Review the generated migration artifact and regression suite from CI.
2. Review the new RPCs, RLS policies and admin target scoping.
3. Confirm the desired message-content retention duration before any automatic purge is introduced.
4. Configure and test the existing notification provider secrets before enabling email/SMS dispatch.
5. Deploy the migration and updated notification function only after the feature PR is approved and merged.
6. Run iOS Safari/iPad acceptance in addition to the automated Chromium responsive/PWA suite.

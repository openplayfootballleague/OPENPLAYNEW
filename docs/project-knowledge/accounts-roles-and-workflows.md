# Open Play — Accounts, Roles and Workflows

## Principles
Authentication proves identity, not permission. Every privileged action is enforced server-side. UI visibility is not a security boundary. Roles are explicit, scoped, auditable and revocable.

## Roles
Viewer, registered player, team captain, referee, location/competition-scoped administrator, global administrator and finance-authorised administrator. Do not conflate these roles. Location admins are restricted to assigned scopes; finance is separate. Global-admin bootstrap requires owner approval.

## Account lifecycle
Visitor → authenticated account/email verification where configured → mandatory player registration including DOB → join-team request or team application → authorised approval → active membership. Account creation alone creates no player record or business role.

## Player profile
DOB is mandatory at registration. Personal data is private by default. Standard profile editing allows profile-picture changes only. Other fields remain read-only absent a separately approved correction workflow. Public pages must not expose DOB, private contact details or private membership data.

## Team and captain
Team applications capture captain details and fee acceptance. Approval is separate. The registering player becomes captain only after the application is approved and the role assigned by the authorised workflow. Captains manage their own team and approve/decline join requests. Membership approval must be safe against captain handover and admin permission revocation races. Prevent conflicting active team memberships within a season unless explicitly allowed.

## Team sheets
Only authorised captains (or explicitly authorised delegates) submit for their team/fixture.
- 6-a-side: 6 starters including goalkeeper, up to 3 substitutes.
- 7-a-side: 7 starters including goalkeeper, up to 4 substitutes.
Validate fixture ownership, eligibility, active membership, duplicates, starter/sub limits and goalkeeper requirement server-side.
Preserve historical team-sheet selections after membership becomes inactive. Historical identity remains visible, but former/inactive players cannot be selected for current amendments. Audit amendments.

## Referees
Referees access assigned fixtures only. Match reports validate fixture, event, match state and actor permissions. Payment state is only successful after provider confirmation and server persistence.

## Inbox and notifications
Two distinct areas:
- **Notifications:** automated league alerts, official announcements, matchday, membership and payment updates.
- **Messages:** player-to-player communication, including captains, with approved privacy/safety controls.
Admins use official automated notifications rather than unrestricted DMs. Do not enable unrestricted messaging by default. Preferences and opt-outs must be checked immediately before delivery. Essential account/security events retain protected handling; push lock-screen content is generic.

## Support
Support cases/conversations are private, scoped and auditable. Assignment, status, resolution and reopening are server-validated. Require change reasons and resolution summary where specified.

## Acceptance
Test role/scope positive and negative paths, validation, duplicate/race cases, persistence, audit, privacy, accessible/responsive UI and all relevant error states.

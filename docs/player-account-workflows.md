# Player Account and Registration Workflow

Status: Confirmed product requirements — 7 November 2026

This document defines the account, player-registration and team-membership lifecycle for Open Play. Account creation, player registration and team membership are separate states.

## 1. Public access

Visitors may browse the public Home, Match Centre, Teams and Join Open Play areas without signing in.

Join Open Play offers two distinct routes:
- Join an existing team.
- Register a new team.

A user must create an account before proceeding with either route. Creating an account does not, by itself, create a registered player or grant captain permissions.

## 2. Account creation

- Users create an account using email and password.
- Email verification, validation, duplicate-account handling and password recovery are required.
- Once the account is created, the user can sign in.
- The account record and player record must remain separate.

## 3. Player registration

Player registration requires these four fields, all mandatory:
1. Full name
2. Phone number
3. Email address
4. Date of birth

Date of birth is collected as a required player detail, but it is **not** a fourth matching metric. The duplicate/review threshold remains based only on full name, phone number and email address.

On submission, the system compares the submitted details against existing player records. It evaluates three independent matching metrics:
- Full name matches an existing player.
- Phone number matches an existing player.
- Email address matches an existing player.

### Matching threshold

- Zero matching metrics: registration is automatically approved.
- Exactly one matching metric: registration is automatically approved.
- Two matching metrics: registration is held for admin approval.
- Three matching metrics: registration is held for admin approval.

The threshold is strictly **two or more matching metrics out of three**. There is no separate one-match exception, including when the matching existing player is marked as banned.

A match is a review signal, not proof that two records belong to the same person. The system must not automatically ban or reject a user based on matching details.

### Matching implementation safeguards

- Normalize values consistently before comparison (for example, trim whitespace, compare email case-insensitively, and normalize phone numbers to a consistent format).
- Count each field at most once. Multiple matching records for the same field must not inflate the metric count.
- Evaluate the three fields independently and retain a clear, auditable reason for the review flag.
- Avoid exposing another player's personal details to the applicant.
- Apply the same threshold consistently on the trusted server side; do not rely on client-side checks.
- Protect against concurrent submissions creating duplicate player records. Enforce suitable database constraints and use a transaction or server-side operation for registration and matching.

## 4. Age tiers and guardian consent

Age eligibility is separate from the three-metric identity-review process above. Date of birth must be evaluated on the trusted server using the current date; a client-side age check is only explanatory UI.

- Under 16: may use the public/basic app experience to view published fixtures, results, tables and other public information. They cannot register as a player, join or register a team, hold captaincy, or use player-only functions.
- Ages 16–17: may register as a player only after verified parent or legal-guardian consent and a separate global administrator approval.
- Age 18 and over: may register independently without guardian consent.

For ages 16–17:
1. Collect the parent/legal guardian's full name and email address. The guardian email must be different from the player's account email.
2. Send a one-use, time-limited verification link to the guardian. Opening the link must not itself confirm consent; the guardian must explicitly submit the confirmation action.
3. Record the request, guardian verification timestamp, administrator decision, reviewer, review timestamp and reason in the consent record and audit trail.
4. A verified guardian response enters a separate administrator review queue. Verification alone does not permit player registration.
5. Only after the administrator approves may the player submit their permanent player registration. The age/consent gate must be enforced by the database, not only by the UI.
6. The guardian receives a separate withdrawal link. A withdrawal while the player is still 16 or 17 suspends player registration, ends active/pending team memberships, removes captaincy, preserves historical records and alerts global administrators where a captain replacement is required.
7. A rejected or withdrawn request may be resubmitted with a fresh verification link and a new administrator decision. An expired or used verification link must not be reusable.

Guardian consent approval must not alter or bypass the independent identity-matching threshold of two or more matches out of the three fields: full name, phone and email. A consented player may still be held for identity review.

## 5. Pending admin review

When two or more metrics match:
- Create the account normally.
- Set player registration to pending_review.
- Allow the user to sign in.
- Allow the user to view and edit their own account/personal details.
- Do not allow the user to join an existing team or register with a team until an authorised admin clears the review.
- Show a clear status message explaining that registration is awaiting review.
- Do not grant registered-player privileges while the review is pending.

An authorised admin must be able to review the flagged registration and approve or reject it. Record the decision, reviewer, timestamp and any reason in the audit trail. On approval, activate the player's registration and permit the normal team-joining/team-registration workflows. On rejection, keep the account and registration states distinct and show an appropriate outcome without exposing confidential ban or other-player information.

## 6. Automatically approved registration

When fewer than two metrics match:
- Create or link the player's permanent player identity.
- Set player registration to approved/active immediately.
- No admin approval is required.
- The player may continue to the team workflow.

A player may be registered with Open Play without belonging to a team.

## 7. Joining an existing team

- A registered player can submit a request to join an existing team.
- The team captain (or another explicitly authorised role) must approve or reject the request.
- Membership is not active while the request is pending.
- A player whose registration is pending_review or rejected must not be able to submit or activate a team-joining request.
- Captain decisions must be recorded in the audit trail.
- Do not grant captain permissions merely because a user created an account or submitted a team registration.

## 8. League-exclusive club membership and transfers

A player may represent **only one club in the same league at a time**. This restriction is league-specific: it does not, by itself, prevent a player joining a club in a different league.

- A player may represent only one club in a league at a time, across all seasons of that league. Membership in a different league is independent.
- To move clubs, the player must leave their current club themselves. The old captain or an administrator does not approve an ordinary voluntary departure. A captain must appoint a replacement before leaving.
- Leaving ends the active membership but preserves the historical membership record and all appearances, statistics, disciplinary history and other competition records. A player listed on a submitted upcoming team sheet must have that sheet amended by an administrator before leaving.
- Only after the old membership has ended may the player submit a transfer request to a different club in that league. A player with a recorded voluntary departure cannot bypass transfer approval by using the first-time team-join request path; that path remains available for first-time league entrants and a return to the same club. A pending transfer request leaves the player unattached and ineligible to represent either club.
- The destination club's active captain approves or rejects the request. Administrators are not ordinary decision-makers; they retain oversight and an audited exceptional-intervention route.
- Outside the emergency window, a player may have only one pending transfer request in a league. The player must cancel or resolve it before requesting another destination.
- In the final 24 hours before a destination club's scheduled kickoff, an unattached player may request multiple clubs in that league, but only clubs with an upcoming fixture in that window whose team sheet has not been submitted are eligible. A saved draft does not count as submitted; the sheet becomes ineligible only when the captain confirms submission and it is locked.
- If a destination captain submits their team sheet after receiving an emergency request, that request is automatically cancelled. The first destination captain to approve a still-valid emergency request secures the player. The approval transaction cancels every other pending transfer request for that player in the league. Competing approvals are serialised in the database; a later captain cannot also activate the player.
- On rejection, the player remains unattached and other emergency requests remain pending. The database validates the emergency fixture window and team-sheet status again when the captain decides.
- The database must enforce league-wide active membership and pending-transfer rules transactionally, including concurrent requests, direct API/RPC calls and memberships across different seasons. Client-side checks alone are insufficient.
- A transfer must never move or rewrite historical team-sheet, appearance, goal, result, disciplinary or finance records. Historical records remain associated with the club and competition identity under which they were created.
- Captains may edit and save team-sheet drafts before kickoff. They must explicitly confirm before submission; submission locks the sheet. A draft remains editable and does not exclude that club from emergency transfer eligibility.

## 8. Registering a new team

- Account creation is required before starting the team-registration journey.
- A player held for admin review cannot register with or join a team until cleared.
- Team registration and appointment of its captain must use an authorised, auditable workflow.
- The exact approval rules for new team applications should be specified separately; do not infer that ordinary player registration approval applies to team applications.

## 9. Identity and season rules

- A person has one permanent player identity across seasons.
- A new season must not create a duplicate player identity for a returning person.
- Account, player registration, season registration and team membership are distinct records/states.
- A player may have an account without being registered, and may be registered without belonging to a team.
- Leaving or transferring teams must preserve historical memberships and records.
- Squad numbers are optional.

### Season statistics across club transfers

- A player's season statistics belong to their permanent competition identity, not to their current club membership.
- If a player represents Club A and later transfers to Club B during the same season, all verified appearances, starts, substitute appearances, goals and goalkeeper statistics accumulate into one season leaderboard record.
- A transfer must never reset a player's goal tally or reduce their leaderboard position by splitting one person into separate player entries.
- Club-specific history remains separately attributed to the club represented in each fixture. The player record therefore has both a combined season total and a per-club breakdown.
- The appearance display remains starts(substitute appearances), for example 8(9); starts and substitute appearances are stored separately.

## 10. Minimum acceptance scenarios

1. New account, no matching fields: player registration is automatically approved.
2. New account, name only matches: automatically approved.
3. New account, phone only matches: automatically approved.
4. New account, email only matches: automatically approved.
5. Any two fields match: registration is held for admin review.
6. All three fields match: registration is held for admin review.
7. Two fields match a banned player's record: held for admin review; no automatic ban or rejection.
8. One field matches a banned player's record: automatically approved under the confirmed 2+ threshold.
9. Pending-review user can sign in and edit their own details.
10. Pending-review user cannot join an existing team or register with a team.
11. Admin approves a pending review: player becomes registered and can proceed to team workflows.
12. Admin rejects a pending review: player cannot proceed to team workflows.
13. Registered player with no team can use their player account without being assigned to a team.
14. A captain rejects a team-joining request: no active membership is created.
15. Returning player in a later season retains the same permanent player identity.
16. Date of birth is required and validated, but does not affect the three-metric matching count.
17. Duplicate or simultaneous registration submissions cannot create duplicate player identities.
18. A player with an active membership at Club A cannot join or represent Club B in the same league.
19. A player can leave Club A without old-captain or administrator approval, and must do so before submitting a transfer request to Club B in that league.
20. A pending transfer request does not grant playing eligibility or active membership.
21. The destination club's captain, not an administrator, approves or rejects the transfer request. Approval activates the new membership; rejection leaves the player unattached.
22. Outside the final 24-hour emergency window, a player cannot have more than one pending transfer request in a league.
23. During the final 24 hours before match kickoff, an unattached player can request every eligible club whose upcoming matchday sheet is not submitted.
24. A saved team-sheet draft does not exclude a club; explicit captain confirmation submits and locks the sheet.
25. The first captain to approve an emergency transfer secures the player and all competing pending requests are automatically cancelled.
26. A later or concurrent captain approval cannot also activate the same player.
27. The same player may hold memberships in different leagues, subject to each league's own rules.
28. The database rejects concurrent attempts to create active memberships at two clubs in the same league, including across seasons.

## 11. Security and privacy requirements

- Matching and approval decisions must be enforced server-side.
- Users may read and update only their own permitted account fields.
- Applicants must not be able to enumerate player records or discover another player's phone, email, ban status or private details.
- Only authorised admins may view and resolve registration-review cases.
- All approval/rejection actions must be auditable.
- Never trust a client-supplied registration status, banned flag, role or approval decision.

## 12. Inactive player accounts and reactivation

Account retention is separate from player registration and team membership.

- The inactivity clock is based on the last successful sign-in. A successful sign-in resets the clock.
- A registered player is exempt from automatic closure while they have any active or pending team membership, even if they have not signed in recently.
- A registered player with no active or pending team membership and no successful sign-in for 12 consecutive months is eligible for account closure.
- Account closure applies a long Auth ban, blocking new sign-ins and token refresh. Already-issued access tokens may remain valid until their normal expiry; the app checks the closed-account state and signs the user out when that state is observed. It does not delete the player's historical identity, results, appearances or competition records.
- Closure starts a restricted 12-month archive period. The player cannot sign in during this period.
- During the archive period, the player may request reactivation using a verified email link sent to the account's existing email address. The request must be single-use, time-limited and rate-limited.
- Successful reactivation restores the existing registered player account and profile, but does not restore any club/team membership, pending membership request, captaincy or team permissions. The player returns as a registered player without a club and must use the normal team-joining workflow.
- Reactivation clears the closure/archive state and starts a fresh 12-month inactivity period from the reactivation/sign-in date.
- If the player does not reactivate before the archive expires, their identifiable data becomes due for erasure or genuine anonymisation, subject to documented legal retention exceptions, safeguarding holds and financial-record obligations.
- Historical competition records must remain usable through the account-independent `competition_player_identities` table. Team-sheet appearances and goal records reference that identity, not the live Auth/profile UUID.
- After the 12-month archive, the retention worker removes the profile avatar, scrubs profile/player contact and DOB data, detaches operational/audit references, relabels the permanent competition identity as "Former player", and deletes the Auth user. Historic fixtures, results, appearances, goals and league statistics remain.
- The database membership guard serialises active/pending membership creation against closure and rejects new memberships for closed or erasure-due accounts.
- Standard admin team-sheet amendments are blocked if a sheet contains a former/unattached player whose live membership cannot be safely resolved. Result correction and season statistics continue to use the permanent competition identity.
- Payment/accounting records remain on their separate documented retention schedule; the direct player and Stripe customer links are removed where possible, while payment references needed for statutory records, refunds or disputes may remain.
- Active or pending team membership, a safeguarding/legal hold, a current global/location-admin assignment, or an unresolved financial/legal obligation must prevent automatic erasure until reviewed.


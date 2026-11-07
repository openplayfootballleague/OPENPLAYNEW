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

Player registration requires these three fields, all mandatory:
1. Full name
2. Phone number
3. Email address

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

## 4. Pending admin review

When two or more metrics match:
- Create the account normally.
- Set player registration to pending_review.
- Allow the user to sign in.
- Allow the user to view and edit their own account/personal details.
- Do not allow the user to join an existing team or register with a team until an authorised admin clears the review.
- Show a clear status message explaining that registration is awaiting review.
- Do not grant registered-player privileges while the review is pending.

An authorised admin must be able to review the flagged registration and approve or reject it. Record the decision, reviewer, timestamp and any reason in the audit trail. On approval, activate the player's registration and permit the normal team-joining/team-registration workflows. On rejection, keep the account and registration states distinct and show an appropriate outcome without exposing confidential ban or other-player information.

## 5. Automatically approved registration

When fewer than two metrics match:
- Create or link the player's permanent player identity.
- Set player registration to approved/active immediately.
- No admin approval is required.
- The player may continue to the team workflow.

A player may be registered with Open Play without belonging to a team.

## 6. Joining an existing team

- A registered player can submit a request to join an existing team.
- The team captain (or another explicitly authorised role) must approve or reject the request.
- Membership is not active while the request is pending.
- A player whose registration is pending_review or rejected must not be able to submit or activate a team-joining request.
- Captain decisions must be recorded in the audit trail.
- Do not grant captain permissions merely because a user created an account or submitted a team registration.

## 7. Registering a new team

- Account creation is required before starting the team-registration journey.
- A player held for admin review cannot register with or join a team until cleared.
- Team registration and appointment of its captain must use an authorised, auditable workflow.
- The exact approval rules for new team applications should be specified separately; do not infer that ordinary player registration approval applies to team applications.

## 8. Identity and season rules

- A person has one permanent player identity across seasons.
- A new season must not create a duplicate player identity for a returning person.
- Account, player registration, season registration and team membership are distinct records/states.
- A player may have an account without being registered, and may be registered without belonging to a team.
- Leaving or transferring teams must preserve historical memberships and records.
- Squad numbers are optional.

## 9. Minimum acceptance scenarios

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
16. Duplicate or simultaneous registration submissions cannot create duplicate player identities.

## 10. Security and privacy requirements

- Matching and approval decisions must be enforced server-side.
- Users may read and update only their own permitted account fields.
- Applicants must not be able to enumerate player records or discover another player's phone, email, ban status or private details.
- Only authorised admins may view and resolve registration-review cases.
- All approval/rejection actions must be auditable.
- Never trust a client-supplied registration status, banned flag, role or approval decision.

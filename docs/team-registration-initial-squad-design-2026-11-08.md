# Open Play New — Team registration with initial squad

**Status:** implementation design; schema work gated on migration-source reconciliation  
**Date:** 8 November 2026  
**Related issue:** #16

## 1. Current verified behaviour

The current public `/join` team-registration form collects the team name, optional colours, optional Instagram handle and optional Instagram profile URL. It calls the existing `register_team` RPC.

The live deployed `register_team(uuid,text,text,text)` function:
- requires an authenticated user with an approved, eligible, non-banned player profile;
- requires a public, published league and a season with registration open;
- creates the canonical team and a season-specific team record in pending status;
- creates a pending membership row for the registering player, without activating captain privileges;
- writes a team-registration audit event.

The current competition rules helper defines:
- six-a-side: 6 starters and up to 3 substitutes;
- seven-a-side: 7 starters and up to 4 substitutes;
- exactly one goalkeeper, selected from the starters;
- no duplicate player identities on a team sheet.

The team registration form does not currently capture the initial squad. The existing team-sheet rules can inform squad validation, but team registration must not silently convert a submitted list into active memberships.

## 2. Product flow

1. An authenticated, approved and eligible player selects a public season accepting registrations.
2. The applicant selects the competition format inherited from the selected season. The format must not be supplied or overridden by the browser.
3. The applicant enters the team name and existing optional team details.
4. The applicant identifies the proposed captain (the registering player by default) and submits the initial squad:
   - exact starter count for the season format;
   - no more than the allowed substitute count;
   - exactly one goalkeeper among starters;
   - unique player identities;
   - optional squad numbers within the existing 1–99 rule.
5. Each squad member is linked to an existing player identity or offered a secure invitation/player-registration journey. The application must not create duplicate Auth accounts, infer an identity from a display name, or reveal whether an email address already has an account.
6. The team and its proposed squad are submitted atomically as one pending application.
7. An administrator reviews the team application and the proposed squad together.
8. Team approval, player registration approval, player invitation acceptance and team membership activation remain separate state transitions. No player is silently approved or made active by team submission.
9. The team becomes operational only after the required team, captain and roster approvals are satisfied. The exact readiness rule for partially accepted substitute slots must be confirmed in the product acceptance decision.

## 3. Proposed data model

Do not add schema until the migration-source reconciliation release gate is cleared.

Recommended child table: `team_registration_squad_members`.

Fields:
- `id uuid primary key`;
- `season_team_id uuid not null references season_teams(id)`;
- `player_user_id uuid null references auth.users(id)` for a known existing player;
- `invite_email text null` for an invited person without a linked account (restricted, never public);
- `squad_role text check in ('starter','substitute')`;
- `is_goalkeeper boolean not null default false`;
- `squad_number smallint null`;
- `status text check in ('invited','accepted','declined','approved','rejected')`;
- `invited_by uuid not null references auth.users(id)`;
- `responded_at timestamptz null`, `reviewed_by uuid null`, `reviewed_at timestamptz null`;
- created/updated timestamps and a client nonce/idempotency key where appropriate.

Constraints/indexes:
- exactly one of `player_user_id` and `invite_email` is populated;
- no duplicate player identity per application;
- unique active squad numbers within the application when supplied;
- indexes for application, invitee, status and review queues;
- enforce starter/substitute counts and exactly one starting goalkeeper in the server transaction (cross-row rules need a deferred trigger or guarded RPC, not a simple row CHECK).

A separate invite-token table may be required if the existing notification/email infrastructure cannot provide one-time, hashed, expiring, revocable invitation tokens without storing raw tokens.

## 4. Required server operations

### `register_team_with_initial_squad(...)`

One transaction must:
- authenticate caller and confirm approved/eligible player status;
- load the season and competition format from the database;
- verify the season is public, published and registration-open;
- validate the team name and existing optional social fields;
- validate starter/substitute counts, goalkeeper, duplicate IDs and squad numbers;
- verify every linked existing player is registered and not banned;
- prevent a player from being active in another team in the same season, using the existing advisory-lock strategy;
- create the team and season-team record in pending status;
- create only pending proposed-squad/invitation records;
- preserve the existing creator membership semantics;
- write a single audit event with safe metadata (never raw invite email or invite token);
- roll back the entire application on any failure.

The existing `register_team` overload must remain compatible until every current caller has migrated and regression-tested.

### Invite response and approval

- A player must authenticate and accept an invitation bound to their verified account; invite tokens are single-use, expiring and stored hashed.
- A player who has no account is sent through the existing sign-up/player-registration process. Do not auto-create an Auth account.
- Acceptance does not bypass player registration approval or team membership rules.
- Admin approval of the team does not silently approve the individual player profile.
- A declined or expired invitation does not create an active membership.
- The final membership activation is a guarded server-side transition with audit history.

## 5. Admin review

The team application review should show:
- team details and selected season/format;
- proposed captain and captain eligibility status;
- starters, substitutes, goalkeeper and squad numbers;
- per-player identity/registration/invitation/acceptance/approval status;
- validation errors and any duplicate/season-conflict blockers.

Admins must be able to approve or reject the team application with a bounded reason. They must not be able to bypass player registration eligibility, identity checks or membership consent. Location-admin scope must be enforced in the database, not only hidden in the UI.

## 6. Security and privacy invariants

- Browser input is untrusted; all counts, season format, identity eligibility and authorisation are validated server-side.
- No arbitrary user can be inserted as a member by supplying a UUID.
- No direct client write access to privileged squad-submission/invitation records.
- Invitation emails and tokens are private, rate-limited and never returned by public team-directory RPCs.
- Avoid account enumeration: responses must not disclose whether an invite email maps to an existing account.
- No player or team is active after partial failure.
- Every approval, rejection, invitation, acceptance, expiry and activation is auditable.
- No message bodies, invite emails or tokens are sent to PostHog or notification previews.
- Preserve existing one-active-team-per-season and transfer workflow invariants.

## 7. Acceptance tests

Run on a disposable Supabase-compatible database after migration reconciliation.

- valid six-a-side application: exactly 6 starters, 0–3 substitutes, one starting goalkeeper;
- valid seven-a-side application: exactly 7 starters, 0–4 substitutes, one starting goalkeeper;
- too few/many starters or too many substitutes rejected;
- zero or multiple goalkeepers rejected; goalkeeper substitute rejected;
- duplicate player identities and duplicate squad numbers rejected;
- unregistered, banned, missing or cross-season-ineligible players rejected;
- captain must be eligible and must be included as proposed captain;
- season format is loaded server-side and cannot be forged;
- invalid/closed/unpublished season rejected;
- duplicate submission nonce does not create duplicate teams or invitations;
- concurrent submissions cannot place a player on two active teams in the same season;
- invitee can accept only their own invitation; unrelated users cannot accept or read it;
- declined, expired or revoked invite cannot create membership;
- team approval does not auto-approve player profiles or activate unaccepted members;
- location admin cannot review another location; global admin can;
- failure at any step rolls back the team and all proposed squad records;
- public team directory reveals no invite email, token, private player status or pending application data.

## 8. Gated implementation sequence

1. Complete authoritative migration-source/version reconciliation and clean replay.
2. Confirm the readiness rule for substitute slots and whether invited players must already have accounts.
3. Implement the child-table schema and RLS/grants.
4. Implement the atomic team-plus-squad RPC and invitation lifecycle.
5. Extend the public registration form and admin review UI.
6. Add SQL and browser regression tests for both formats and role isolation.
7. Only after isolated replay and acceptance: prepare production migration and deployment plan.

No schema, data or production setting was changed while preparing this design.

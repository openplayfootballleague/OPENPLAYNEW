# Open Play — Player, Club and Matchday Workflow

**Status:** Owner-confirmed product workflow; acceptance specification for implementation.
**Authority:** User confirmation on 8 November 2026. This document supersedes any initial-squad interpretation.

## Non-negotiable product rule

There is no initial squad submission form. Club registration creates a club application, not a roster. The only recurring lineup submission is the fixture-specific weekly match sheet.

## Phase 1 — Individual player registration

1. A person creates an Open Play account and verifies their email.
2. They complete their own player registration form: full name, mobile number and date of birth; the account email is taken from the verified signed-in account.
3. The server creates the player record and determines whether it can be registered immediately or requires identity review.
4. Only a registered, eligible, non-banned player may proceed to club requests.
5. Account creation is not player registration; player registration is not club membership.

**Acceptance checks**
- Unauthenticated users cannot submit a player registration.
- Unverified email cannot submit.
- Duplicate/identity-review cases remain pending and cannot join/create clubs until approved.
- A player cannot register twice or change the account email by submitting a different email.
- Player identity and review decisions are server-authoritative.

## Phase 2 — Choose one club action after player approval

The approved player chooses either **Join an existing club** or **Create a club**.

### Join an existing club
1. Show approved clubs in the selected, open season/location only.
2. Player selects a club and submits a membership request.
3. Request remains pending; it does not grant membership or match-sheet eligibility.
4. Captain later accepts or rejects it (Phase 3).

### Create a club
1. Player completes the club/team registration form (club name and supported club details such as colours).
2. Server creates the club's season-specific record in pending approval status.
3. The creator is recorded as the applicant, but is not an active captain yet.
4. Open Play administrator approves or rejects the club application.
5. On approval, the creator's membership is activated and they become that club's captain automatically. On rejection, the applicant does not become captain.
6. No player roster, starters, substitutes or initial squad is collected during club creation.

**Acceptance checks**
- Only an approved, eligible player can request membership or create a club.
- Club creation is restricted to a season currently accepting registrations.
- Duplicate club names within a season are rejected safely.
- Pending/rejected clubs do not appear as joinable public clubs.
- Admin approval activates the creator as captain in the same atomic approval workflow.
- The creator cannot exercise captain powers before approval.
- No initial squad fields, roster validation, or squad submission are part of this form.

## Phase 3 — Membership decisions and weekly match sheets

### Captain membership management
1. For an approved club, registered players may request to join.
2. Only that club's active captain (or explicitly authorised Open Play administrator) may decide a pending request.
3. Accepting creates active membership; rejecting does not.
4. A player is selectable on a match sheet only while they have an active membership in that exact season club and remain registered and eligible.
5. Existing membership/transfer rules prevent a player being active in conflicting clubs in the same season.

### Weekly fixture-specific match sheet
1. The system automatically identifies the club's **next required fixture** and preselects that match sheet when the captain opens the Match Sheet area. The captain does not choose an arbitrary gameweek from a list.
2. Only that next required fixture is available for captain draft/save/submit. Previous gameweeks are historical; later gameweeks remain unavailable until they become next in sequence.
3. Example: if Gameweek 5 is the last completed gameweek and it is Thursday before the next matchday, the only available sheet is Gameweek 6. Gameweeks 1–5 cannot be resubmitted and Gameweek 7 cannot be submitted early.
4. The system advances to the next fixture/gameweek only when the prior fixture is marked completed (or cancelled, which is skipped) in the authoritative fixture lifecycle. A postponed or in-progress fixture remains the blocking next fixture until it is rescheduled and completed. Do not advance merely because the calendar date changed or because a sheet was submitted.
5. The sheet is tied to that fixture and that club, not to a general squad profile.
6. Captain selects players only from the club's active, eligible membership list.
7. For 6-a-side: exactly 6 starters and up to 3 substitutes. For 7-a-side: exactly 7 starters and up to 4 substitutes.
8. Captain confirms one goalkeeper from the selected starters.
9. Captain may save a draft, return to it, review the sheet and submit it for that fixture. Drafts are keyed to the same next-required fixture.
10. Submission locks the sheet against ordinary captain edits. Once the fixture is marked completed, the sheet is expired for captain access. An administrator may amend the locked sheet only after fixture completion, with a reason of at least five characters; the amendment is audited with before/after data and does not reopen captain editing.
11. The referee/matchday process records actual appearances and match events separately from the captain's pre-match selection.

**Acceptance checks**
- A captain can access only the single next-required fixture for their own active club in the selected active season.
- The next fixture is preselected automatically; there is no free choice of an earlier or later gameweek.
- The next fixture is derived from authoritative fixture/gameweek completion state, not simply the current date or team-sheet submission timestamp.
- A captain cannot submit an earlier gameweek again or submit a later gameweek early.
- The selected club must be one of the fixture's two participants.
- The server independently verifies captain authority, fixture status, format, player membership, registration status, ban status, duplicate selections and goalkeeper selection.
- A pending join request, member of another club, banned player or unregistered player cannot be selected.
- The sheet is unique per fixture/club; drafts restore correctly; submitted sheets lock; privileged amendments are audited.
- A fresh sheet is required for each gameweek/fixture. A prior week's selection is never treated as a permanent roster or silently copied as an approved lineup.

## Current implementation observations (code review, not acceptance sign-off)

- `/register-player` already provides individual player registration and calls the `register_player` RPC.
- `/join` already offers JOIN A TEAM and REGISTER A TEAM after checking the player is registered and not banned.
- The club application calls `register_team`; the database creates a pending season club and pending applicant membership.
- `resolve_team_registration` is intended to activate the applicant as captain only after administrator approval.
- Membership request and captain decision RPCs already exist.
- `/captain` currently contains a fixture selector (this must be replaced with automatic next-fixture selection), active-member selection, starters/substitutes, goalkeeper confirmation, draft save/restore and submit flow.
- `get_captain_fixtures()` currently returns all scheduled fixtures for captain teams; this is not sufficient for the owner-confirmed next-gameweek-only rule. It must be replaced or wrapped by a server-authoritative next-required-fixture projection, and the draft/get/submit RPCs must independently enforce that same fixture eligibility.
- Database `submit_team_sheet` validates fixture participation and active eligible membership; the later goalkeeper-confirmation migration must be checked together with the client call before declaring parity.

These observations identify existing implementation; they do not prove end-to-end correctness. The remaining work is to reconcile the migrations, generated database types, client RPC signatures, permissions, and acceptance tests against every rule above.

## Explicitly out of scope

- No initial squad registration/submission form.
- No permanent starter/substitute designation at club level.
- No automatic membership merely because a player registered or requested to join.
- No captain privileges before club approval.
- No selection of players outside the approved club membership for a match sheet.

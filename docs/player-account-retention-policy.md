# Open Play player account retention policy

Status: Confirmed product requirement — 9 November 2026

## Purpose

Keep registered-player accounts only while they are being used or remain involved with a team, while protecting historic league records and providing a fair route back for returning players.

This policy is an application lifecycle rule. It does not replace the separate retention schedules for payment, accounting, safeguarding, dispute or legal records.

## Qualifying inactivity

A player becomes eligible for closure only when both conditions are true:

1. No successful sign-in has occurred for 12 consecutive months.
2. The player has no active or pending team membership.

The clock is based on the last successful sign-in, falling back to account creation time for an account that has never signed in. Every successful sign-in resets the clock. Active or pending team membership protects the account from automatic closure even if the player has not signed in.

Administrator, finance and other privileged accounts are not processed by the player-retention job.

## Stage 1 — active account

- Account authentication and player access remain available.
- Successful sign-in resets the inactivity clock.
- Existing historical competition records remain linked to the registered player identity.

## Stage 2 — closure after 12 months

When the qualifying inactivity conditions are met:

- Mark the account closed.
- Disable sign-in using the Supabase Auth administrative ban mechanism.
- Revoke existing refreshable sessions.
- Notify the player at the verified email address before closure where the notification schedule is configured.
- Preserve the player identity and historic competition data during the archive period.
- Do not change historic results, appearances, goals, fixtures or league tables.

Closure is not the same as deleting the player record.

## Stage 3 — restricted archive (months 12–24)

- The account remains closed and cannot sign in.
- Identifiable data is restricted to the retention purpose and authorised operational access.
- The player may request reactivation using a single-use, expiring email link sent to the email address already held for the account.
- Reactivation requests must not disclose whether an email address has an account. The public response is the same whether an eligible account exists or not.
- Reactivation links are stored as hashes, expire, are single-use and are rate-limited.

### Reactivation outcome

A successful reactivation:

- Reopens the same registered player account and profile.
- Removes the Auth ban and restores sign-in.
- Clears the closed/archive state and starts a new 12-month inactivity clock.
- Does not restore any club/team membership, pending membership request, captaincy, squad number or team-level permissions.
- Returns the player as registered with Open Play but unattached to a club/team.
- Requires the player to use the ordinary team-joining process and obtain the normal approval.

## Stage 4 — end of archive (after month 24)

If the player has not reactivated by the end of the archive:

- Identifiable personal data becomes due for erasure or genuine anonymisation.
- Historic competition records must be preserved in a form that cannot reasonably identify the individual.
- Data that must be retained for a legal obligation, accounting/tax requirements, safeguarding, disputes or legal claims follows its own documented retention period and access restriction.
- An erasure request made before the scheduled date is assessed separately and is not automatically delayed until month 24.

### Technical release gate

The current data model contains historical records that reference profile IDs, including goal records and submitted team-sheet appearances. Deleting an Auth user/profile directly can either be blocked by restrictive foreign keys or cascade-delete records that Open Play needs to preserve.

Therefore the final erasure/anonymisation worker must not be enabled until the historical identity model has been refactored and tested. The safe implementation must separate a person's live account/profile from the non-identifying historical competition identity. A random UUID or pseudonym alone is not sufficient to call the resulting data anonymous.

## Operational safeguards

- Exclude active/pending team memberships from automatic closure.
- Exclude privileged accounts from the player-retention worker.
- Recheck eligibility immediately before closure to avoid races with a new membership or sign-in.
- Use service-role-only database operations and server-side Auth Admin API calls; never expose service-role credentials to the client.
- Use idempotent processing and audit every closure/reactivation/erasure decision.
- Keep safeguarding/legal holds and financial record retention separate from ordinary player inactivity.
- Send advance warning notices before closure when the notification schedule is configured; the final cadence must be operationally approved before activation.

## Acceptance scenarios

1. A player who signs in before the 12-month boundary remains active and the clock resets.
2. A player with an active membership is not closed, regardless of sign-in age.
3. A player with a pending membership is not closed.
4. A player with no active/pending membership and 12 months without sign-in is closed.
5. A closed account cannot sign in and existing sessions are revoked.
6. A reactivation request for an eligible account sends a single-use email link without exposing account existence to the requester.
7. An expired, used or invalid reactivation token cannot restore access.
8. A successful reactivation restores the same registered player identity, but no team membership or captaincy.
9. Reactivation resets the inactivity clock.
10. An account past the 24-month archive boundary is queued for controlled erasure/anonymisation, not hard-deleted until the historical identity refactor is deployed.
11. Active/pending membership, privileged status or a documented legal/safeguarding hold prevents automatic erasure.
12. Historic fixtures, results, appearances, goals and league tables remain intact after the eventual anonymisation process.

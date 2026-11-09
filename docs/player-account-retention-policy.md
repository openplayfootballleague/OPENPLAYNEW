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
- Apply a long Supabase Auth ban, which blocks new sign-ins and token refresh.
- Already-issued access tokens may remain valid until their normal expiry. The app checks the account lifecycle state and signs the user out when that state is observed.
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

- The worker removes the player's profile avatar object, scrubs direct personal details from live profile/player rows and removes account-linked operational references.
- It then deletes the Supabase Auth user. If Auth deletion fails, the account remains banned and the daily worker retries; erasure is not complete until Auth deletion succeeds.
- Historic fixtures, results, team-sheet appearances and goals remain linked to a random `competition_player_id`, not the account/profile UUID.
- The retained competition identity is relabelled **Former player** and the original account-to-competition mapping is removed with the Auth/profile/player rows.
- Season statistics continue to count historical appearances/goals according to the player's genuine/registered/unbanned eligibility snapshot at erasure time.
- Payment and accounting records follow their separate retention schedule. Direct player/Auth and Stripe customer links are detached, but payment-intent/checkout references may remain where required for statutory accounting, refunds or disputes.
- An erasure request made before the scheduled date is assessed separately and is not automatically delayed until month 24.

### Historical identity separation

The schema now includes `competition_player_identities`. Each registered player receives a random, account-independent identity. Team-sheet appearances and goal records reference that identity. Their account/profile UUID fields are nullable and are cleared on erasure.

The standard admin team-sheet amendment flow refuses to rewrite sheets containing former/unattached players, while result correction and season statistics continue to use the permanent competition identity. This prevents an admin roster edit from silently deleting anonymised historical appearances.

## Operational safeguards

- Exclude active/pending team memberships from automatic closure.
- Exclude global and location administrators from the player-retention worker.
- Recheck eligibility immediately before closure/erasure. A membership guard serialises new active/pending memberships against account closure and rejects membership for closed or erasure-due accounts.
- Use service-role-only database operations and server-side Auth Admin API calls; never expose service-role credentials to the client.
- Use idempotent processing and audit every closure/reactivation/erasure decision.
- Keep safeguarding/legal holds and financial record retention separate from ordinary player inactivity.
- Global administrators can apply or clear a documented retention hold while an account is active or in its restricted archive. Each change requires a reason and is audited. A hold cannot safely be introduced after the account reaches `erasure_due`.
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
10. An account past the 24-month archive boundary is anonymised against its permanent competition identity and the Auth/profile/player account is deleted; failed Auth deletions remain banned and retry.
11. Active/pending membership, privileged status or a documented legal/safeguarding hold prevents automatic erasure.
12. Historic fixtures, results, appearances, goals and league tables remain intact after the eventual anonymisation process.

## Deployment and activation requirements

The implementation consists of the retention and competition-identity migrations, the `player-account-retention` Edge Function, the sign-in reactivation request, the app-level account guard and the scheduled GitHub Actions workflow.

Before activating the scheduled worker after release:

1. Apply the forward-only migration to the intended Supabase environment.
2. Deploy `supabase/functions/player-account-retention`.
3. Configure Supabase Edge Function secrets: `ACCOUNT_RETENTION_CRON_SECRET`, `RESEND_API_KEY` and `RESEND_FROM_EMAIL`.
4. Configure GitHub repository secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY` and the same `ACCOUNT_RETENTION_CRON_SECRET`.
5. Run the workflow manually against controlled test accounts and verify Auth ban, reactivation email, single-use confirmation, no restored memberships, avatar removal, Auth deletion and preserved anonymised match history.
6. Confirm the advance-warning email cadence and operational support process before enabling unattended closures.

The scheduled worker closes accounts, moves expired archives to `erasure_due`, anonymises the permanent competition identity and deletes the Auth user. It never hard-deletes fixtures, results, appearances or goals. Advance-warning emails before closure are not yet implemented; agree and implement that cadence before enabling unattended account closures. Payment/accounting records remain subject to their separate documented retention schedule.


# Phase 1 manual acceptance runbook

**Purpose:** Provide a repeatable, auditable manual acceptance procedure for Open Play New Phase 1.  
**Environment:** Approved isolated staging only.  
**Status:** Runbook prepared; execution and sign-off are outstanding.

## 1. Mandatory safety preconditions

Do not begin until all are true:

- [ ] An isolated staging project/environment is approved and identified. The connected `OPENPLAYNEW` project is not to be treated as a disposable test environment.
- [ ] Staging contains only disposable synthetic accounts and test competition data.
- [ ] Email delivery is routed to controlled test inboxes or a safe email sink.
- [ ] Stripe is in test mode with test credentials and no live charges.
- [ ] Resend sender identity and required secrets are configured in staging.
- [ ] A named reviewer is responsible for the test run and evidence record.
- [ ] A recovery/reset plan exists for disposable accounts and storage objects.
- [ ] No production account, real child, real payment or real player history is used.

If no isolated staging environment is available, mark the relevant tests **Blocked**. Do not substitute live users or manually dispatch the retention worker against the connected hosted project.

## 2. Test identities to prepare

Create only synthetic accounts, using clearly fake names and reserved test email domains:

| Persona | Required state | Purpose |
|---|---|---|
| V-01 | Anonymous visitor | Public navigation and public-only data |
| U16-01 | Under-16 viewer | Basic-view restrictions |
| U17-01 | Age 16–17, guardian pending | Guardian verification and admin approval |
| U17-02 | Age 16–17, guardian verified | Separate admin decision |
| P-01 | Adult registered player, no club | Standard player access and team join |
| P-02 | Adult player with active membership | Membership and retention exclusion |
| C-01 | Active team captain | Captain Hub and team-sheet workflow |
| L-01 | Location administrator | Location-scoped administration |
| G-01 | Global administrator | Global review/retention permissions |
| F-01 | Finance role | Finance-only access |
| B-01 | Banned registered player | Restricted access and unban behaviour |
| R-01 | Closed account eligible for reactivation | Retention reactivation lifecycle |

Do not reuse one identity for multiple roles unless the test explicitly checks role changes.

## 3. Manual acceptance scenarios

Record **Pass**, **Fail** or **Blocked** for each scenario. Attach redacted screenshots or screen recordings where useful; never capture passwords, bearer tokens, guardian tokens, service-role keys or real personal data.

### Registration, age and consent

| ID | Steps | Expected result |
|---|---|---|
| REG-01 | Open public Home, Match Centre, Teams and Join as V-01. | Public pages work; no private player data or private workspace access is exposed. |
| REG-02 | Sign in as U16-01 and navigate to Join, registration and direct player/captain/admin URLs. | Public basic view remains available; player registration and joining are non-actionable; direct private data access is denied. |
| REG-03 | Start U17-01 registration and attempt to proceed without guardian verification. | Registration remains pending/restricted; no player privileges are granted. |
| REG-04 | Verify guardian email for U17-01, then inspect the admin queue before an admin decision. | Guardian verification alone does not grant player access; admin decision remains separate. |
| REG-05 | Approve U17-02 after guardian verification, then sign in as the player. | Only the approved player workflow becomes available. |
| REG-06 | Withdraw guardian consent for U17-02. | Player access is suspended, pending/active memberships and captaincy are ended, and historic competition records remain. |
| REG-07 | Reuse an already-consumed or expired guardian token. | Request is rejected without changing consent or account state. |
| REG-08 | Submit adult registration with valid and invalid phone formats and duplicate identity combinations. | Phone is canonicalised; invalid formats fail safely; duplicate review follows the documented two-of-three identity threshold without revealing another player's private details. |

### Player access, bans and captaincy

| ID | Steps | Expected result |
|---|---|---|
| ACC-01 | Sign in as P-01 and inspect Player Hub, Match Centre, Teams and More navigation. | Four fixed tabs appear in the required order; More exposes secondary workspaces; no horizontal overflow at the tested viewport. |
| ACC-02 | Sign in as B-01 and open Player Hub directly. | Access is restricted and the account-status screen is shown; protected player data does not render. |
| BAN-01 | As G-01, ban a synthetic player with an active membership and an eligible captain successor. | Ban, membership changes, succession and audit record occur transactionally; successor selection follows current-season appearances then deterministic name order. |
| BAN-02 | Repeat with no eligible successor. | No arbitrary successor is assigned; administrators receive the required alert/audit record. |
| BAN-03 | Unban the player. | Auth access may resume, but ended memberships, pending requests and captaincy are not silently restored. |
| CAP-01 | As C-01, open Matchday with multiple fixtures. | The next required fixture is preselected; an existing draft or submitted/locked sheet is restored correctly. |
| CAP-02 | Submit a valid sheet and attempt direct table mutation outside approved RPCs. | Submission follows competition format and server-side rules; direct client table writes are denied. |
| CAP-03 | Complete a fixture and ask an authorised admin to amend the expired matchday sheet. | Only permitted post-match amendment paths work; historical former-player rows cannot be overwritten. |

### Administration and location boundaries

| ID | Steps | Expected result |
|---|---|---|
| ADM-01 | Sign in as L-01 and open an assigned location's players, fixtures, transfers, team sheets, gallery and statistics. | Only assigned-location data and actions are available. |
| ADM-02 | Attempt to open or mutate a different location by changing route/query identifiers. | Cross-location reads and writes are denied server-side. |
| ADM-03 | Sign in as G-01 and review player identity matches, guardian applications, retention holds and admin audit history. | Global-only actions require the global-admin role and produce audit records. |
| ADM-04 | Sign in as F-01 and open finance workspaces and finance RPCs. | Finance access is limited to the intended finance/admin role; unrelated admin/player roles do not inherit finance access. |
| ADM-05 | Create a fixture using a venue from another location. | Server rejects the mismatch. |
| ADM-06 | Inspect a season with points-tied teams. | Shared positions are shown; goal difference is informational only; tied first place triggers the final-required state. |

### Retention, warnings and reactivation

Run these tests only with synthetic staging accounts and a controlled email provider. Use the documented staging-only method to move the inactivity anchor; do not change a real account's sign-in timestamp.

| ID | Steps | Expected result |
|---|---|---|
| RET-01 | Prepare an eligible synthetic registered player with no active/pending membership, unresolved payment/transfer, admin assignment or retention hold. Move its inactivity anchor to the 90-day-warning threshold. | One 90-day warning is accepted by the provider and recorded once for that inactivity anchor. |
| RET-02 | Re-run the worker without changing the inactivity anchor. | The same successful warning is not sent again. |
| RET-03 | Simulate provider rejection/timeout for a due warning, then retry. | Failed stage remains retryable; no account closure or erasure occurs in a run with warning delivery/recording failure; provider idempotency prevents duplicate acceptance where a prior response was uncertain. |
| RET-04 | Move the synthetic inactivity anchor past the 30-day and 7-day thresholds. | Missing stages are caught up and recorded; the email states a valid no-earlier-than closure date. |
| RET-05 | Attempt closure before all stages are recorded and before seven days have elapsed after the 7-day stage. | Database independently rejects closure. |
| RET-06 | After all three stages are provider-accepted and the final seven-day grace period has elapsed, process the eligible synthetic account. | Account is closed and Auth sign-in is blocked; no real account is affected. |
| RET-07 | Request reactivation for R-01 and use its single-use link. | Same registered-player account is reactivated without restoring membership, pending requests, captaincy or squad permissions. |
| RET-08 | Reuse the reactivation link or request for an unknown email. | Link reuse fails; public response does not reveal whether an account exists. |
| RET-09 | Attempt retention processing for an account with membership, unresolved payment/transfer, admin assignment or retention hold. | Account is excluded and remains active. |
| RET-10 | Allow a synthetic closed account to reach archive expiry; simulate avatar storage deletion failure, then retry after restoring the test storage object. | Failed storage deletion prevents personal-data scrub/Auth deletion; account remains queued for retry. Successful retry removes avatar, scrubs personal links and deletes Auth identity while preserving the Former player competition history. |

### Historic data, payments and statistics

| ID | Steps | Expected result |
|---|---|---|
| HIST-01 | Inspect synthetic player's appearances, goals, results and season statistics before and after erasure. | Historical competition records remain under the account-independent Former player identity. |
| HIST-02 | Attempt standard admin amendment of a protected former-player team-sheet row. | The historic appearance cannot be silently overwritten. |
| PAY-01 | Inspect synthetic payment records and accounting references before/after account erasure. | Direct player/Auth links are detached where designed; legally required accounting/refund/dispute records remain according to the approved schedule. |
| PAY-02 | Attempt finance reads as a player, captain and location admin without finance entitlement. | Finance data remains inaccessible. |

## 4. Responsive and accessibility review

For each of mobile, tablet and desktop, record device/browser/version and test:
- Home, Match Centre, Join Open Play, More and all role-specific hubs.
- Registration forms, validation, empty/loading/error states and consent flows.
- Fixed bottom navigation, scrolling, modal/drawer behaviour and no horizontal overflow.
- Keyboard navigation, visible focus, labels, validation announcements and adequate touch targets.
- Contrast and legibility on dark surfaces; Oswald headings and Inter body text render correctly.
- Session expiry, refresh, back navigation and direct-link entry to protected routes.

## 5. Stop conditions

Stop the run immediately and mark the scenario **Fail** if any of these occur:
- A viewer, under-16 user, banned player or unauthorised role can access private player/admin/finance data.
- A user can read or mutate another location's protected records.
- A guardian token or reactivation token can be reused or exposes a player's date of birth.
- An account can close without the required warning stages and seven-day grace period.
- A provider failure causes account closure/erasure to proceed.
- Erasure deletes historic appearances/goals or leaves an account able to sign in.
- Payment/accounting records are removed contrary to the approved retention schedule.
- A real player, real child, real payment or live account is affected during testing.

Preserve redacted logs and record the scenario ID, timestamp and environment. Do not continue to the next destructive test until the issue is triaged.

## 6. Evidence and sign-off record

| Field | Entry |
|---|---|
| Staging project / environment | Pending |
| Build / commit under test | Pending |
| Reviewer(s) | Pending |
| Test start / end | Pending |
| Device/browser matrix | Pending |
| Email provider / safe inbox | Pending |
| Stripe test-mode confirmation | Pending |
| Scenario results and evidence links | Pending |
| Defects / follow-up issues | Pending |
| Reviewer conclusion | Pending |
| Approval date | Pending |

**Acceptance rule:** All applicable scenarios must pass or have an explicitly approved, risk-assessed deferral with an owner and target date. A blocked test is not a pass. Do not sign off Phase 1 while any critical/high-risk scenario is failed or untested.

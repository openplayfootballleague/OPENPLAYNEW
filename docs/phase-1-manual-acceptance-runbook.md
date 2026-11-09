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
| P-03 | Registered player with a pending team request | Join and transfer request lifecycle |
| P-04 | Registered player eligible to request a transfer | Transfer initiation and denial/approval outcomes |
| C-02 | Captain of a second synthetic team | Transfer decision and squad impact |
| M-01 | Active player in a synthetic team conversation | Messaging sender/recipient permissions |
| M-02 | Non-member / unrelated player | Messaging isolation and denial |
| PAY-03 | Synthetic team with a due/overdue fee | Payment deadlines and status transitions |
| PAY-04 | Finance reviewer with test-mode Stripe access | Payment reconciliation, refunds and disputes |

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


### End-to-end account journey and role transitions

Run each journey from a clean synthetic identity. Verify both the visible app state and the server-side permissions after every transition. A successful database mutation alone is not a complete pass.

| ID | Steps | Expected result |
|---|---|---|
| FLOW-01 | V-01 browses public pages, creates an account, verifies email, signs out and signs back in. | Visitor becomes an authenticated account; verification state is respected; public navigation remains correct and no player privileges appear prematurely. |
| FLOW-02 | Create an account, leave registration incomplete, close the app, return later and resume. | Existing account is recovered; entered data is handled consistently; no duplicate Auth identity/player profile is created; incomplete registration remains restricted. |
| FLOW-03 | Attempt to register twice using the same signed-in account and submit duplicate registration requests rapidly. | No duplicate player identity or conflicting application is created; the user receives a safe, understandable outcome. |
| FLOW-04 | Complete adult registration from start to finish, then refresh, sign out/in and open direct Player Hub links. | Approved registered-player state and navigation are consistent across refresh and new sessions; server-side access matches the UI. |
| FLOW-05 | Submit an invalid or incomplete registration, correct it and resubmit. | Validation identifies the issue without losing valid fields; no partial or privileged player state is created. |
| FLOW-06 | Submit a team-creation application as an eligible registered player; inspect access before admin approval, then approve it. | Applicant is not prematurely treated as an active captain; on approval, the intended applicant becomes captain of the correct team with only the approved permissions. |
| FLOW-07 | Repeat FLOW-06 but reject the team application. | Applicant remains a registered player without an unwanted team, captain role or inaccessible team workspace; rejection is communicated safely. |
| FLOW-08 | As P-03, request to join an existing team; inspect the player and captain views before a decision. | Request is pending; player is not an active member and cannot use member-only functions until approval. |
| FLOW-09 | As the captain, approve P-03; refresh both sessions and inspect Player Hub, squad and fixtures. | Membership is active exactly once; the correct team is shown to the player and captain; permissions update consistently. |
| FLOW-10 | Repeat a join request and submit duplicate requests rapidly or from two sessions. | Duplicate/pending membership is prevented; no double membership, duplicate notifications or inconsistent squad entries occur. |
| FLOW-11 | As captain, reject a join request. | Request is denied and no membership or team access is granted; the player remains registered and can follow the permitted next step. |
| FLOW-12 | Player withdraws/cancels a pending join request, where the interface permits it. | Request becomes inactive once; captain's pending queue updates; no membership is created. |
| FLOW-13 | Player leaves a team or an authorised captain/admin removes the player. | Membership ends according to the defined workflow; player remains registered; old team permissions and private data access are removed; historic competition records remain. |
| FLOW-14 | A player requests to join another team after leaving or being removed from the previous team. | Eligibility is recalculated correctly; no stale membership blocks or grants access; the new request follows normal approval. |
| FLOW-15 | Change captaincy to an eligible successor and sign in as both old and new captains. | New captain receives captain functions; former captain loses them immediately; both retain only their underlying player permissions. |
| FLOW-16 | Sign in as one user, sign out, then sign in as a different user in the same browser/device. | No prior user's profile, messages, team, notifications, cached data or permissions remain visible. |
| FLOW-17 | Expire a session while a user is on a protected page and while a form is in progress. | Protected content is not left exposed; session recovery is safe; the user receives a clear sign-in/retry path without duplicate submissions. |
| FLOW-18 | Refresh, use browser back/forward and open a protected deep link after each major role transition. | Route guards and server authorisation agree; stale client state cannot preserve access after a role or membership change. |
| FLOW-19 | Attempt to join or create a team as an under-16, pending, rejected, banned or otherwise ineligible account. | Ineligible account cannot bypass the workflow through direct URLs, API calls or stale UI. |
| FLOW-20 | Reactivate a closed account and inspect profile, membership, messages, captaincy and squad access. | Same registered-player account is restored as specified; old memberships, pending requests, captaincy and permissions are not silently restored. |

### Transfers — approval, denial, expiry and race conditions

Use two synthetic teams in the same eligible competition and test the transfer rules configured for that competition. Do not assume a transfer is complete merely because a request exists.

| ID | Steps | Expected result |
|---|---|---|
| TRF-01 | Eligible player initiates a transfer request from their current team to a destination team. | Request records the correct player, source team, destination team, competition/season and status; current membership remains unchanged while pending. |
| TRF-02 | Destination captain reviews and approves the transfer. | Transfer completes once, membership changes according to the configured transfer rules, and old/new team views update consistently. |
| TRF-03 | Destination captain explicitly denies the transfer request. | Request is marked denied with the correct audit/status history; player remains with the original team and retains no destination-team access. |
| TRF-04 | Source captain or required approver denies/declines a transfer where the workflow requires their decision. | Denial prevents completion; current membership remains intact; the request clearly shows which decision is outstanding/denied. |
| TRF-05 | Attempt to approve a previously denied, cancelled or expired request through the UI and direct endpoint. | Terminal request cannot be revived or approved; a new request is required if policy allows. |
| TRF-06 | Player cancels a pending transfer, where permitted. | Request is cancelled once; existing membership and permissions remain unchanged. |
| TRF-07 | Attempt a second transfer while one is already pending. | Conflicting requests are blocked or handled by the explicit competition rule; no ambiguous dual destination or double membership results. |
| TRF-08 | Submit a transfer request when the player has no active source membership, is banned, is pending registration or is otherwise ineligible. | Server rejects the request and does not create a misleading pending transfer. |
| TRF-09 | Test transfer requests at the configured opening/closing deadline, immediately before and after it, including the competition's local timezone and daylight-saving boundary where relevant. | Boundary is deterministic and server-enforced; UI deadline matches server decision; late requests cannot bypass the deadline by changing device clock/timezone. |
| TRF-10 | Leave a transfer pending until its configured expiry/deadline passes. | It moves to the defined expired/closed state if expiry is part of the product rules; no stale approval action remains available. If no automatic expiry is specified, record the actual manual/admin resolution rule rather than inventing one. |
| TRF-11 | Two authorised users attempt conflicting decisions at nearly the same time. | Exactly one valid terminal decision wins; no duplicate membership, contradictory audit records or partial transfer occurs. |
| TRF-12 | Inspect notifications and audit history for approved, denied, cancelled and expired transfers. | Only intended parties receive appropriate updates; status, actor and timestamps are accurate; private details are not exposed to unrelated users. |

### Messaging and conversation permissions

First confirm which messaging surfaces and message types are included in the release. Test only implemented features; do not treat read receipts, attachments, group chat or moderation controls as requirements unless they are part of the approved product scope.

| ID | Steps | Expected result |
|---|---|---|
| MSG-01 | Active team members open the intended team conversation/message area. | Only authorised participants can read the conversation and its history. |
| MSG-02 | M-01 sends a message and another authorised participant receives it. | Message is persisted once, attributed to the correct sender and delivered/displayed to intended recipients. |
| MSG-03 | Refresh, sign out/in and open the conversation on a second device/session. | Message history and ordering remain consistent; no duplicate messages appear. |
| MSG-04 | M-02 attempts to open the conversation by navigating directly to its URL/identifier or calling the underlying endpoint. | Non-member cannot read, send to or enumerate the private conversation. |
| MSG-05 | A player leaves/is removed from a team, is banned, or loses the relevant role while a conversation is open. | Access follows the documented membership/role policy immediately; stale sessions cannot continue sending or reading protected messages. |
| MSG-06 | A new player is approved into the team. | Access to team conversations follows the defined rule; historical message visibility is consistent with the product's privacy policy and is not accidentally broadened. |
| MSG-07 | Attempt to send an empty, whitespace-only, oversized or malformed message; rapidly submit the same message twice. | Invalid content is rejected safely; duplicate submission does not create duplicate messages; limits and errors are clear. |
| MSG-08 | Simulate network interruption or provider/API failure during send, then retry. | UI distinguishes pending/failed/sent states accurately; retry does not duplicate a message that was already persisted. |
| MSG-09 | Test message ordering and timestamps across devices with different local timezones and clocks. | Server ordering/timestamps remain authoritative and display consistently in the user's local timezone. |
| MSG-10 | Inspect notifications generated by a new message, including muted/disabled or unavailable recipients if those states exist. | Only intended recipients are notified; notification content does not expose private message text on unintended surfaces; delivery failure does not lose the persisted message. |
| MSG-11 | Attempt to access another team's conversation by changing IDs, query parameters or cached links. | Server denies cross-team access and does not reveal whether another conversation exists. |
| MSG-12 | Test any implemented conversation creation, group membership, read state, attachment, blocking or reporting controls against their documented permissions and failure states. | Each implemented control follows its documented policy; unsupported controls are not represented as available. |

### Payments, fees, deadlines and reconciliation

Use Stripe test mode and synthetic customers only. Before testing, record the configured fee amount, currency, due date/deadline, timezone, reminder schedule, grace period, late-payment consequences, refund policy and who is liable (team, captain or player). Where a policy is not yet defined, record it as a product/business decision; do not invent a deadline or automatically impose a restriction.

| ID | Steps | Expected result |
|---|---|---|
| PAY-03 | Accept the displayed team/season fee during team registration and proceed to checkout. | Correct amount, currency, payer and team/season reference are shown; acceptance is recorded; no team is marked paid before verified payment success. |
| PAY-04 | Complete a successful Stripe test checkout. | Verified webhook/server result updates the correct payment record exactly once; the app displays the correct paid state and receipt/reference. |
| PAY-05 | Open checkout then abandon/cancel without paying. | Payment remains unpaid/pending according to the defined state; no paid entitlement or false confirmation is granted. |
| PAY-06 | Simulate card decline, authentication/3-D Secure failure, checkout timeout and provider error. | Failure is shown clearly; no false paid state; retry is possible without duplicate charges or records. |
| PAY-07 | Deliver the same successful webhook more than once. | Idempotency prevents duplicate payment, fee settlement, notification or entitlement. |
| PAY-08 | Deliver webhook events late or out of order (for example, delayed success after a browser cancellation, or failure after a confirmed success). | Server reconciles authoritative provider state safely; stale events cannot downgrade or duplicate a settled payment. |
| PAY-09 | Attempt to alter checkout amount, currency, team, season, player or payment reference client-side. | Server-created checkout details remain authoritative; tampering is rejected and cannot redirect a payment to another account/team. |
| PAY-10 | Create a fee with a known due date and inspect it before, on and after the deadline using the configured local timezone. | Due/overdue status changes at the exact server-defined boundary; UI and notifications show the same deadline and timezone. |
| PAY-11 | Test payment immediately before and after a deadline, including daylight-saving transition and a device set to a different timezone. | Server time is authoritative; boundary behaviour is deterministic; changing the device clock/timezone cannot extend the deadline. |
| PAY-12 | Allow a synthetic fee to become overdue without payment. | The configured overdue state, reminder and any restrictions follow the published policy; no unapproved automatic ban, membership removal or account closure occurs. |
| PAY-13 | Pay an overdue fee successfully. | Outstanding balance/status reconciles correctly; any payment-related restriction is lifted only as defined by policy; no unrelated player or team status is restored. |
| PAY-14 | Simulate partial payment, overpayment or multiple attempts against the same fee if supported. | Balance and ledger remain accurate; unsupported partial payments are rejected rather than misrepresented; duplicate settlement is prevented. |
| PAY-15 | Issue a full or partial refund in Stripe test mode and deliver the corresponding webhook. | Refund is linked to the correct original payment; paid/outstanding/refunded balances and audit trail update correctly. |
| PAY-16 | Simulate a dispute/chargeback and subsequent resolution. | Finance status and evidence trail update; player/team access follows the documented policy and is not silently changed by an unverified event. |
| PAY-17 | Inspect payments as player, captain, location admin and finance role. | Each role sees only the payment information/actions explicitly permitted; finance details remain restricted. |
| PAY-18 | Reconcile Stripe test transactions against the Open Play finance ledger and export/report totals. | No missing, duplicated or misattributed transactions; totals, currency, refunds and outstanding balances reconcile. |
| PAY-19 | Attempt retention closure/erasure for a synthetic account with an unresolved payment, refund or dispute. | Retention is blocked/excluded as designed; required accounting records are preserved and direct identity links are handled according to the approved schedule. |
| PAY-20 | Test payment reminders and deadline notifications at each configured reminder point, including provider failure and retry. | Correct recipient, amount, due date and payment link are used; retries do not duplicate accepted notifications; no reminder is sent after settlement unless policy requires it. |
| PAY-21 | Attempt to pay the same fee from two sessions or submit two checkout requests concurrently. | One fee cannot be settled twice; concurrent checkout attempts reconcile to one authoritative outstanding/paid state. |
| PAY-22 | Test a fee deadline changed by an authorised administrator after issue, including an already-overdue fee. | Only authorised changes succeed; old/new deadline and reason are auditable; notifications and status recalculate consistently. |

**Payment policy gate:** No payment scenario can be signed off until the actual fee schedule and deadline rules are written down. At minimum, specify whether fees are per team or per player, who pays, when they are due, reminders, grace periods, consequences of non-payment, refund handling and dispute handling. The acceptance suite verifies the agreed policy; it must not silently create one.


### Historic data, payments and statistics

| ID | Steps | Expected result |
|---|---|---|
| HIST-01 | Inspect synthetic player's appearances, goals, results and season statistics before and after erasure. | Historical competition records remain under the account-independent Former player identity. |
| HIST-02 | Attempt standard admin amendment of a protected former-player team-sheet row. | The historic appearance cannot be silently overwritten. |
| PAY-01 | Inspect synthetic payment records and accounting references before/after account erasure. | Direct player/Auth links are detached where designed; legally required accounting/refund/dispute records remain according to the approved schedule. |
| PAY-02 | Attempt finance reads as a player, captain and location admin without finance entitlement. | Finance data remains inaccessible. |

## 5. Responsive and accessibility review

For each of mobile, tablet and desktop, record device/browser/version and test:
- Home, Match Centre, Join Open Play, More and all role-specific hubs.
- Registration forms, validation, empty/loading/error states and consent flows.
- Fixed bottom navigation, scrolling, modal/drawer behaviour and no horizontal overflow.
- Keyboard navigation, visible focus, labels, validation announcements and adequate touch targets.
- Contrast and legibility on dark surfaces; Oswald headings and Inter body text render correctly.
- Session expiry, refresh, back navigation and direct-link entry to protected routes.

## 6. Stop conditions

Stop the run immediately and mark the scenario **Fail** if any of these occur:
- A viewer, under-16 user, banned player or unauthorised role can access private player/admin/finance data.
- A user can read or mutate another location's protected records.
- A guardian token or reactivation token can be reused or exposes a player's date of birth.
- An account can close without the required warning stages and seven-day grace period.
- A provider failure causes account closure/erasure to proceed.
- Erasure deletes historic appearances/goals or leaves an account able to sign in.
- Payment/accounting records are removed contrary to the approved retention schedule.
- A real player, real child, real payment or live account is affected during testing.
- A denied/expired transfer grants destination-team access or removes the player's existing membership.
- A non-member can read or send messages in a private team conversation.
- A payment is marked settled without authoritative provider confirmation, is settled twice, or a deadline can be bypassed by changing the device clock.
- An overdue fee causes an unapproved ban, membership removal or account closure.

Preserve redacted logs and record the scenario ID, timestamp and environment. Do not continue to the next destructive test until the issue is triaged.

## 7. Evidence and sign-off record

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

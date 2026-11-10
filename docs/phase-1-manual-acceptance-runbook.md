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
| BILL-01 | Synthetic team with a due/overdue fee | Payment deadlines and status transitions |
| FIN-01 | Finance reviewer with test-mode Stripe access | Payment reconciliation, refunds and disputes |
| RFE-01 | Approved referee with active membership | Fixture appointments, match reports and notifications |
| RFE-02 | Second approved referee with active membership | Assignment conflicts, cross-account isolation and cancellation |

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
| CAP-04 | As C-01, edit and save a team-sheet draft several times before kickoff, then review it and submit only after checking the explicit confirmation box. | Draft changes persist and remain editable before kickoff; review is separate from submission; confirmation locks the final sheet. |
| CAP-05 | Save a draft for a club whose fixture is within 24 hours, then inspect emergency transfer destinations as an unattached player. | The club remains eligible while its sheet is a draft; it disappears from emergency destinations immediately after the captain confirms submission. |
| CAP-06 | Attempt to save or submit a team sheet at or after kickoff. | Database rejects the change even if the fixture still has scheduled status. |
| TRF-01 | As P-04, leave a non-captain active club membership from Player Hub. | The player can leave without old-captain/admin approval; membership history remains; a captain must appoint a replacement before leaving. |
| TRF-02 | As P-04, attempt to request a destination while still attached, then leave and submit a normal transfer request. | Attached request is denied; after leaving, only clubs in a previously represented league are offered; only one normal request may be pending. |
| TRF-03 | In the final 24 hours before kickoff, request all eligible clubs whose sheets are not submitted; include one club with a locked submitted sheet. | Multiple emergency requests are created for eligible clubs; submitted-sheet club is excluded; a draft-only club remains eligible. |
| TRF-04 | Have two destination captains approve the same player's emergency requests in close succession. | First approval wins, activates exactly one destination membership and cancels all competing pending requests; the later approval is rejected. |
| TRF-05 | Have one captain reject an emergency request while another remains pending. | Player remains unattached; the other request remains pending and can still be approved. |
| TRF-06 | Attempt to create active memberships for the same player at two clubs in different seasons of the same league, then at a club in a different league. | Second different-club membership in the same league is rejected server-side; a membership in the same club across seasons and a membership in another league remain allowed. |
| TRF-07 | A player has an emergency request pending, then the destination captain submits the team's matchday sheet. | The pending emergency request is automatically cancelled; the club is no longer available as a destination. |
| TRF-08 | A player who voluntarily left a club tries to use the ordinary first-time team-join request to join a different club. | The request is denied and the player is directed through the transfer workflow; first-time entrants and same-club returns can still use ordinary joining. |

### Administration and location boundaries

| ID | Steps | Expected result |
|---|---|---|
| ADM-01 | Sign in as L-01 and open an assigned location's players, fixtures, transfers, team sheets, gallery and statistics. | Only assigned-location data and actions are available. |
| ADM-02 | Attempt to open or mutate a different location by changing route/query identifiers. | Cross-location reads and writes are denied server-side. |
| ADM-03 | Sign in as G-01 and review player identity matches, guardian applications, retention holds and admin audit history. | Global-only actions require the global-admin role and produce audit records. |
| ADM-04 | Sign in as F-01 and open finance workspaces and finance RPCs. | Finance access is limited to the intended finance/admin role; unrelated admin/player roles do not inherit finance access. |
| ADM-05 | Create a fixture using a venue from another location. | Server rejects the mismatch. |
| ADM-06 | Inspect a season with points-tied teams. | Shared positions are shown; goal difference is informational only; tied first place triggers the final-required state. |

### Admin dashboard end-to-end workflows, editing and permission usability

Run these scenarios as G-01, L-01 and F-01, plus unauthorised player/captain personas. Use a populated but synthetic staging dataset with at least two locations, two seasons, multiple teams, fixtures, players, applications, payments and historic results. Test the dashboard as an operator doing real work, not just by calling RPCs. For every permitted edit, verify the saved value, audit trail where required, downstream screens and public/player-facing impact. For every denied edit, verify that no partial mutation occurred.

**Core acceptance principle:** the dashboard must not impose an accidental permission wall on an action the signed-in admin is authorised to perform. Equally, a visible button or editable field is not authority: the server must enforce the correct role, location, record state and business rule. Maintain an explicit role/action matrix; if a task is blocked, identify whether the block is intended policy, missing assignment, invalid state, UI defect or server defect.

| ID | Steps | Expected result |
|---|---|---|
| ADM-07 | Sign in as G-01 and open every dashboard section from the sidebar: Overview/Needs Attention, Locations & Leagues, Seasons, Teams, Players, Approvals, Fixtures, Team Sheets, Results & Match Events, Statistics, Gallery, Finance, Feature Management and Settings. | Every authorised section loads; no dead links, blank panels, endless spinners, broken back navigation or unexplained access-denied screens. Unavailable features are clearly marked rather than presented as working controls. |
| ADM-08 | Repeat the dashboard navigation as L-01 and F-01. | Each role sees the sections/actions it is entitled to; location admins see only assigned-location operations; finance role sees only intended finance operations. No valid task is blocked merely because an unrelated permission is missing. |
| ADM-09 | Use Overview/Needs Attention with a mixture of pending player applications, team applications, guardian reviews, transfer requests, missing team sheets, results awaiting publication and finance tasks. Open each item and complete or dismiss it where authorised. | Counts and links are accurate; each item opens the correct record/action; completion removes or updates the task; unrelated items remain; no task silently disappears without a valid state change. |
| ADM-10 | Search and filter Players, Teams, Seasons, Fixtures, Applications and Finance registers by name, status, location, season and relevant identifiers. Clear filters and paginate/sort. | Results match filters; no cross-location leakage; sorting/pagination do not lose edits or show duplicate/missing rows; empty states explain how to recover. |
| ADM-11 | Open a record, edit permitted fields, save, refresh and reopen it. | Changes persist and are reflected consistently in related dashboard views and the appropriate player/public views; unchanged fields remain unchanged. |
| ADM-12 | Attempt to edit read-only or protected fields, including player identity fields restricted by the product, historic competition identity and protected former-player rows. | UI communicates read-only status; direct API/RPC attempts are also rejected; no workaround through a different screen or bulk editor. |
| ADM-13 | Submit invalid values, missing required fields, malformed dates, duplicate names/identifiers and values outside configured limits. | Field-level validation is clear; server validation agrees; invalid submissions do not partially save or corrupt related records. |
| ADM-14 | Simulate a network error, server error or session expiry during save; retry after recovery. | UI reports failure honestly; no false success toast; retry is safe and idempotent; no duplicate record or partial multi-table update. |
| ADM-15 | Edit the same record from two authorised admin sessions, saving conflicting values in turn. | Stale updates are detected or resolved by a documented last-write/version policy; no silent data loss; audit history records the actual committed change where required. |
| ADM-16 | As L-01, create/edit/archive permitted records inside the assigned location, then attempt the same operations against a different location by changing IDs or request payloads. | Assigned-location actions work end-to-end; out-of-scope reads/writes are denied server-side; the UI does not falsely suggest a successful save. |
| ADM-17 | As G-01, create a location, league and season; edit their permitted settings; deactivate/archive where allowed; inspect dependent records. | Global admin can complete the intended setup and maintenance tasks; dependencies and confirmation prompts prevent accidental destructive changes; historical records remain consistent. |
| ADM-18 | Create/edit teams, update permitted team details, assign a captain through the approved workflow and inspect squad/membership state. | Correct team is changed; captain/member relationships are valid; no duplicate or orphan membership; changes are visible to the right users. |
| ADM-19 | Process player applications: inspect details, approve, reject, request correction or leave pending where supported. | Each action is available to the authorised reviewer; decision and reason are recorded; applicant status and access change correctly; duplicate or repeated decisions are safely blocked. |
| ADM-20 | Process team applications through approve/reject paths, including fee acceptance/payment prerequisites where configured. | Approval creates/activates only the intended team and captain; rejection creates no active team/captain privileges; finance state is not fabricated. |
| ADM-21 | Create, edit, regenerate and publish fixtures using the approved fixture generator; include an invalid venue/location combination and a season with existing results. | Valid schedules can be created and amended; invalid cross-location venues are rejected; regeneration cannot silently overwrite played/published fixtures or existing results; previews and confirmation explain impact. |
| ADM-22 | Enter and edit match results, scorers and match events as an authorised admin; attempt duplicate result submission and invalid scorers. | Correct fixture/team/player linkage is enforced; scorer must be eligible for the relevant team/fixture; result publication updates standings/statistics once; duplicates and invalid references are rejected. |
| ADM-23 | Correct a published result using the authorised correction path. | Correction is possible for an authorised admin without an unnecessary permission dead end; previous value/change reason is auditable; tables, statistics and notifications are recalculated consistently. |
| ADM-24 | Open a fixture's team sheet before, during and after matchday; amend an expired sheet as an authorised admin and attempt to change a protected historic former-player row. | Correct next fixture and sheet state are shown; permitted admin amendments work after the match; protected historic identity/appearance constraints remain enforced. |
| ADM-25 | Review transfer requests as an authorised admin, including pending, approved, denied, cancelled and expired states. | Admin can perform only the decisions permitted by the transfer policy; terminal states cannot be reopened accidentally; both teams and player reflect the final outcome. |
| ADM-26 | Manage gallery items: create/upload a synthetic image, edit metadata, publish/unpublish and archive/delete where authorised. | Only permitted media and metadata changes save; public gallery reflects publication state; storage failures are visible and do not leave broken published records. |
| ADM-27 | Open Statistics and compare totals against synthetic source fixtures, results, team sheets and scorer events; make a permitted correction upstream and recheck. | Statistics reconcile to source data and recalculate after valid corrections; admin cannot directly edit derived values in a way that creates inconsistency. |
| ADM-28 | As F-01, review payment records, outstanding fees, refunds and disputes; export/report if supported. Attempt the same finance actions as L-01, C-01 and P-01. | Finance role can complete intended finance work; non-finance roles cannot access protected financial details or actions; displayed totals reconcile to the ledger/provider state. |
| ADM-29 | Change feature flags, league recruitment and announcement toggles as authorised; inspect public/player impact and repeat as an unauthorised role. | Authorised changes take effect only in their intended scope; unauthorised changes are denied; turning a feature off does not destroy underlying data or bypass critical admin access. |
| ADM-30 | Review admin audit history after edits, approvals, role/assignment changes, bans, finance actions and destructive operations. | Actor, action, target, timestamp and reason are recorded where required; audit entries are immutable to ordinary admins and do not expose secrets. |
| ADM-31 | Attempt destructive or high-impact actions (delete/archive season, remove team, revoke admin assignment, ban player, publish results, bulk edit) with cancel, missing reason and confirm paths. | Clear confirmation and reason requirements apply where specified; cancel makes no change; authorised confirmation succeeds; unauthorised or invalid-state operation is rejected. |
| ADM-32 | Test bulk actions and multi-select operations on mixed eligible/ineligible records. | Only eligible selected records change; ineligible rows are reported clearly; operation is atomic or reports per-row outcomes exactly as designed; no unintended records are included. |
| ADM-33 | Use dashboard links from notifications, Needs Attention, search results and related-record panels. | Every action opens the correct record with the right context and permissions; no broken deep links or navigation traps. |
| ADM-34 | Perform a complete routine admin task without developer/database intervention: approve an application, correct a fixture/result, resolve a transfer, update a team/player field and review a payment. | An authorised admin can complete the normal operational workflow through the UI; no missing button, hidden RPC dependency, unnecessary permission wall or manual SQL workaround blocks the task. |
| ADM-35 | For each role, attempt one action just outside its authority and one valid action within its authority, through both UI and direct request. | Valid work succeeds; invalid work is denied; role boundaries are precise rather than broadly blocking or broadly granting access. |

**Admin usability evidence:** For ADM-07 through ADM-35 record the persona, location assignment, dashboard section, record state, intended action, whether the UI exposed the action, result, server response, persisted state, audit entry and any downstream impact. A backend permission test alone does not prove the admin workflow is achievable or easy to use.

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


## 4. End-to-end account journey and role transitions

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

### Payments, fees, deadlines, late strikes and cancellation

Use Stripe test mode and synthetic customers only. The agreed Open Play fixture-payment policy is:

1. **Payment deadline — 24 hours before kick-off.** The team fee must be paid by this point. The captain/team sees a live countdown to the deadline, with the exact local deadline displayed. Server time is authoritative; changing a device clock or timezone cannot extend the deadline.
2. **Late-payment window — the following 12 hours.** If the deadline passes unpaid, the team receives one late-payment strike and the captain/admins are notified. The fixture remains scheduled during this window. The team may still pay, but paying late does not remove the strike.
3. **Cancellation threshold — 12 hours before kick-off.** If still unpaid at the end of the late-payment window, the fixture is cancelled. The non-paying team remains liable for its match fee despite the cancellation. The opposing team, if it paid, is due a full refund.
4. **Refund completion.** The opponent's refund is initiated against the original payment and is not shown as completed until Stripe/provider confirmation is received. Failed or delayed refunds enter the admin Needs Attention queue for resolution; they must not be silently marked refunded.
5. **Three strikes in a season.** The team is automatically referred to admins for review. The proposed outcome is removal from the league, but removal is **not automatic**: the team is suspended from further fixtures pending admin clearance, and an authorised admin must review the circumstances and explicitly approve reinstatement or removal. Record the decision and reason in the audit trail. A strike is not erased merely because the late fee is subsequently paid.
6. **Case-by-case admin discretion.** Admins must be able to review the circumstances and decide the appropriate outcome. The system must not impose automatic permanent removal based solely on reaching three strikes.

The configured fee amount, currency, liable team, fixture/kick-off time and Europe/London deadline calculation must be explicit. Use the fixture's authoritative scheduled kick-off and Europe/London civil time for user-facing deadlines, with an unambiguous stored timestamp and deterministic daylight-saving handling. If a fixture time changes, recalculate deadlines and notify affected teams; preserve the previous deadline and reason in the audit history. No admin may silently waive the non-paying team's fee or mark the opposing team's refund complete without the corresponding authorised financial action/provider confirmation.

| ID | Steps | Expected result |
|---|---|---|
| PAY-03 | Accept the displayed team/season fee during team registration and proceed to checkout. | Correct amount, currency, payer and team/season reference are shown; acceptance is recorded; no team is marked paid before verified payment success. |
| PAY-04 | Complete a successful Stripe test checkout. | Verified webhook/server result updates the correct payment record exactly once; the app displays the correct paid state and receipt/reference. |
| PAY-05 | Open checkout then abandon/cancel without paying. | Payment remains unpaid/pending according to the defined state; no paid entitlement or false confirmation is granted. |
| PAY-06 | Simulate card decline, authentication/3-D Secure failure, checkout timeout and provider error. | Failure is shown clearly; no false paid state; retry is possible without duplicate charges or records. |
| PAY-07 | Deliver the same successful webhook more than once. | Idempotency prevents duplicate payment, fee settlement, notification or entitlement. |
| PAY-08 | Deliver webhook events late or out of order (for example, delayed success after a browser cancellation, or failure after a confirmed success). | Server reconciles authoritative provider state safely; stale events cannot downgrade or duplicate a settled payment. |
| PAY-09 | Attempt to alter checkout amount, currency, team, season, player or payment reference client-side. | Server-created checkout details remain authoritative; tampering is rejected and cannot redirect a payment to another account/team. |
| PAY-10 | Inspect the team fee countdown at 24 hours plus, exactly 24 hours, and immediately after the deadline. | Countdown is accurate and visible to the captain/team; the 24-hour deadline is the server-authoritative boundary; immediately after it, the late window and one strike are recorded exactly once. |
| PAY-11 | Pay immediately before and after the 24-hour deadline, including DST transition and a device set to a different timezone. | On-time payment creates no strike; payment during the 12-hour late window is accepted but retains the strike; device clock/timezone changes cannot bypass the deadline. |
| PAY-12 | Leave the fee unpaid throughout the 12-hour late window and inspect immediately before, at and after the 12-hours-before-kick-off threshold. | Fixture remains scheduled during the late window; at the threshold it is cancelled once, with an auditable reason and notification to both teams. |
| PAY-13 | After the cancellation threshold, inspect both teams' financial records. | Non-paying team remains liable for the full match fee; paid opposing team receives a full refund against its original transaction; neither liability nor refund is duplicated. |
| PAY-14 | Simulate a refund provider delay, failure, duplicate webhook and successful retry for the opposing team. | Refund is shown as pending/failed until provider confirmation; retry is idempotent; admin Needs Attention shows unresolved refunds; confirmed refund reconciles the ledger once. |
| PAY-15 | Test a team paying within the late window after receiving a strike. | Fixture remains valid; payment settles the fee; strike remains on the team's season record and is visible to authorised admins. |
| PAY-16 | Create a team with one, two and then three late-payment strikes in the same season. | First and second strikes are recorded and surfaced; the third triggers an admin review/referral and suspends the team from further fixtures pending clearance; no automatic permanent removal occurs. |
| PAY-17 | As an authorised admin, review a three-strike team with different documented circumstances and choose reinstate or remove. | Admin can inspect the strike/payment/fixture history, record a reason and make an explicit decision; only authorised admin roles can decide; the action is audited and the team state updates consistently. |
| PAY-18 | Attempt to create, edit or delete strikes directly as a captain/player or unauthorised admin. | Server rejects unauthorised changes; strike history is tamper-resistant and visible only to permitted roles. |
| PAY-19 | Change a fixture kick-off time after a fee has been issued. | The 24-hour deadline and late/cancellation boundaries recalculate from the new kick-off; affected teams are notified; previous values and change reason remain auditable. |
| PAY-20 | Reconcile Stripe test transactions, non-paying-team liabilities, opponent refunds and strike records against the Open Play finance ledger. | No missing, duplicated or misattributed transactions; amounts, currencies, outstanding liabilities, refunds and strike counts reconcile. |
| PAY-21 | Inspect payment and strike information as player, captain, location admin and finance role. | Each role sees only information/actions explicitly permitted; finance details and admin-only strike decisions remain restricted. |
| PAY-22 | Attempt retention closure/erasure for a synthetic account/team with an unresolved match fee, refund or dispute. | Retention is blocked/excluded as designed; required accounting records are preserved and direct identity links are handled according to the approved schedule. |
| PAY-23 | Attempt concurrent checkout/payment for the same fixture fee from two sessions. | The fee cannot be settled twice; concurrent attempts reconcile to one authoritative outstanding/paid state. |
| PAY-24 | Attempt an admin deadline edit, fee waiver, strike adjustment or refund completion without the required role/recorded reason/provider confirmation. | Only authorised actions succeed; changes are auditable; no UI-only permission boundary or false financial completion is accepted. |

**Payment policy gate:** The deadline, 12-hour late-payment window, strike, cancellation, non-paying team's continuing fee liability, opposing team's full refund and three-strike admin-review process are agreed policy and must be implemented and accepted as written. The actual season/team fee amount and currency remain configuration/business data, not assumptions. Stripe test mode and synthetic accounts only; no real charges or refunds during acceptance.

### Referee applications, appointments, reports and discipline

| ID | Steps | Expected result |
|---|---|---|
| REF-01 | Submit a referee application as RFE-01 with experience, qualifications, availability and preferred locations. Attempt duplicate pending submission and invalid availability. | Application validation is server-enforced; duplicate pending applications and invalid availability are rejected. |
| REF-02 | Review the application as an administrator for the permitted location; approve, reject, suspend and reinstate in separate synthetic test cycles. | Decisions require a reason, are location-scoped and audited; referee membership is separate from player registration and suspended referees cannot access Matchday. |
| REF-03 | Allocate RFE-01 to a future fixture within their declared availability, then attempt a different location, unavailable time, duplicate role and same-kickoff conflict using RFE-02. | Only eligible active referees can be appointed; conflicts and invalid location/time combinations are rejected; each active appointment is unique. |
| REF-04 | Cancel an appointment with and without a reason; inspect referee notification and assignment history. | Cancellation requires a reason, preserves the original assignment, and queues a notification exactly once. |
| REF-05 | Sign in as RFE-01 and RFE-02 and inspect each Matchday workspace and direct report URLs. | Each referee sees only their own active appointments and can submit only for an assigned fixture; another referee's fixture/report is inaccessible. |
| REF-06 | Submit an initial report just before, exactly at and just after 24 hours from the latest fixture in the gameweek. | The 24-hour deadline is calculated from the latest gameweek fixture; initial submission is accepted through the boundary and rejected after it. |
| REF-07 | Have an administrator reject a submitted report with a reason, wait until after the original deadline, then correct and resubmit it as the appointed referee. | Rejected work remains available after the deadline; version history is preserved; the referee receives an in-app/email notification containing the review reason. |
| REF-08 | Use an administrator account to submit a report for a completed fixture after the referee deadline. Attempt the same action as a referee or an administrator outside the fixture's location. | Admin takeover is permitted only for an authorised location; unauthorised roles/locations are denied and no referee payout obligation is created for an admin-submitted report. |
| REF-09 | Approve a referee-submitted report and inspect the official result, scorer/appearance records, disciplinary events, team fines, player strikes and referee payout obligation. | Approval is atomic and audited; result/statistics publish once; fines are charged to the correct team; only a straight red to a registered player adds a strike; the third strike blocks selection on new sheets; one £22 gross payout obligation is recorded, but no payment is claimed until Stripe Connect transfer confirmation. |
| REF-10 | Attempt duplicate approval, a direct write to report/discipline/payout tables, a disciplinary player team-sheet addition, and administrator reactivation with/without a reason. | Direct writes are denied; duplicate approval cannot duplicate results, fines or payout obligations; disciplinary restriction is enforced by the database; reactivation requires an authorised reason and retains the strike history. |
| REF-11 | Inspect the referee's Player/Referee notifications, then simulate missing provider credentials, provider rejection and retry in the isolated staging environment. | In-app notifications remain available; email is only marked sent after provider acceptance; failures remain visible/retryable and do not change report approval state. |
| REF-12 | As an authorised location administrator, correct an approved report using its current version, including score/scorers/appearances and disciplinary events; retry with the stale version. | The correction is reasoned, location-scoped and version-checked; result/statistics are recalculated; old card incidents remain as voided history; each old fine is offset by an append-only team credit and corrected fines are posted once; erroneous player strikes are reversed without erasing history; the existing referee payout entitlement is unchanged; stale retries are rejected. A team credit is not a cash refund—any cash refund follows the separate authorised refund workflow. |
| REF-13 | Inspect referee payout obligations and attempt to mark one as paid without a confirmed Stripe Connect transfer/webhook. | Payout remains pending; no admin UI or manual database edit can falsely mark a referee paid. Connect onboarding, transfers, webhook reconciliation and payout controls remain a release gate. |
| REF-14 | As an authorised location administrator, select a completed fixture with both locked team sheets, enter the score, select substitute appearances and goalscorers, add disciplinary events and submit an administrator report. Repeat against a rejected report. | Only completed fixtures within the administrator's location scope are selectable; player options come from the locked sheets; score/scorer/discipline validation is server-enforced; the report is saved as submitted/amended and remains unpublished until separate approval. |
| REF-15 | As a location administrator, filter referee payout obligations by status and inspect a pending, transferred and failed synthetic obligation. Attempt to access another location's records or change a status manually. | The queue is location-scoped and read-only; it reconciles gross, deductions, net and top-up values; pending obligations are never shown as paid; status changes require a future verified Stripe Connect transfer/webhook workflow. |

**Referee workflow gate:** Run only with synthetic fixtures, synthetic referees and isolated test accounts. Do not enable live notification dispatch, create live Connect accounts, initiate real transfers or treat a pending_connect obligation as a completed payment.

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

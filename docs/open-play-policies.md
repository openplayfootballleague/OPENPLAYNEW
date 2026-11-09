# Open Play New — Product, player and data policies

**Status:** Approved product decisions and proposed operational/privacy controls  
**Applies to:** Open Play New, all locations and seasons  
**Policy owner / proposed data controller:** Open Play (unregistered trading name operated by an individual; the individual's full legal name remains to be confirmed before publication)  
**Last updated:** 8 November 2026

This document records the product and operational decisions confirmed for Phase 1. It is an implementation specification, not a substitute for a legally reviewed privacy notice, safeguarding policy or terms of participation. Items marked proposed must be reviewed before public launch.

## 1. Account access and player eligibility

Account access and player registration are separate states. Creating or holding an app account does not by itself make someone a registered player, team member or captain.

| Age | App access | Player registration | Consent |
|---|---|---|---|
| Under 16 | Basic-view access only | Not eligible | No player-registration consent flow applies |
| 16–17 | Basic view; player features only after approval | Eligible | Verified parent/legal-guardian consent is mandatory |
| 18+ | Eligible for normal player journey | Eligible | No parental consent required |

### Basic view (under 16)
- Basic view is **account-based**, not anonymous-only. An under-16 may create an Open Play viewer account without creating a player identity.
- The permitted experience is public Home, Match Centre and Teams/Leagues information: fixtures, results and league tables. The Join Open Play route may explain eligibility, but must not allow a team join request, team application or player registration.
- The More page may expose public destinations and account controls only. It must not expose Player Hub, Captain Hub, Admin Dashboard or Finance Workspace links to a basic-view account; direct access to protected routes must also be denied.
- Under-16 users cannot register as players, join a team as a player, become a captain, or use player-only actions. Player registration starts at age 16.
- Basic view must not expose private player/team information. These restrictions must be enforced by server-side authorization and data access policies, not merely by hiding interface controls.

### Player registration (16+)
- Date of birth is mandatory in player registration and eligibility is calculated using the date of birth, not a self-selected age.
- Anyone under 16 must be blocked from player registration by both client and server/database enforcement.
- Players aged 16 or 17 must complete the parental/legal-guardian consent process before registration approval or participation.
- Consent is not optional and cannot be bypassed by an administrator through ordinary approval flows.
- Capture the parent/legal guardian's name and email address, send a verification/consent link to that address, and require successful verification before player approval.
- Record consent status, timestamp, verification evidence/reference and withdrawal status in an access-controlled audit trail. Verification links expire after 7 days; the single-use withdrawal link expires after 2 years and is rejected once the player turns 18. Collect no more information than is necessary.
- Pending or withdrawn consent means the player cannot participate in registered-player activities until resolved.
- At age 18, parental consent is no longer required for future participation; retain only the minimum consent evidence required by the approved retention schedule.
- The privacy and safeguarding information must explain the processing of children's data and the limits of basic-view access.

## 2. Player identity matching and phone numbers
- A registration is flagged for identity review when at least two of these three metrics match the same candidate player: full name, phone number and email address.
- Matches against different candidate players must not be combined to reach the threshold.
- Phone numbers must be normalised to canonical E.164 form for storage and matching.
- Accept UK national format, +44 and 0044 as equivalent; support international numbers with country-aware parsing and a UK default.
- Preserve a user-friendly input that accepts spaces, brackets and country prefixes; validate and normalise on the server.
- Add regression coverage for equivalent formats and concurrent registration attempts.

## 3. Public profile pictures
- Profile-picture upload is optional.
- If a player uploads a picture, it is intentionally visible to other app users in accordance with the product's public-profile design.
- If no picture is uploaded, show the standard Open Play avatar.
- Only the picture owner and authorised administrators may change or remove it.
- Explain the public visibility clearly before upload; do not imply that an uploaded picture is private.

## 4. Bans, active participation and reinstatement
- A ban makes a player inactive for active-player counts and removes them from active player-facing lists and participation.
- Banning revokes player registration/participation privileges and removes active team membership while preserving legitimate historical records, results and statistics.
- Historical membership and competition records must not be deleted merely to hide a banned player from current activity. Use a historical/left state and timestamps where appropriate.
- A banned player must not retain captain privileges or regain access through a stale session, direct URL, API call or active-membership edge case.
- If the banned player is captain, automatically transfer captaincy for each affected active team to the eligible teammate with the most appearances in the **current season**.
- If eligible teammates are tied, choose alphabetically by **full registered name** using a deterministic, documented collation.
- Record the ban, membership changes, successor selection and notifications in an auditable transaction.
- If there is no eligible successor, leave the team without a captain and alert an administrator for manual appointment.
- An administrator may review the automatic appointment and manually appoint another eligible teammate.
- Unbanning does **not** restore prior registration, team membership or captaincy. The person must complete fresh player registration and the normal approval process.
- Preserve historical competition records subject to the approved retention schedule and applicable data-protection rights.

## 5. Data controller and privacy
- **Open Play** is the responsible organisation/trading name for the service. It is currently unregistered; the data controller is the individual operating Open Play, whose full legal name must be confirmed and included before the public notice is published.
- The confirmed privacy contact email is **openplayfootballleague@gmail.com**. No postal or business address is currently held; do not invent one. Confirm whether an address or alternative service address is legally required before publication.
- The privacy notice must explain how people can exercise their rights and must not be published until the individual data controller's legal identity and appropriate contact details have been verified.
- The notice must describe actual data categories, purposes, lawful bases, recipients/processors, international transfers (if any), retention, rights, complaints route and any relevant automated decisions.
- Select and document a lawful basis separately for each processing purpose. Do not use consent as a blanket basis for all account and league processing.
- Public profile-picture visibility, parental-consent records, identity-review evidence and disciplinary/ban information require clear purpose and access explanations.
- Minimise collection, restrict administrative access, log privileged actions and apply appropriate security controls.
- Open Play has an existing PostHog EU Cloud project, but the current application branch has no PostHog SDK dependency/initialisation or analytics-consent UI. The app integration is therefore still outstanding: before sending new events, implement explicit consent, identify users with Supabase Auth UUIDs and reset identity on logout, use privacy-safe event properties, and route trusted server-side events through the approved capture path. Keep session replay/autocapture disabled until the required controls are in place. Preserve the existing 749 historical analytics events and let them expire under PostHog's configured retention policy; do not manually delete them.
- The final privacy notice and children's-data approach require review against current UK data-protection requirements before launch.

## 6. Retention schedule — proposed, not final

The following is a working proposal for review, not a promise of fixed or indefinite retention:

| Record category | Proposed approach |
|---|---|
| Account/contact details | Current implementation: after 12 months without successful sign-in, close only if there is no active/pending team membership, unresolved payment, pending transfer, administrator assignment or legal/safeguarding hold; retain in a restricted archive for 12 months, then erase account-linked data subject to lawful exceptions |
| Player registration details | Follow the same inactivity and 12-month restricted-archive lifecycle; verified reactivation restores the same player account without restoring membership or captaincy |
| Match appearances, results and league statistics | Preserve the required competition history under a random account-independent identity; treat it as pseudonymised personal data unless a documented identifiability assessment establishes that it is genuinely anonymous |
| Ban and disciplinary records | Retain only while needed for league integrity, safety, dispute handling or legal claims; review periodically |
| Parent/guardian consent evidence | Keep while required to demonstrate valid consent and manage participation; review when the player turns 18 and under the final schedule |
| Financial/accounting records | Apply a separate statutory/accounting schedule; detach direct account/customer links where legally permitted |
| Security and technical logs | Use a shorter documented period based on security and operational need |

- No category is automatically retained for ten years simply because that is a convenient round number.
- Define a retention owner, review cadence, deletion/anonymisation process and legal-hold exception.
- The proposed 90/30/7-day advance-warning emails are not yet implemented. The retention workflow is manual-only; do not enable unattended closure until the notices, delivery round-trip and release approval are complete.
- Historical sports records and identifiable personal information must be treated separately.
- The schedule and lawful bases must be reviewed by a UK data-protection professional before publication.

## 7. Administration and audit
- The intended first administrator account is openplayfootballleague@gmail.com; the account must be created and email-verified through the normal signup flow before controlled first-super-admin bootstrap.
- Never request or store the administrator's password or one-time verification code in project documentation or support conversations.
- Ban decisions, captain transfers, registration approvals, consent verification/withdrawal and privileged changes must be auditable.
- No live Bideford location, league or season data is to be seeded during testing. Bideford is to be added manually after publication, as directed by the owner.

## 8. Release and verification requirements
These policies are not complete merely because they are documented. Before release:
- implement and test server-side age, consent, role and ban enforcement;
- test under-16 basic-view restrictions and direct API/URL access;
- test 16–17 consent verification, pending/withdrawn states and 18th-birthday transition;
- test ban/unban, current-season appearance succession and full-name tie-break;
- test identity matching and phone canonicalisation;
- verify privacy notices, retention jobs and audit trails;
- complete browser, mobile and iPad acceptance testing.

Do not apply hosted database changes, merge the pull request or deploy the app solely on the basis of this policy-document update.

### Official UK ICO guidance used for this review
- [Right to be informed](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/individual-rights/right-to-be-informed/): privacy information must identify the organisation and explain purposes, lawful bases, recipients, retention and individual rights.
- [Pseudonymisation](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-sharing/anonymisation/pseudonymisation/): pseudonymised data remains personal data under UK GDPR.
- [Storage limitation](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-protection-principles/a-guide-to-the-data-protection-principles/storage-limitation/): retention periods must be justified, documented and reviewed; the law does not prescribe one universal period.


## Player transfers and matchday team sheets

- A player must leave their current club themselves before requesting a transfer. Ordinary voluntary departures do not require old-captain or administrator approval; a current captain must appoint a replacement first.
- A pending transfer leaves the player unattached and unavailable to either club. Outside the emergency window, only one destination request may be pending in the same league.
- In the final 24 hours before a scheduled kickoff, an unattached player may send simultaneous requests to all eligible clubs in that league that have not submitted their team sheet for a fixture in that window.
- A team-sheet draft may be edited and saved before kickoff. Only explicit captain confirmation submits and locks the sheet; a saved draft does not remove the club from emergency-transfer eligibility.
- The first destination captain to approve secures the player. The database automatically cancels competing pending requests and rejects later approvals, including simultaneous attempts.
- One active club per player per league is enforced across seasons. Memberships in different leagues remain independent. Historic appearances, statistics and club attribution are never moved or reset by a transfer.

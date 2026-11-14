# Join Open Play, League Discovery and Player Screens — Detailed UX Specification

**Reference baseline:** owner-supplied screenshots uploaded 13 November 2026. See [visual-reference-catalogue.md](./visual-reference-catalogue.md) for the complete image-to-screen mapping.

This document translates the visual references into implementation requirements. It is deliberately explicit so that contributors do not rely on visual guesswork.

## 1. Public Join Open Play route

### Purpose and audience
Entry point for signed-out visitors who want to play, create a team or discover competitions. The page must explain that every new member starts with a player account.

### Layout order
1. Signed-out global header.
2. Hero panel with eyebrow, headline, supporting copy, Register Now primary CTA and player-account-first helper text.
3. “How would you like to get involved?” section heading.
4. Player pathway card.
5. Team-creation pathway card with prerequisite badge.
6. League-discovery pathway card.
7. Existing-user sign-in prompt.
8. Public/viewer bottom navigation, following the current viewer navigation specification.

### Behaviour
- Register Now and Start Player Registration route to the same canonical player-registration entry point.
- Create Team must not bypass player registration. If the visitor is signed out, begin registration; after player registration, continue to team application.
- Explore Our Leagues opens the competition directory without requiring authentication unless a specific action requires an account.
- Existing users are directed to sign in, with a safe return path to the intended destination.
- Preserve the intended destination through authentication without accepting arbitrary external redirect URLs.

## 2. Player registration completion / next action

### Purpose
Help a newly registered player decide what to do next without implying they have joined a team.

### Required states
- Registration complete, no team: show Find a Team, Create a Team, Upcoming Leagues and My Applications.
- Registration complete, already attached to a team: show contextually appropriate team/player hub route and current membership status; do not continue presenting “no team” messaging.
- Pending team application: clearly distinguish pending review from approved membership.
- Rejected/withdrawn application: show the status and permitted next action without creating duplicate applications.
- No upcoming leagues: show a genuine empty state rather than invented competitions.

### Action semantics
- Find a Team: browse eligible active competitions and request membership in a team.
- Create a Team: start a team application; captain authority is only granted after approval.
- Upcoming Leagues: view configured future competitions and submit interest where enabled.
- My Applications: show the player's own team applications, join/transfer requests and league-interest records, with status, submitted date and next permitted action.

## 3. Competition directory

### Data required per competition card
- Competition/location display name.
- Location label/region where configured.
- Format (e.g. 6-a-side).
- Venue.
- Division and season where applicable.
- Canonical competition/season lifecycle status.
- Recruitment/interest availability controlled by administration.
- A permitted destination action.

### Status rules
- Active means the competition is currently configured as running/active. It does not automatically mean recruitment is open.
- Upcoming/Planned means the competition is configured for a future launch. It does not mean registration is guaranteed open.
- Recruitment-open/closed is a separate administrative control and must be represented independently where needed.
- Never infer a competition's state from a hard-coded location list or current date alone.

### Sorting and grouping
- Separate active and upcoming sections.
- Within each section, use a stable admin-defined order or a documented deterministic order.
- Avoid duplicate competition cards where several seasons or divisions share one location; represent the hierarchy clearly.

## 4. Team directory

### Required data
- Team name and approved badge/monogram.
- Current registered player count.
- Team's competition/location context.
- Team registration status and visibility eligibility.

### Behaviour
- Only teams that are eligible for public discovery appear.
- A pending/unapproved team application must not be shown as a registered team.
- Player counts include current approved memberships only.
- Team detail opens a public team profile with only fields approved for public visibility.
- A join request must be authenticated, validated against eligibility and duplicate/pending requests, and recorded as pending until captain action.
- Team membership is not created merely because a request was submitted.

## 5. Inbox

### Information architecture
- All is a combined, chronological activity view.
- Messages contains person-to-person/captain messages permitted by the messaging policy.
- Notifications contains automated league-system alerts and official announcements.
- A notification must not be represented as a private direct message.
- An admin announcement is official system communication; do not create a general admin-to-player DM channel.

### Card fields
- Sender/event title.
- Message or notification type.
- Context/category label.
- Preview text.
- Timestamp in the recipient's local display format.
- Unread/new indicator.
- Optional avatar or category icon.

### Security and lifecycle
- Fetch only records the authenticated user is authorised to read.
- Mark-read operations must be authorised and persisted.
- Unread counts must be computed from recipient-scoped records.
- Empty, loading, error and pagination states must be designed.
- Avoid exposing message contents in analytics events or logs.

## 6. Player profile

### Profile header
- Profile picture with a clear Change Profile Picture control.
- Player name.
- Team and role.
- Account/player status.

### Personal information
- Full name.
- Date of birth.
- Email.
- Mobile number.

All are read-only in the player profile screen. Profile picture is the only editable profile field in this workflow. Any exceptional correction process should be an explicitly separate support/admin workflow with audit controls, not an inline edit.

### Football information
- Current team.
- Competition.
- Player status.

Display the canonical membership status, not a locally inferred label.

### Account settings destinations
- Change Password.
- Notification Preferences.
- Privacy and Permissions.
- Terms and Conditions.
- Log Out.

Each row must have a real route/action, loading/error feedback and keyboard/touch accessibility. Do not ship decorative controls that do nothing.

## 7. League table

### Data and calculation
- Rows are generated from published results for the selected competition/season.
- Position, played, won, drawn, lost, goal difference and points must reconcile with the underlying results and configured scoring rules.
- Team highlight is based on the authenticated player's current approved team membership in that competition.
- “Your Team Position” must use the same computed standings dataset as the table.
- Points gap is displayed only when it has an unambiguous meaningful value.

### Tie handling
Do not introduce automatic goal-difference or head-to-head tie-breakers as a ranking rule. The established competition rule is that a tie for first place is resolved by a final. Display tied positions consistently until the final is completed and its result is published.

### Responsive behaviour
- Keep team names and essential standings legible.
- Use compact spacing and sensible column sizing.
- If a horizontally scrollable table is necessary, constrain scrolling to the table region and preserve visible context; never create page-level horizontal overflow.
- Provide accessible table headers and a non-colour-only indication of the user's team.

## 8. Shared header and navigation

- Reuse a consistent global header component with signed-out and signed-in variants.
- Use the original OP logo asset.
- Location selector must use the user's selected location and only offer configured locations.
- Notification icon must expose an accessible name and unread state where applicable.
- Account control must route to the correct account/profile area.

### Navigation conflict resolution
- The authoritative rule is the navigation table in `product-master-specification.md` (owner specification 2026-11-14).
- Visitor and every signed-in player state: Home (the Player Hub for approved players), Match Centre, Teams, Join Open Play, More.
- Registration screens: Home, Match Centre, Join Open Play, More, with Join highlighted.
- Captain navigation extends the registered-player experience with captain-only Club and Matchday destinations as defined by the captain workflow; do not expose captain functions to ordinary players.
- A screenshot showing five items or Join Open Play in the permanent registered-player nav is not authoritative for that account state.
- The post-registration next-action screen may be a transitional onboarding route and must not redefine persistent navigation.

## 9. Visual quality checklist

- [ ] Near-black page background and charcoal card surfaces.
- [ ] Orange Open Play brand/action accent used consistently.
- [ ] Correct Oswald/Inter typography roles.
- [ ] Correct logo asset; no recreated text-logo substitute.
- [ ] Clear hierarchy between page title, section heading, card title and helper text.
- [ ] Status pills use consistent semantic colours and wording.
- [ ] Primary, secondary and tertiary actions are visually distinct.
- [ ] Cards have consistent radius, padding, borders and vertical rhythm.
- [ ] Mobile controls meet accessible touch-target expectations.
- [ ] Keyboard focus is visible and logical.
- [ ] Screen-reader labels exist for icon-only controls.
- [ ] No page-level horizontal overflow.
- [ ] Loading, empty, error, disabled and success states are specified.
- [ ] Sample data from screenshots is not hard-coded.
- [ ] Permissions and server-side access checks match the workflow.
- [ ] Navigation follows the current account state, not an outdated screenshot.

## 10. Implementation evidence expected

A screen is not complete merely because its route renders. For each screen, implementation evidence should identify:
- The route/component and the exact commit SHA reviewed.
- The data source and server-side permission boundary.
- The primary and secondary actions and their resulting state transitions.
- Loading, empty, error and success states.
- Responsive screenshots at supported breakpoints.
- Relevant automated tests and any remaining known gaps.



## 11. Player Hub — My Results

**Visual reference:** `IMG_0573.jpeg`.

### Layout and content
- Signed-in global header with OP branding, selected location and account control.
- Context eyebrow “Player Hub / My Results”, prominent “Your Results.” heading and team, division and season context.
- Completed Matches section with result count.
- Each result card displays gameweek, local match date, home and away team names, explicit home/away labels, score, pitch, the player's team's outcome (Win/Draw/Loss) and a result-detail affordance.
- Pagination displays the current range and total (for example, 1–4 of 10) with disabled Previous/Next states at boundaries.
- Navigation follows the five-tab rule in `product-master-specification.md`.

### Behaviour and data
- Results are scoped to the player's current or selected historical team membership and relevant competition/season; define the historical-membership rule consistently with the team-history model.
- Only published results appear as completed matches. Unpublished or disputed results must not be presented as final.
- Outcome is calculated from the selected player's team's perspective, not from home/away position alone.
- Clicking a result opens a match detail view with published score and permitted match events/statistics. Do not expose private referee/admin notes.
- Sort newest gameweek/date first by default. Pagination must be stable and not duplicate/skip records when new results are published.
- Empty state, loading, API error and no-more-pages states are required.

## 12. Player Hub — My Fixtures

**Visual reference:** `IMG_0572.jpeg`.

### Layout and content
- Same signed-in header and Player Hub page hierarchy as My Results.
- “Your Fixtures.” heading with team, division and season context.
- Upcoming Fixtures section and total count.
- Each card displays gameweek, date, home and away team names with explicit home/away labels, central “VS”, kick-off time, pitch and fixture-detail affordance.
- Pagination with range/total and correct disabled states.

### Behaviour and data
- Show fixtures belonging to the player's approved team membership and selected competition/season, including fixtures through the end of the season where required by the Player Hub specification.
- Exclude cancelled fixtures from the ordinary upcoming list or clearly label them in a dedicated cancelled state; postponed fixtures must show their current confirmed date/time only when set.
- Display local competition time and venue/pitch from canonical fixture data. Never hard-code sample Fridays, times or pitches.
- Fixture detail opens the permitted match preview, including opponent, venue, time and available team-sheet/status information. Do not expose another team's private submitted lineup before its authorised publication point.
- Sort chronologically ascending by kick-off. Pagination must be stable.
- Include loading, empty, error, postponed, cancelled and rescheduled states.

## 13. Team registration wizard — four steps

**Visual references:** `IMG_0568(2).jpeg`, `IMG_0569(2).jpeg`, `IMG_0570(2).jpeg`, `IMG_0571(2).jpeg`.

### Shared wizard behaviour
- Four ordered steps with clear progress indicator and step count (01/04 through 04/04).
- Preserve entered values when navigating Back/Continue or when the session is interrupted; protect drafts and enforce ownership.
- Validate fields on the server as well as client. Show field-level errors and retain valid entries after an error.
- Do not create a registered team or grant captain permissions on draft creation or submission. Submission creates a pending team application; approval is the event that provisions the team/captain role under the approved workflow.
- Prevent duplicate submissions with idempotency and a clear submitted/pending state.
- The screenshot shows a four-step flow after player registration. Signed-out users must first complete player registration; do not expose a bypass.

### Step 1 — Build your team
Fields shown:
- Team name — required; validate length, allowed characters and uniqueness within the relevant competition/location scope. Handle near-duplicates and reserved names through clear errors/review.
- Preferred kit colour — required; explain that final arrangements are subject to confirmation to avoid clashes.
- Team Instagram URL — optional; validate as a URL and store only if supplied.
- Team logo/crest — optional upload; screenshot lists PNG, JPG or SVG. Apply file-size limits, content/signature validation, malware scanning where available, SVG sanitisation (or rasterise safely), storage access controls and moderation before public display. The user may skip and upload later.
- New to Open Play / Returning to Open Play — required single-choice field.

### Step 2 — Who's leading?
Fields shown:
- Captain's full name — required.
- Captain's mobile number — required; validate and normalise using a UK-aware international phone-number library, while allowing supported international numbers where the competition policy permits.
- Captain's WhatsApp contact number — required in this screenshot, with explicit instruction to enter “No WhatsApp” if not used or repeat the mobile number if the same. Store the distinction safely; do not interpret a supplied number as marketing consent.
- Ensure the applicant/captain identity is consistent with the already registered player account. Where the form captures the same information as the authenticated profile, define whether it is a confirmation snapshot or the canonical profile value; do not create contradictory identities.

### Step 3 — Anything else?
- Optional free-text additional details/support request/team information.
- Explicit instruction not to include sensitive player information.
- Enforce a sensible maximum length, strip/escape unsafe content, and provide a privacy notice. Do not use this field as a place to collect health data or special-category information.

### Step 4 — Final check
Five separately presented required declarations are shown:
1. Authority to register the team and act as captain or nominated representative.
2. Accuracy of supplied information and obligation to notify Open Play of changes.
3. Payment requirements — screenshot wording says captain ensures each fixture is paid in full at least 24 hours before kick-off and collects player contributions where necessary.
4. Minimum player age — screenshot says all players will be aged 16 or over when participating.
5. Agreement to applicable league rules.

Each acknowledgement must be independently checked before submit. Store the exact declaration text/version, applicant, timestamp and application reference for audit. The review notice must say submission is reviewed by administration and does not guarantee approval.

**Owner confirmation gates:** declarations 3 and 4 are not automatically approved policy simply because they appear in a visual. Confirm the 24-hour payment rule and age-16 eligibility against the current approved financial, competition, safeguarding and insurance policies before enabling them. If not confirmed, revise the wording with the owner rather than silently changing policy.

## 14. Player registration — post-submission next action

**Visual reference:** `IMG_0567(2).jpeg`.

After player registration has been successfully submitted, present three clear choices:
1. Create a Club — start team registration and apply to enter an Open Play competition.
2. Join a Club — browse eligible existing clubs/teams and request to join their squad.
3. Continue as an Individual — enter Player Hub and join a team later.

The state must be explicit: player registration submitted is not the same as team membership, team approval or captain approval. The selected action must preserve the user's authenticated session and route to the correct workflow without duplicating their player account.

## 15. Player registration — discovery and marketing preferences

**Visual reference:** `IMG_0566(2).jpeg`.

- Ask “How did you find us?” with a single-choice source list: Facebook, Instagram, Word of mouth, Team captain, Other.
- Provide optional additional detail. Keep this field optional and do not require it for registration.
- Marketing preferences are separate from essential registration. Email marketing and SMS marketing are independent optional opt-ins, unticked by default.
- Record consent evidence per channel: affirmative action, timestamp, wording/policy version, source and relevant contact point. A single combined marketing checkbox is insufficient.
- Withdrawing one channel's consent must not withdraw or silently change the other channel. Essential service communications must be classified separately from marketing.
- Do not make marketing consent a condition of registration or access to the league.

## 16. Player registration — fitness and declarations

**Visual reference:** `IMG_0565(2).jpeg`.

- Fitness self-declaration asks whether the applicant considers themselves fit to participate, with Yes, No and Unsure options. This is health-related data and requires explicit privacy/legal review, a documented lawful basis and strict access/retention controls. Do not send this answer to PostHog or general analytics. Do not imply it is medical clearance.
- Required declarations are separately acknowledged: accuracy of information; minimum age (16+ as pictured); league rules agreement; injury risk acknowledgement; photography and filming notice.
- Each declaration opens the actual current policy/notice text, not a dead-end decorative row. Require acknowledgement of the correct version and record version/timestamp.
- Photography/filming acknowledgement is not marketing consent. Confirm the legal and safeguarding approach, including alternatives/objection handling, before treating it as a blanket release.
- The minimum age statement must be confirmed against the applicable competition and safeguarding policy before enforcement; age rules may be competition-specific.
- The form must explain what happens if the applicant selects No or Unsure for fitness. Do not automatically diagnose, reject or clear the player; route to a defined human review/support path approved by the owner.

## 17. Player registration — emergency contact

**Visual reference:** `IMG_0564(2).jpeg`.

Required fields shown:
- Emergency contact full name.
- Relationship to player.
- Contact telephone number.

Explain why the information is collected and that it is restricted to authorised personnel. The emergency contact is a third party, so provide appropriate transparency information and minimise the data collected. Define who can access it (for example, authorised event/safeguarding personnel only), when it may be used, retention/deletion rules, and how the player updates it. Do not expose it to team captains by default, in player profiles, team lists, exports or analytics. Apply strict server-side access controls and audit access where appropriate.

## 18. Registration data protection and security acceptance gates

- [ ] Separate essential service communications from optional marketing.
- [ ] Email and SMS marketing consent independently recorded and revocable.
- [ ] Fitness declaration treated as sensitive health-related data; access and analytics restrictions enforced.
- [ ] Emergency contact treated as third-party personal data with restricted access and retention policy.
- [ ] Photography/filming notice separate from marketing consent and approved by owner.
- [ ] Age threshold confirmed for each competition before validation is enabled.
- [ ] Payment declaration reconciled with the approved Stripe/payment policy before it is shown as binding.
- [ ] Team crest upload validates file type, size and content server-side; SVG is sanitised or disallowed.
- [ ] Draft wizard progress is private to the applicant and cannot grant team/captain privileges.
- [ ] Declaration text/version and timestamp retained for audit.
- [ ] No sensitive registration answers or emergency contact data sent to PostHog.
- [ ] Access controls verified with negative tests for player, captain, referee and admin roles.

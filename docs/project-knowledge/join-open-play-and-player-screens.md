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
- Viewer/public navigation: Home, Match Centre, Teams, Join Open Play, More, as specified for the viewer state.
- Registered player navigation: Player Hub replaces Home; Match Centre, Teams, More. Exactly four tabs.
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


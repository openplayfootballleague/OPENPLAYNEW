# Open Play — Owner-Supplied Visual Reference Catalogue

**Reference sets:** 10 initial screenshots plus 10 additional screenshots uploaded by the owner on 13 November 2026 (20 source images total).  
**Status:** authoritative visual reference set for the screens represented below, subject to the conflict rules in this document. All owner references supplied on 2026-11-14 (32 images: IMG_0522–IMG_0583, including the player registration steps IMG_0563–IMG_0567) are stored at full resolution in `docs/reference-assets/visual-references/`, with an index and a current-implementation comparison in its README. The filenames below are the original upload names; the stored copies add a descriptive suffix.

## Source files and screen mapping

| Source file | Screen / component | Reference scope |
|---|---|---|
| `IMG_0581.jpeg` | Join Open Play — public / signed out | Public entry page, hero CTA, player-first registration explanation, create-team prerequisite, league discovery |
| `IMG_0582.jpeg` | Join Open Play — registered player | Post-registration next-step screen; find team, create team, upcoming leagues, applications |
| `IMG_0583.jpeg` | Find your league — signed-in | Active and upcoming league directory; location, format, venue, status and team-discovery action |
| `IMG_0580.jpeg` | League teams — Bideford | Registered team directory, team initials, registered-player counts and View Team action |
| `IMG_0579.jpeg` | Find your league — Player Hub route | Active/upcoming competition cards and team-discovery actions; alternate layout reference |
| `IMG_0576.jpeg` | Inbox | Combined activity feed with All / Messages / Notifications filters, unread indicators, sender/type, preview and time |
| `IMG_0575.jpeg` | Player profile | Profile image editing, read-only personal details, football information, account settings and logout |
| `IMG_0577.jpeg` | Signed-in global header | OP wordmark, notification control, account/avatar and location selector |
| `IMG_0578.jpeg` | Signed-out global header | OP wordmark, notification control, Sign In CTA and location selector |
| `IMG_0574.jpeg` | League table | Standings, current-team highlight, competition context and team-position summary |

## Visual authority and conflicts

1. These screenshots are the owner's newly supplied references for the represented screens. Use them ahead of older Library concepts when implementing those screens.
2. These are visual references, not permission to copy illustrative data. Names such as Alex Morgan, Hale Rovers, 6 Offenders, sample scores, dates, counts and standings are placeholder examples unless independently confirmed by the live product data.
3. Navigation follows the five-tab rule in `product-master-specification.md` (owner specification
   2026-11-14). Screenshots that show four tabs for visitors or players, or a Captain's Hub tab, are
   superseded on navigation only.
4. The screenshot labelled “Join Open Play — Registered player” is a post-registration onboarding/next-action page. Its five-item bar matches the standard five-tab navigation.
5. The product/workflow specification remains authoritative for business rules, permissions, privacy, account states and data. A visual mockup must not override those rules.
6. Preserve the demonstrated dark interface, orange OP accent, typography hierarchy, card treatments, spacing, rounded corners, restrained status colours, iconography and header patterns. Use the approved Oswald heading / Inter body type system where the screenshot rendering or font fallback is ambiguous.
7. Do not redraw or approximate the official OP logo. Use the original approved logo asset.
8. Treat status colours as semantic: green for active/success, blue for upcoming/planned, orange for Open Play actions and emphasis, neutral greys for surfaces and secondary information.
9. Use responsive layouts that preserve the information hierarchy. Do not simply scale a desktop composition down; cards, tables and headers must adapt without horizontal overflow.

## Screen-by-screen implementation notes

### Public Join Open Play — `IMG_0581.jpeg`
- Signed-out global header: OP branding at left; notification affordance, Sign In and current location at right.
- Main hero is a dark elevated panel with a small orange eyebrow, large two-line headline, short explanatory copy, prominent full-width orange Register Now CTA and a short player-account-first note.
- Follow with “How would you like to get involved?” and three distinct pathways:
  - I want to play — start player registration.
  - I want to create a team — explain that player registration is required first; route to player registration rather than bypassing it.
  - Explore our leagues — browse active competitions and upcoming league launches.
- Include sign-in prompt for existing users.
- The primary CTA and player pathway must lead into Phase 1 player registration. A team application cannot create a captain role before the required player registration and team approval flow.

### Registered player — Join Open Play next action — `IMG_0582.jpeg`
- Signed-in header with notification, account/avatar and location selector.
- Show a clear registration-complete success state.
- Heading and short copy explain that the player account is ready and ask how they want to participate.
- Primary filled orange card/action: Find a Team; describe browsing active leagues, registered teams and requesting to join.
- Secondary outlined orange action: Create a Team; explain captain status is granted only once approved.
- Additional cards: Upcoming Leagues (register interest) and My Applications (track transfer requests, team applications and league-interest registrations).
- Keep this page useful for a player who has completed player registration but has not joined a team. Do not assume registration means team membership.
- The image's five-item bar matches the standard five-tab navigation.

### Find Your League — `IMG_0583.jpeg` and `IMG_0579.jpeg`
- Competition discovery is divided into Active Leagues and Upcoming Leagues, each with a short explanatory subheading.
- Each competition card communicates location, competition name, format, venue, division/season or recruitment state, and a clear action.
- Use semantic status pills: Active (green), Upcoming/Planned (blue).
- Active competition action should lead to registered teams / team discovery. Upcoming competitions should lead to league details and/or expression-of-interest workflow according to configured availability.
- Only display league availability and recruitment status controlled by administration; do not infer availability from a venue or season date.
- Avoid duplicating the same competition across sections. A competition's status and actions must be derived from the canonical competition/season configuration.

### League Teams — `IMG_0580.jpeg`
- Context breadcrumb/eyebrow identifies Find a Team and the selected location.
- Heading “League Teams.” followed by location, format and venue.
- Registered Teams heading and total count.
- Each team row/card shows a team monogram or approved team badge, team name, registered Open Play team descriptor, registered-player count and View Team action.
- Entire card may be navigable, with a distinct View Team affordance. Ensure accessible focus and a single unambiguous target.
- Counts must reflect current registered team membership, not pending requests or historic team-sheet participants.
- Do not hard-code the eight sample team names or counts from the mockup.

### Inbox — `IMG_0576.jpeg`
- Page title “Your Inbox.” and explanatory sentence.
- Three filter states: All, Messages, Notifications. These are distinct content types, not interchangeable labels.
- Recent Activity heading and unread count.
- Activity rows/cards include sender or event title, message/notification category, optional audience/context label, unread/new state, preview and timestamp.
- Notifications are automated league alerts and official announcements. Messages are player-to-player/captain communications under the approved messaging permissions.
- Admins should use official automated notifications rather than unrestricted direct messages.
- Read/unread state and unread counts must be persisted and scoped to the authenticated recipient.
- Never leak another user's message, notification or read state through client-side filtering alone; enforce access server-side/RLS.

### Player Profile — `IMG_0575.jpeg`
- Profile summary panel: avatar/profile picture, Change Profile Picture action, player name, current team/role and player-status pill.
- Personal Information fields: full name, date of birth, email and mobile number. These are read-only in the player self-service profile; show lock/read-only affordances consistently.
- Football Information: current team, competition and player status.
- Account Settings links: Change Password, Notification Preferences, Privacy and Permissions, Terms and Conditions.
- Logout is a distinct bottom action.
- The player may edit only their profile picture through this screen. Do not make name, DOB, email, phone or football membership fields editable here.
- Use the actual authenticated profile and membership data; screenshot values are illustrative. Handle missing profile image with a neutral default avatar.

### Global headers — `IMG_0577.jpeg` and `IMG_0578.jpeg`
- Shared header frame with rounded dark surface and subtle border.
- Left: official orange OP mark and white OPEN PLAY wordmark.
- Right-side controls are account-state dependent:
  - Signed out: notification affordance, prominent Sign In action and location selector.
  - Signed in: notification affordance, account/avatar control and location selector.
- Location selector displays the selected location and opens a location-switching control only for configured locations.
- Maintain adequate touch targets, keyboard focus, accessible labels and responsive collapse behaviour.
- Never infer account state from a client-side display flag; derive it from the authenticated session and server-authorised profile.

### League Table — `IMG_0574.jpeg`
- Context label Player Hub / League Table; large “The Table.” heading and competition/season context.
- League Standings section with live/current status where appropriate.
- Table columns shown: position/team, played, won, drawn, lost, goal difference and points.
- Highlight the signed-in player's current team and label it “Your Team.”
- Beneath the table, include a “Your Team Position” summary with position, points, team name and points gap to the leader where meaningful.
- Preserve mobile readability; use a responsive table strategy rather than forcing page-wide horizontal overflow.
- Standings must be calculated from published results and configured points rules. Do not introduce goal difference or head-to-head as an automatic tiebreaker unless the owner explicitly changes the competition rules. The established rule for a tie at first place is a final.
- Sample rows and statistics are placeholders, never seed data.

## Shared visual system extracted from this set

- Base: near-black page/background; dark charcoal raised panels; subtle mid-grey borders/dividers.
- Primary accent: Open Play orange for branding, primary actions, selected navigation and interactive emphasis.
- Text: white for headings and primary values; mid-grey for supporting copy; muted grey for secondary labels.
- Status: green for signed-in/complete/active; blue for upcoming/planned; orange for unread/new/action emphasis.
- Components: rounded bordered outer shell; rounded charcoal cards; pill status indicators; generous vertical spacing; clear section headings; strong uppercase display headings; thin separators.
- Actions: filled orange for the primary action; orange outline for secondary action; orange text links for tertiary actions.
- Icons: simple consistent outline icons; orange for actionable/context icons, neutral grey for inactive navigation.
- Layout: strong single-column mobile-first flow; header and bottom navigation remain visually distinct from scrollable content; avoid cramped card content.

## Relationship to other project documents

See:
- `design-system.md` for tokens, typography, responsive behaviour and accessibility.
- `product-master-specification.md` for account states and global navigation.
- `accounts-roles-and-workflows.md` for registration, membership, messaging and profile permissions.
- `competition-and-match-operations.md` for team directories, league tables and standings logic.



## Additional owner-supplied references — 13 November 2026

These ten further screenshots extend the reference set to 20 images. They are the authoritative visual references for the additional screens/workflows below, subject to product-rule and privacy conflict checks.

| Source file | Screen / component | Reference scope |
|---|---|---|
| `IMG_0573.jpeg` | Player Hub — My Results | Completed match list, gameweek/date, home/away layout, score, pitch, W/D/L outcome, result detail affordance and pagination |
| `IMG_0572.jpeg` | Player Hub — My Fixtures | Upcoming match list, gameweek/date, home/away layout, kick-off, pitch, fixture detail affordance and pagination |
| `IMG_0571(2).jpeg` | Team registration — step 4 of 4 | Final declarations, five mandatory acknowledgements, application review notice and submit action |
| `IMG_0570(2).jpeg` | Team registration — step 3 of 4 | Optional additional information, privacy warning and continue action |
| `IMG_0569(2).jpeg` | Team registration — step 2 of 4 | Captain name, mobile and WhatsApp contact details |
| `IMG_0568(2).jpeg` | Team registration — step 1 of 4 | Team identity, kit colour, optional Instagram, optional crest upload and new/returning status |
| `IMG_0567(2).jpeg` | Player registration — post-submission choice | Create a club, join a club or continue as an individual |
| `IMG_0566(2).jpeg` | Player registration — discovery and marketing preferences | How the player found Open Play, optional detail and separate email/SMS marketing opt-ins |
| `IMG_0565(2).jpeg` | Player registration — declarations | Fitness self-declaration and required declarations covering accuracy, age, rules, injury risk and photography/filming |
| `IMG_0564(2).jpeg` | Player registration — emergency contact | Required emergency contact name, relationship and telephone; restricted-access privacy notice |

## Additional screen-specific authority notes

- Results and fixtures are Player Hub screens. Their sample team names, scores, dates, times and pitches are illustrative only. They must be generated from the selected player's approved team membership and the canonical fixture/result records.
- The team registration flow is a four-step wizard. Persist progress safely, validate each step, prevent duplicate submissions, and show a review/confirmation state after successful submission. A step number/progress bar must reflect actual validated progress, not merely the current URL.
- The team registration screenshot says payment for each fixture must be made in full at least 24 hours before kick-off and the captain is responsible for collecting player contributions. Treat this as a proposed declaration requiring owner/legal/operational confirmation against the current payment policy; do not implement a new financial obligation solely from screenshot text.
- The screenshots state a minimum player age of 16. This is a material eligibility rule and must be checked against the current approved competition rules, safeguarding policy, insurance and legal requirements before implementation. Do not silently assume it applies to every location/competition.
- Fitness-to-participate is health-related information. Minimise collection and retention, restrict access, avoid sending it to analytics, and obtain appropriate owner/legal review of the wording and handling. The UI must not imply that a self-declaration is medical clearance.
- Emergency contact details are personal data about another person. Explain purpose, restrict access to authorised personnel, use a documented retention period, and never expose them in public player profiles, team directories, routine exports or analytics.
- Photography/filming notice acknowledgement is distinct from optional marketing consent. Email and SMS marketing opt-ins must be separate, optional, unticked by default, and recorded with timestamp, wording/version and channel. Refusal must not block essential registration.
- WhatsApp contact number is not automatically consent to receive WhatsApp marketing or messages. Explain its operational purpose and apply the messaging/consent policy.
- Optional Instagram URL and team crest upload require validation, safe file handling and moderation/visibility controls. Accept only supported file types and enforce size limits server-side.
- Preserve the four-tab registered-player navigation rule and other account-state navigation decisions even where these registration screens show a transitional Join Open Play tab.

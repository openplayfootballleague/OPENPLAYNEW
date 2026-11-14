# Open Play visual references (owner-supplied, authoritative)

These are the owner's original screenshots, stored at full resolution so ChatGPT and Claude can both
refer to the same images. They are the **authoritative design references** for the screens they show
(owner instruction, 2026-11-14). Do not redesign or reinterpret them without owner approval.

- The names, scores, dates, e-mail addresses and counts in the images are illustrative placeholders.
  They are not product data, and they must not be copied into production flows (AGENTS.md: no mock data).
- The `OP` mark in the images stands in for the official logo. Use the supplied official asset only
  (owner decision D5, issue #18).
- Behaviour, permissions, account states and data rules come from the specifications linked below.
  Where an image and a written specification disagree, the conflict is recorded under
  [Conflicts](#conflicts-needing-owner-confirmation). It is not silently resolved.

## Index

This directory holds 32 owner-supplied images, received in two uploads on 2026-11-14:

- `IMG_0568`–`IMG_0583` (first upload);
- `IMG_0522`–`IMG_0567` (second upload). This includes `IMG_0563`–`IMG_0567`, the player registration
  steps that were previously missing.

**Photography and likeness:** several images contain third-party photographs whose source credits are
visible: uk.linkedin, leisureleagues, ru.sputnik, gelderlander, artificialturfpitchreplacement.co.
IMG_0522 shows a real person's portrait.

- These show where imagery goes and how it is treated. They are **not** cleared assets.
- Production must use owner-licensed photography (design-system "Imagery") and users' own uploaded
  avatars.

### Public and onboarding

| Image | Screen | Account state | Specification |
| --- | --- | --- | --- |
| [IMG_0562](IMG_0562-home-public-signed-out.jpeg) | Home — "More than just a game", four steps | Visitor | PUB-01 |
| [IMG_0561](IMG_0561-home-signed-in-earlier-build.png) | Home — tile layout (screenshot of an earlier Workers preview build) | Signed in | PUB-01 (see conflict 5) |
| [IMG_0581](IMG_0581-join-open-play-public-signed-out.jpeg) | Join Open Play — public | Visitor | PUB-06 |
| [IMG_0563](IMG_0563-player-registration-step-1-personal-information.jpeg) | Player registration 01 — Personal information and preferred position | Signed in, registering | REG-01, REG-02 |
| [IMG_0564](IMG_0564-player-registration-step-2-emergency-contact.jpeg) | Player registration 02 — Emergency contact | Signed in, registering | REG-03 |
| [IMG_0565](IMG_0565-player-registration-step-3-declarations.jpeg) | Player registration 03 — Fitness and five declarations | Signed in, registering | REG-04 |
| [IMG_0566](IMG_0566-player-registration-step-4-how-did-you-find-us.jpeg) | Player registration 04 — Discovery source, notes, separate email/SMS marketing consent | Signed in, registering | REG-05 |
| [IMG_0567](IMG_0567-player-registration-submitted-next-step.jpeg) | Registration submitted — Create a club / Join a club / Continue as individual | Signed in, registration submitted | REG-06 |
| [IMG_0582](IMG_0582-join-open-play-registered-player-next-move.jpeg) | Join Open Play — "Your next move" | Approved player, no team | REG-06 |
| [IMG_0583](IMG_0583-find-your-league-signed-in-no-team.jpeg) | Find your league (Join route) | Approved player, no team | PUB-04 |
| [IMG_0568](IMG_0568-team-registration-step-1-build-your-team.jpeg) | Team registration 1/4 — Build your team | Approved player, no team | REG-07, REG-08 |
| [IMG_0569](IMG_0569-team-registration-step-2-whos-leading.jpeg) | Team registration 2/4 — Who's leading? | Approved player, no team | REG-07 |
| [IMG_0570](IMG_0570-team-registration-step-3-anything-else.jpeg) | Team registration 3/4 — Anything else? | Approved player, no team | REG-07 |
| [IMG_0571](IMG_0571-team-registration-step-4-final-check.jpeg) | Team registration 4/4 — Final check (5 declarations) | Approved player, no team | REG-07 |
| [IMG_0577](IMG_0577-global-header-signed-in.jpeg) | Global header — signed in | Signed in | PUB-08 |
| [IMG_0578](IMG_0578-global-header-signed-out.jpeg) | Global header — signed out | Visitor | PUB-08 |

### League, teams and Match Centre

| Image | Screen | Account state | Specification |
| --- | --- | --- | --- |
| [IMG_0532](IMG_0532-match-centre-hub.jpeg) | Match Centre hub — hero, Fixtures/Results/Team stats/Player stats tiles, table preview | Player in a team | MC-01..04 |
| [IMG_0533](IMG_0533-teams-all-teams-in-league.jpeg) | Teams — search, initials, squad size, played, points | Player in a team | PUB-05 |
| [IMG_0535](IMG_0535-team-profile.jpeg) | Team profile — position/points/played, team navigation, upcoming fixture, latest result | Player in a team | PUB-05 |
| [IMG_0536](IMG_0536-team-squad.jpeg) | Team squad — searchable squad, optional numbers, captain flag, club leaders | Player in a team | PUB-05, STAT |
| [IMG_0540](IMG_0540-team-fixtures.jpeg) | Team fixtures — paginated, Current Gameweek action | Player in a team | PUB-05 |
| [IMG_0538](IMG_0538-team-results.jpeg) | Team results — season record and match history | Player in a team | PUB-05 |
| [IMG_0579](IMG_0579-find-your-league-player-hub.jpeg) | Find your league (Player Hub route) | Player in a team | PUB-04 |
| [IMG_0580](IMG_0580-league-teams-bideford.jpeg) | League teams — Bideford | Player in a team | PUB-05 |

### Player Hub and captain

| Image | Screen | Account state | Specification |
| --- | --- | --- | --- |
| [IMG_0522](IMG_0522-player-hub-home.jpeg) | Player Hub home — welcome, season stats, six tiles, next match | Player in a team | PH-01 |
| [IMG_0542](IMG_0542-player-profile-career-statistics.jpeg) | Player profile — this season, career statistics, career history | Player in a team | PH-07, STAT |
| [IMG_0572](IMG_0572-player-hub-my-fixtures.jpeg) | My Fixtures | Player in a team | PH-02 |
| [IMG_0573](IMG_0573-player-hub-my-results.jpeg) | My Results | Player in a team | PH-03 |
| [IMG_0574](IMG_0574-player-hub-league-table.jpeg) | League table | Player in a team | PH-04, D7 |
| [IMG_0575](IMG_0575-player-profile.jpeg) | Player profile (account) | Player in a team | PH-07 |
| [IMG_0576](IMG_0576-inbox.jpeg) | Inbox | Player in a team | NOT-01, D4 |
| [IMG_0543](IMG_0543-captains-hub.jpeg) | Captain's Hub — next fixture, team sheet, transfer requests, MOTM, club finances | Captain | CAP-01..04, FIN-02, D6 |

## Bottom navigation shown in the references

This is the evidence for the rule in
[product-master-specification](../../project-knowledge/product-master-specification.md#navigation-and-account-states).
It is implemented in `src/lib/navigation/account-navigation.ts`.

| Account state | Tabs shown | Images |
| --- | --- | --- |
| Visitor (signed out) | Home, Match Centre, Join Open Play, More (4) | IMG_0562, IMG_0581 |
| Signed in, player registration not yet approved | Home, Match Centre, Join Open Play, More (4) | IMG_0563–IMG_0567 |
| Approved player, no team (transitional) | Home, Match Centre, Teams, Join Open Play, More (5) | IMG_0582, IMG_0583 |
| Player in a team | Home, Match Centre, Teams, More (4) | IMG_0522, IMG_0532–IMG_0542, IMG_0572–IMG_0580 |
| Captain | Home, Match Centre, Teams, Captain's Hub, More (5) | IMG_0543 |
| Team registration wizard | Home, Match Centre, Join Open Play, More (4; title case, alternative icons) | IMG_0568–IMG_0571 |

## Comparison with the current application (2026-11-14)

**Method:** the local dev server was run at a 390 × 844 viewport, with a test-only session and stand-in
API responses, in three states: signed out, signed in without a team, and in a team. Screenshots and
assertions came from a Playwright script. No hosted data was used, so data-driven content shows empty
states. Status uses the audit scale: Missing / Partial / Implemented.

| Image | Current implementation | Status | Differences |
| --- | --- | --- | --- |
| IMG_0581 Join (public) | `src/components/public-join-landing.tsx` via `src/routes/join.tsx` | Implemented (2026-11-14) | Hero, Register Now, the three pathways and the sign-in prompt match the reference. Matches the reference, including the global header. |
| IMG_0582 Your next move | `src/routes/join.tsx` (signed-in branch) | Partial | Shows "Find your place to play" with a recruitment notice. Missing: the registration-complete badge, the Find a Team / Create a Team / Upcoming Leagues / My Applications cards, and a light callout that breaks the dark theme. |
| IMG_0583 / IMG_0579 Find your league | `src/routes/leagues.tsx` | Partial | The data model has locations, leagues and seasons. Missing: the Active and Upcoming sections with green and blue status pills, and the per-card View Teams / View League Details actions. The heading is "Find your competition." in mixed case. |
| IMG_0580 League teams | `src/routes/teams.tsx` | Partial | The team directory exists. Missing: initials tiles, registered-player counts and per-location scoping ("Find a team / Bideford"). |
| IMG_0577 / IMG_0578 Global header | `src/components/global-header.tsx` | Implemented (2026-11-14) | Bell with unread count, Sign In or avatar with orange ring, location selector. Below 400 px the "OPEN PLAY" text is hidden to avoid overlap. The marketing Home keeps its own header until the PUB-01 redesign. |
| IMG_0572 My Fixtures | `src/routes/player_.fixtures.tsx`, `src/components/player-matches.tsx` | Implemented | Matches the layout, with pagination. Verified with stand-in data (my-fixtures screenshot, 2026-11-13). |
| IMG_0573 My Results | `src/routes/player_.results.tsx` | Implemented | Win/Draw/Loss pills and pagination present. |
| IMG_0574 League table | `src/routes/match-centre.tsx`, `src/lib/competition/standings.ts` | Partial | The standings logic is implemented. Missing: the Player Hub table page with the Your Team highlight and the position summary. The image shows a GD column, which owner decision D7 (points only) overrides on data. A GD column may only be displayed if the owner confirms it. |
| IMG_0575 Profile | `src/components/player-profile.tsx` | Implemented | Layout matches. Terms and conditions is shown as pending until legal text is published (PUB-10). |
| IMG_0576 Inbox | `src/routes/inbox.tsx` | Implemented | All / Messages / Notifications filters and unread states present. |
| IMG_0568–IMG_0571 Team registration | `src/routes/join.tsx` (single form) | Partial | A team application exists as a single form. Missing: the four-step wizard, drafts, kit colour, Instagram and crest (REG-08; PR #122 not integrated), WhatsApp, "anything else", and the five versioned declarations. |

| IMG_0563–IMG_0566 Player registration | `src/routes/register-player.tsx` (single form) | Partial | A single form captures name, DOB and phone, with the age rules. Missing: the 5-segment progress wizard; the first/last name, email, home town and preferred position fields (step 01); emergency contact (step 02); fitness and the five declarations, including injury risk and photography (step 03); and discovery source, notes and separate email/SMS marketing consent (step 04). Declarations need versioned server-side storage. |
| IMG_0567 Registration submitted | — | Missing | No post-submit choice screen. See conflict 6. |
| IMG_0522 Player Hub home | `src/routes/player.tsx` | Partial | The hub exists. Missing: the "Welcome back" header with season pill and avatar, the appearances/goals/assists strip, the six-tile grid, and the Next Match card. |
| IMG_0542 Profile with career statistics | `src/components/player-profile.tsx` | Partial | Account details only. Missing: the this-season stats, career statistics and career history sections. Statistics data exists server-side (`get_admin_season_statistics`, player statistics RPCs). |
| IMG_0543 Captain's Hub | `src/routes/captain.tsx`, `captain-motm-nominations.tsx`, `captain-team-payments.tsx` | Partial | Team sheet, MOTM and payments exist. Missing: the next-fixture header, the transfer requests card with pending count, and the club finances summary layout. The **Pay** button must stay disabled under D6 until the owner approves online payments. |
| IMG_0562 / IMG_0561 Home | `src/routes/index.tsx` | Partial | The current Home uses cream sections and a different hero. Missing: the dark layout, the four-steps section and the tile grid (PUB-01). |
| IMG_0532 Match Centre hub | `src/routes/match-centre.tsx` | Partial | Tables, fixtures, results and leaders exist on one page. Missing: the hero, the four tiles and the table preview with a "View full league table" link. |
| IMG_0533 / IMG_0535 / IMG_0536 / IMG_0540 / IMG_0538 Teams | `src/routes/teams.tsx`, `src/routes/teams.$teamId.tsx` | Partial | The directory and profile exist. Missing: search, initials tiles, squad counts, points, team navigation, squad list with club leaders, and paginated team fixtures and results with a season record. |

**Cross-cutting differences:**
- **Navigation:** fixed after this comparison (commit "feat(nav): account-state bottom navigation").
  - Visitors now see 4 tabs.
  - Signed-in accounts that are not yet approved players see 4 tabs.
  - Approved players without a team see 5 tabs on one row.
  - Players in a team see 4 tabs, with Home leading to the Player Hub.
  - Captains see 5 tabs, including Captain's Hub (IMG_0543).
- **Headings:** they use mixed case with an orange second line. The references use white uppercase headings ending with a full stop.
- **Surfaces:** some public surfaces (the Home sections and the join callout) use cream or light backgrounds. The references are charcoal throughout.

## Conflicts needing owner confirmation

1. **Wizard bottom bar.** The bar in IMG_0568–IMG_0571 uses different icons and title-case labels from
   the other images. The canonical icon set and labels are used unless the owner says otherwise.
2. **GD column.** IMG_0574 shows GD and IMG_0532 says "goal difference". Decision D7 forbids GD as a
   tie-breaker. Confirm whether goal difference may be displayed for information only.
3. **Captain payments (IMG_0543).** The image shows "Pay £70.00, powered by Stripe". Under D6 no new
   online card payment goes live without owner approval, so the button stays gated.
4. **Photography.** Third-party credited photos and a real person's portrait appear in the mockups.
   Licensed imagery is needed.
5. **Home (IMG_0561 vs IMG_0562).** IMG_0561 is a screenshot of an earlier deployed build (tile
   layout). IMG_0562 shows a different signed-out Home. Confirm whether IMG_0561 is the intended
   signed-in Home or only a record of the earlier build.
6. **Two post-registration screens.**
   - IMG_0567 appears straight after submitting player registration, offering Create a club / Join a
     club / Continue as individual.
   - IMG_0582 is the "Your next move" page for an approved player.
   - Proposed: IMG_0567 is shown on submission. Joining or creating a club stays blocked by the
     server until the registration is approved.
7. **Resolved by these images:**
   - Captain navigation (IMG_0543).
   - The navigation for accounts that are not yet approved players (IMG_0563–IMG_0567).

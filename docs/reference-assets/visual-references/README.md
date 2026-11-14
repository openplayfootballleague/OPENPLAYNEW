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

The original set is 20 images, `IMG_0564`–`IMG_0583`. This directory holds the 16 the owner supplied on
2026-11-14.

**Still missing:** `IMG_0564`–`IMG_0567` (player registration steps: emergency contact,
fitness/declarations, discovery/marketing consent, post-registration choice). The owner needs to upload
them so they can be stored here.

| Image | Screen | Account state | Specification |
| --- | --- | --- | --- |
| [IMG_0568](IMG_0568-team-registration-step-1-build-your-team.jpeg) | Team registration 1/4 — Build your team | Registered player, no team | [join-open-play-and-player-screens](../../project-knowledge/join-open-play-and-player-screens.md), REG-07, REG-08 |
| [IMG_0569](IMG_0569-team-registration-step-2-whos-leading.jpeg) | Team registration 2/4 — Who's leading? | Registered player, no team | same, REG-07 |
| [IMG_0570](IMG_0570-team-registration-step-3-anything-else.jpeg) | Team registration 3/4 — Anything else? | Registered player, no team | same, REG-07 |
| [IMG_0571](IMG_0571-team-registration-step-4-final-check.jpeg) | Team registration 4/4 — Final check (5 declarations) | Registered player, no team | same, REG-07; [accounts-roles-and-workflows](../../project-knowledge/accounts-roles-and-workflows.md) |
| [IMG_0572](IMG_0572-player-hub-my-fixtures.jpeg) | Player Hub — My Fixtures | Player in a team | [join-open-play-and-player-screens](../../project-knowledge/join-open-play-and-player-screens.md), PH-02 |
| [IMG_0573](IMG_0573-player-hub-my-results.jpeg) | Player Hub — My Results | Player in a team | same, PH-03 |
| [IMG_0574](IMG_0574-player-hub-league-table.jpeg) | Player Hub — League table | Player in a team | same, PH-04; owner decision D7 |
| [IMG_0575](IMG_0575-player-profile.jpeg) | Player profile | Player in a team | same, PH-07 |
| [IMG_0576](IMG_0576-inbox.jpeg) | Inbox (All / Messages / Notifications) | Player in a team | owner decision D4, NOT-01 |
| [IMG_0577](IMG_0577-global-header-signed-in.jpeg) | Global header — signed in | Any signed-in user | [design-system](../../project-knowledge/design-system.md), PUB-08 |
| [IMG_0578](IMG_0578-global-header-signed-out.jpeg) | Global header — signed out | Visitor | same, PUB-08 |
| [IMG_0579](IMG_0579-find-your-league-player-hub.jpeg) | Find your league (Player Hub route) | Player in a team | [visual-reference-catalogue](../../project-knowledge/visual-reference-catalogue.md), PUB-04 |
| [IMG_0580](IMG_0580-league-teams-bideford.jpeg) | League teams — Bideford | Player in a team | same, PUB-05 |
| [IMG_0581](IMG_0581-join-open-play-public-signed-out.jpeg) | Join Open Play — public | Visitor (signed out) | same, PUB-06 |
| [IMG_0582](IMG_0582-join-open-play-registered-player-next-move.jpeg) | Join Open Play — "Your next move" | Registered player, no team | same, REG-06 |
| [IMG_0583](IMG_0583-find-your-league-signed-in-no-team.jpeg) | Find your league (Join route) | Signed in, no team | same, PUB-04 |

## Bottom navigation shown in the references

The images show the bottom navigation by account state. This is the evidence used for the navigation
rule in [product-master-specification](../../project-knowledge/product-master-specification.md#navigation-and-account-states).

| Account state | Tabs shown | Images |
| --- | --- | --- |
| Visitor (signed out) | Home, Match Centre, Join Open Play, More (4) | IMG_0581 |
| Signed in, no team (transitional onboarding) | Home, Match Centre, Teams, Join Open Play, More (5) | IMG_0582, IMG_0583 |
| Player in a team | Home, Match Centre, Teams, More (4) | IMG_0572–IMG_0576, IMG_0579, IMG_0580 |
| Team registration wizard | Home, Match Centre, Join Open Play, More (4, title case, calendar/people icons) | IMG_0568–IMG_0571 |
| Captain | not shown | — |

## Comparison with the current application (2026-11-14)

**Method:** the local dev server was run at a 390 × 844 viewport, with a test-only session and stand-in
API responses, in three states: signed out, signed in without a team, and in a team. Screenshots and
assertions came from a Playwright script. No hosted data was used, so data-driven content shows empty
states. Status uses the audit scale: Missing / Partial / Implemented.

| Image | Current implementation | Status | Differences |
| --- | --- | --- | --- |
| IMG_0581 Join (public) | `src/routes/join.tsx` | **Missing** | Signed-out visitors are redirected to "Sign in to continue". The hero, the Register Now button and the three pathways are absent. |
| IMG_0582 Your next move | `src/routes/join.tsx` (signed-in branch) | Partial | Shows "Find your place to play" with a recruitment notice. Missing: the registration-complete badge, the Find a Team / Create a Team / Upcoming Leagues / My Applications cards, and a light callout that breaks the dark theme. |
| IMG_0583 / IMG_0579 Find your league | `src/routes/leagues.tsx` | Partial | The data model has locations, leagues and seasons. Missing: the Active and Upcoming sections with green and blue status pills, and the per-card View Teams / View League Details actions. The heading is "Find your competition." in mixed case. |
| IMG_0580 League teams | `src/routes/teams.tsx` | Partial | The team directory exists. Missing: initials tiles, registered-player counts and per-location scoping ("Find a team / Bideford"). |
| IMG_0577 / IMG_0578 Global header | `src/routes/__root.tsx` | Partial | Player pages show only the logo. Missing: the bell with unread state, the avatar with an orange ring, Sign In, and the location selector. Home uses an older marketing header. |
| IMG_0572 My Fixtures | `src/routes/player_.fixtures.tsx`, `src/components/player-matches.tsx` | Implemented | Matches the layout, with pagination. Verified with stand-in data (my-fixtures screenshot, 2026-11-13). |
| IMG_0573 My Results | `src/routes/player_.results.tsx` | Implemented | Win/Draw/Loss pills and pagination present. |
| IMG_0574 League table | `src/routes/match-centre.tsx`, `src/lib/competition/standings.ts` | Partial | The standings logic is implemented. Missing: the Player Hub table page with the Your Team highlight and the position summary. The image shows a GD column, which owner decision D7 (points only) overrides on data. A GD column may only be displayed if the owner confirms it. |
| IMG_0575 Profile | `src/components/player-profile.tsx` | Implemented | Layout matches. Terms and conditions is shown as pending until legal text is published (PUB-10). |
| IMG_0576 Inbox | `src/routes/inbox.tsx` | Implemented | All / Messages / Notifications filters and unread states present. |
| IMG_0568–IMG_0571 Team registration | `src/routes/join.tsx` (single form) | Partial | A team application exists as a single form. Missing: the four-step wizard, drafts, kit colour, Instagram and crest (REG-08; PR #122 not integrated), WhatsApp, "anything else", and the five versioned declarations. |

**Cross-cutting differences:**
- **Visitor navigation:** the visitor sees 5 tabs, which wrap onto a second row at 390 px. IMG_0581 shows 4.
- **Signed-in, no team:** the navigation shows 4 tabs, while IMG_0582 and IMG_0583 show 5.
- **Headings:** they use mixed case with an orange second line. The references use white uppercase headings ending with a full stop.
- **Surfaces:** some public surfaces (the Home sections and the join callout) use cream or light backgrounds. The references are charcoal throughout.

## Conflicts needing owner confirmation

1. **Navigation for a signed-in user without a team.**
   - IMG_0582 and IMG_0583 show 5 tabs, including Join Open Play.
   - The catalogue treats IMG_0582 as transitional onboarding, not persistent navigation.
   - Recorded rule: the 5-tab bar applies only while the account has no active team. Once the player is
     in a team, the 4-tab persistent navigation applies.
2. **Wizard bottom bar.** The bar in IMG_0568–IMG_0571 uses different icons and title-case labels from
   the other images. The canonical icon set and labels are used unless the owner says otherwise.
3. **GD column (IMG_0574).** Decision D7 forbids GD as a tie-breaker. Confirm whether goal difference
   may still be displayed for information only.
4. **Captain navigation.** None of the images show it. The current captain bar (Player Hub, Club,
   Matchday, More) drops Match Centre and Teams. The specification says the captain bar *extends* the
   player experience, so the owner needs to confirm the layout.

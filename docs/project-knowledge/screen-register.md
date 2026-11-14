# Open Play — screen, navigation and interaction register

**Status:** working reference for the owner's *Complete Screen-by-Screen Product, Navigation & Interaction
Specification* (2026-11-14), checked against the code on `claude/open-play-master-blueprint-rhtuih`.

- **Images:** the 32 reference images are in `docs/reference-assets/visual-references/`.
- **Requirement tracker:** `completion-register.md`.
- **Audit evidence:** `docs/audit/repository-audit-2026-11-14.md`.

**Status scale** (from the specification). Nothing is marked done without evidence.

| Code | Meaning |
| --- | --- |
| **IV** | Implemented and verified (automated test or recorded browser check) |
| **IU** | Implemented, not verified |
| **P** | Partially implemented |
| **N** | Not implemented |
| **B** | Blocked by an external dependency |

"Verified" here means a local automated check. No hosted environment and no owner acceptance testing
exist yet.

---

## 1. Decisions applied from the specification

| Topic | Specification | Previous rule | Applied |
| --- | --- | --- | --- |
| Visitor navigation | Home, Match Centre, Teams, Join Open Play, More | 4 tabs, from IMG_0581 | **5 tabs.** The screenshot is superseded (spec §17: screenshots do not override explicit requirements). |
| Registered player navigation | Home/Player Hub, Match Centre, Teams, Join Open Play, More. Join is never removed. | Join removed once in a team | **5 tabs in every account state.** |
| Registration screens | Simplified Home, Match Centre, Join Open Play, More, with Join highlighted | — | **4 tabs** on `/sign-up`, `/register-player` and future `/join/team*` |
| Captain | Club and Matchday without a second bar or a changed five-tab bar | Captain's Hub tab (IMG_0543) | **5 player tabs.** Captain Hub (Club and Matchday sections) is reached from Player Hub and More. |
| Header logo | Returns to the appropriate Home/Player Hub | Always `/` | **Approved players go to `/player`, everyone else to `/`.** |

Code: `src/lib/navigation/account-navigation.ts`, unit-tested in `account-navigation.test.ts`.

## 2. Screenshot-to-page mapping (all 32 images)

"Visibility" is who should see the screen. Status is the current implementation of that screen.

| Ref | Page / state | Visibility | Purpose | Interactive elements → destination / action | Related | Status |
| --- | --- | --- | --- | --- | --- | --- |
| IMG_0562 | Public Home | Everyone (signed-out variant) | Introduce Open Play | Location selector → change competition context; Sign In → `/sign-in`; Join Open Play → `/join`; Explore the league → `/match-centre`; bottom nav | Join, Match Centre | P: `/` has a hero but cream sections, no four-steps block, no published competition data (PUB-01) |
| IMG_0561 | Home, tile layout (earlier deployed build) | Signed in | Hub of public areas | Tiles → Match Centre, Find your league (`/leagues`), Join (`/join`), Player Hub (`/player`), Captain Hub (`/captain`, captains only), More; Get started → `/join` | Home | P: owner to confirm whether this is the intended signed-in Home |
| IMG_0581 | Join Open Play — public | Visitor | Choose how to take part | Register Now → `/sign-up`; Start player registration (×2) → `/sign-up`; View leagues → `/leagues`; Sign in → `/sign-in` | Registration, leagues | IV (Playwright 2026-11-14) |
| IMG_0563 | Player registration 01 — personal information | Signed-in account, registering | Collect identity | First/last name, mobile, email, DOB, home town, preferred position (4 options); Continue → step 02 | 0564 | P: `/register-player` is a single form; position, home town and the wizard are missing |
| IMG_0564 | Player registration 02 — emergency contact | Registering | Emergency contact (private) | Name, relationship, telephone; Continue → step 03 | 0565 | N |
| IMG_0565 | Player registration 03 — declarations | Registering | Fitness and five declarations | Fitness radio (3); five declaration checkboxes, each opening its text (chevron); Continue → step 04 | 0566 | N: versioned declaration storage needed |
| IMG_0566 | Player registration 04 — how did you find us | Registering | Discovery source, notes, separate marketing consent | Source radio (5); notes; email and SMS marketing (optional, separate); Submit registration → server submit | 0567 | N |
| IMG_0567 | Registration submitted | Account with submitted registration | Next step | Team registration → team wizard; Find a club → `/teams`; Go to Player Hub → `/player` | 0582 | N (owner question: relationship to IMG_0582) |
| IMG_0582 | Your next move | Approved player without a team | Next step after approval | Find a team → `/leagues`; Start team registration → team wizard; Explore upcoming leagues → `/leagues`; View my applications → requests list | 0583, 0568 | P: `/join` signed-in workspace has join and register forms plus a request list |
| IMG_0583 | Find your league (Join route) | Signed in, no team | Active and upcoming competitions | View teams → league teams; status pills | 0580 | P: `/leagues` lists published locations, leagues and seasons without the Active/Upcoming layout |
| IMG_0579 | Find your league (Player Hub route) | Player | As above | View teams; View league details | 0580 | P |
| IMG_0580 | League teams — Bideford | Everyone | Teams in one league | Team row / View team → `/teams/$teamId` | Team page | P: `/teams` has no player counts or initials |
| IMG_0533 | Teams — all teams in your league | Everyone | Directory | Location pill; search; team row → team page | 0535 | P: no search, initials, played or points |
| IMG_0535 | Team profile | Everyone (public data) | Team hub | Squad, Fixtures, Results, Statistics → team sub-views; fixture → fixture detail; result → match report | 0536, 0540, 0538 | P: `/teams/$teamId` shows fixtures and results without the position strip or team navigation |
| IMG_0536 | Team squad | Signed in (squad names) | Squad and club leaders | Search; player → public profile; leader cards | Profile | N: no squad view; Club Leaders exists only in `/teams` (signed in) |
| IMG_0540 | Team fixtures | Everyone | Paginated upcoming fixtures | Previous/Next; fixture → detail; Current Gameweek → jump to the current gameweek | Fixture detail | N |
| IMG_0538 | Team results | Everyone | Season record and history | Result → match report | Match report | N |
| IMG_0532 | Match Centre hub | Everyone | Fixtures, results and stats entry | Fixtures, Results, Team stats, Player stats tiles; View full league table | Match Centre | P: `/match-centre` shows a single combined page |
| IMG_0574 | League table (Player Hub) | Player in a team | Table with Your Team | Row → team page | Team page | P: the table exists in Match Centre without the highlight or position summary |
| IMG_0522 | Player Hub home | Player | Personal landing | Location pill; avatar → profile; six tiles (My Fixtures `/player/fixtures`, My Results `/player/results`, League Table, My Team `/teams/$id`, My Profile `/player/profile`, Notifications `/inbox`); All fixtures → `/player/fixtures` | Player screens | P: `/player` exists without this layout, the stats strip or the Next Match card |
| IMG_0572 | My Fixtures | Player in a team | Upcoming fixtures, 4 per page | Previous/Next; fixture → detail | 0573 | P: list and paging are verified (unit tests, Playwright); the fixture-detail destination is missing |
| IMG_0573 | My Results | Player in a team | Completed results, 4 per page | Previous/Next; result → match report | Match report | P: verified list; the match-report destination is missing |
| IMG_0575 | Player profile (account) | The player only | Read-only details; avatar is the only edit | Change profile picture → upload; Change password → `/reset-password`; Notification preferences → `/player#notification-preferences`; Privacy → `/privacy-security`; Terms (pending legal text); Log out | — | IV (Playwright; Terms is B on legal text) |
| IMG_0542 | Player profile — career statistics | Public profile view | Season and career statistics | Club rows → team page | Team page | N: no public player profile route; statistics data exists server-side |
| IMG_0576 | Inbox | Signed in | Messages and notifications | All / Messages / Notifications tabs; item → relevant page; mark read | — | IV (unit tests and Playwright) |
| IMG_0543 | Captain's Hub | Approved captain | Matchday and club control | Manage team sheet; Manage requests (2 pending); Submit MOTM nomination; View finance history; Pay (gated by D6) | `/captain` | P: team sheet, MOTM and payments exist; layout, transfer-request card and finance summary are missing |
| IMG_0568 | Team registration 1/4 — Build your team | Approved player | Team identity | Name, kit colour, Instagram, crest upload, new/returning; Continue | 0569 | P: single team form in `/join` (name and colours only) |
| IMG_0569 | Team registration 2/4 — Who's leading? | Approved player | Captain contact | Name, mobile, WhatsApp; Continue | 0570 | N |
| IMG_0570 | Team registration 3/4 — Anything else? | Approved player | Notes | Free text; Continue | 0571 | N |
| IMG_0571 | Team registration 4/4 — Final check | Approved player | Five declarations, then submit | Checkboxes; Submit team application → server | Admin approval | N |
| IMG_0577 | Global header — signed in | Signed in | Brand, notifications, account, location | Logo → `/player` or `/`; bell → `/inbox`; avatar → `/player/profile`; location select | — | IV (unit tests; e2e at 6 widths) |
| IMG_0578 | Global header — signed out | Visitor | As above | Logo → `/`; bell → `/sign-in`; Sign In → `/sign-in`; location select | — | IV |

## 3. Page and route register

**Header:** "Global" means the root-mounted `GlobalHeader`. Admin, finance, referee and Home have their
own headers.

**Navigation key:**
- **5** — the five-tab bar.
- **4R** — the four-tab registration bar.

**States key:** L = loading, E = empty, Er = error, S = success.

| Page | Route | Access (server-enforced) | Header / nav | States | Status |
| --- | --- | --- | --- | --- | --- |
| Public Home | `/` | Everyone | Own hero header / 5 | L, Er (auth lookup recovers) | P |
| Match Centre | `/match-centre` | Everyone (Club Leaders signed in only) | Global / 5 | L, E, Er | P |
| Find your league | `/leagues` | Everyone | Global / 5 | L, E ("No locations published yet"), Er | P |
| Teams directory | `/teams` | Everyone; leaders signed in | Global / 5 | L, E, Er | P |
| Team page | `/teams/$teamId` | Everyone (published) | Global / 5 | L, Er (invalid link) | P |
| Join Open Play | `/join` | Everyone; workspace signed in | Global / 5 | L, Er, S (request sent) | IV signed-out page; P workspace |
| Sign in / Sign up / Reset password | `/sign-in`, `/sign-up`, `/reset-password` | Everyone | Global / 5, 4R on sign-up | L, Er, S | IU |
| Player registration | `/register-player` | Signed in (verified email) | Global / 4R | L, Er, S, pending, under-16 | P |
| Player Hub | `/player` | Signed in | Global / 5 | L, E (no profile), Er | P |
| My Fixtures / My Results | `/player/fixtures`, `/player/results` | Signed in | Global / 5 | L, E, Er | P (detail and report destinations missing) |
| Profile | `/player/profile` | Signed in (own row via RLS) | Global / 5 | L, Er, S (upload) | IV |
| Inbox | `/inbox` (`/messages` redirects) | Signed in | Global / 5 | L, E, Er | IV |
| Captain Hub (Club, Matchday) | `/captain` | Active captain (RPC checks) | Global / 5 | L, E ("No captain teams yet"), Er, S | P |
| More | `/more` | Everyone; protected links after server checks | Global / 5 | L | IU |
| Gallery | `/gallery` | Everyone (published) | Global / 5 | L, E, Er | IU |
| Privacy and permissions | `/privacy-security` | Everyone | Global / 5 | — | IU |
| Admin dashboard | `/admin` (+ `/admin/analytics`, `/admin/referees`, `/admin/guardian-consents`, `/admin/retention`, `/admin-messages`, `/admin-help`) | Platform/location admin roles (RPC and RLS) | Own admin layout | L, E, Er, S | P |
| Finance | `/finance` | Finance permission | Own | L, Er | IU |
| Referee portal | `/referee`, `/referee/matchday`, `/referee/report/$fixtureId` | Approved referee | Own referee nav | L, Er, S | IU (SQL tests cover the RPCs) |
| Fixture detail | — | — | — | — | **N** |
| Match report | — | — | — | — | **N** |
| Public player profile | — | — | — | — | **N** |
| Notifications page | `/inbox` (Notifications tab) | Signed in | Global / 5 | as Inbox | IV |

## 4. Account-permission matrix

✓ = allowed; — = not allowed; (s) = server-enforced by RLS or a `SECURITY DEFINER` check.

| Capability | Visitor | Account (not approved) | Player, no club | Pending request | Player in club | Captain | Admin (location) | Super-admin |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Public Home, Match Centre, Teams, Leagues, Gallery, Join | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Club Leaders (definer RPC) | — (s) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Player registration | — | ✓ | — (already) | — | — | — | — | — |
| Player Hub, My Fixtures/Results, Profile, Inbox | — | Limited (status) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Request to join a team (`request_team_membership`) | — | — (s) | ✓ (s) | — (duplicate blocked, s) | — (s) | — | — | — |
| Team application (`register_team`) | — | — (s) | ✓ (s) | ✓ | — (s) | — | — | — |
| Captain Hub: team sheets, approve requests, MOTM | — | — | — | — | — | ✓ own team (s) | — | — |
| Admin dashboard, location scoped | — | — | — | — | — | — | ✓ own locations (s) | ✓ |
| All locations, role management, audit | — | — | — | — | — | — | — | ✓ (s) |

Evidence: `authorization_scope_regression.sql`, `location_admin_role_scope.sql`,
`membership_approval_authorization_locks.sql`, `security_privilege_assertions.sql`, and RLS on 61 of 61
public tables.

**Gaps:**
- The pending-transfer state has no dedicated UI. Request statuses are listed in `/join`.
- SEND TRANSFER REQUEST is missing from team pages.

## 5. Navigation map

| Account state | Bottom bar | Home destination | Additional entry points |
| --- | --- | --- | --- |
| Visitor | Home, Match Centre, Teams, Join Open Play, More | `/` | Header Sign In; More → Sign in / Sign up |
| Signed-in account, not an approved player | Same 5 (4R on registration screens) | `/` | Join → registration; More |
| Player without a club | Same 5 | `/player` | Join workspace (request, apply); Leagues; request statuses |
| Player with a pending request | Same 5 | `/player` | Request status in `/join` (Player Hub card is N) |
| Player in a club | Same 5 | `/player` | My Fixtures, My Results, Profile, Inbox, team page |
| Captain | Same 5 | `/player` | Player Hub "Open Captains Hub" and More "Captain Hub" → `/captain` (Club `#captain-club`, Matchday `#captain-matchday`) |
| Administrator | Admin layout (no public bar) | `/admin` | More → Admin Dashboard after a server check; workspace nav with 15 anchors |
| Super-administrator | As admin plus global controls | `/admin` | Communications, audit history, role management |

**Admin sections against the specified 14:**
- **Present:** Dashboard, Locations & Competitions, Seasons, Team Approvals, Player Approvals, Teams &
  Squads, Players, Fixtures, Team Sheets, Results & Match Events, Finance, Analytics & Reports,
  Communications, Gallery, Settings & Feature Management.
- **Differences from the specification:**
  - Approvals is split into Team Approvals and Player Approvals.
  - "Statistics" is labelled "Analytics & Reports".
  - Feature Management is combined with Settings.
  - Communications is an extra section.
  - The sections are anchors on a single page, not a separate left sidebar.
- **Status:** P. The owner needs to confirm the 14-section mapping.

## 6. Interaction and destination register (implemented pages)

| Page | Element | Type | Action / destination | Permission |
| --- | --- | --- | --- | --- |
| Global header | Logo | Link | `/player` for approved players, otherwise `/` | — |
| Global header | Bell (with unread badge) | Link | `/inbox` when signed in, otherwise `/sign-in` | Count limited to own rows by RLS |
| Global header | Avatar | Link | `/player/profile` | Signed in |
| Global header | Sign In | Link | `/sign-in` | Visitor |
| Global header | Location select | Filter | Stores the location and notifies open pages (`open-play:location-change`); context reloads seasons | Published locations only |
| Bottom nav | 5 or 4R tabs | Links | See §5; active tab in orange with `aria-current` | — |
| Join (public) | Register Now, Start player registration | Links | `/sign-up` (then email verification, then `/register-player`) | — |
| Join (public) | View leagues | Link | `/leagues` | — |
| Join (workspace) | Join a team / Register a team | Tabs | Switch form | Approved player |
| Join (workspace) | Request to join | Button | `request_team_membership`; shows pending, captain approves | Approved player (s) |
| Join (workspace) | Submit team application | Button | `register_team`; admin approval required; no captain role until approved | Approved player (s) |
| My Fixtures / Results | Previous / Next | Pagination | 4 per page; disabled at the ends | — |
| Profile | Change profile picture | File input | JPEG/PNG/WebP up to 5 MB, uploaded to own folder | Own user (storage policy) |
| Profile | Log out | Button | `auth.signOut()`, then `/sign-in` | — |
| Inbox | All / Messages / Notifications | Tabs | Filter feed | Own rows |
| Captain Hub | Team sheet, MOTM, payments | Forms | Server RPCs check 6+3 / 7+4, eligibility and captaincy | Captain (s) |
| More | Player Hub, Captain Hub, Admin, Finance, Referee | Links | Shown after server checks | (s) |

**Not yet defined in code** (each needs a destination before it can ship):
- fixture → fixture detail;
- result → match report;
- player name → public profile;
- team table row → team page from the Player Hub table;
- SEND TRANSFER REQUEST on a team page.

## 7. Header and footer specification (implemented)

**Header** (`src/components/global-header.tsx`):
- Sticky, 64 px high, dark (`rgba(8,8,8,.97)`), with a subtle bottom border.
- Contents: logo with the "OPEN PLAY" wordmark (text hidden below 400 px), bell, Sign In or avatar, and
  the location select.
- Shown on every player-facing route.
- Not shown on admin, finance, referee or `/`, which have their own headers.
- Logo asset: `/open-play-logo.png`. The official asset is still outstanding (D5, issue #18).

**Footer** (`player-bottom-navigation.tsx`, `.player-bottom-nav`):
- Fixed to the bottom, safe-area padding, 68 px high, dark with a top divider.
- Equal columns (`grid-auto-flow: column`). Labels are 10 px with five tabs and 11 px with four.
- Active tab in orange with `aria-current="page"`.
- From 900 px wide it becomes a floating 540 px bar.
- Page content reserves bottom padding so the bar never covers form fields.
- Icons are inline SVG. **Lucide is required by the specification but is not a dependency yet (P).**

## 8. Responsive verification (2026-11-14)

**Automated:** `tests/e2e/public-device-acceptance.spec.ts`, run locally with Playwright 1.63 against
`vite preview`. **74/74 passed.**

| Widths | Routes | Assertions |
| --- | --- | --- |
| 320, 375, 390, 430 (phones); 820 (tablet); 1440 (desktop) | `/`, `/match-centre`, `/teams`, `/leagues`, `/join`, `/gallery`, `/more`, `/sign-in`, `/sign-up`, `/register-player`, `/reset-password`, `/privacy-security` | No document or body horizontal overflow; bottom nav on one row with no clipped labels and no off-screen items; header controls do not overlap; plus the PWA manifest and offline shell |

**Browser checks with a test-only session at 390 px and 320 px:**
- **Account states:** visitor, account, no team, in a team and captain.
- **Routes:** `/join`, `/leagues`, `/player`, `/player/profile`, `/captain`, `/register-player`.
- **Result:** no overflow, navigation on one row.

**Not yet covered:**
- Signed-in routes at every width, in CI.
- Admin at tablet width.
- Real devices (manual).

## 9. Outstanding functionality (from the specification)

1. **Player registration wizard** (5 stages: IMG_0563–IMG_0567).
   - Needs a forward migration for emergency contacts, versioned declarations with timestamps,
     discovery source and separate marketing consents.
   - Needs server validation and protection against duplicate submission.
2. **Team registration wizard** (4 stages: IMG_0568–IMG_0571).
   - Instagram and crest come from PR #122.
   - Needs declarations, including the weekly-fee acceptance, and a duplicate guard.
3. **SEND TRANSFER REQUEST on team pages** for eligible players without a club.
   - Pending, approved and declined states.
   - Status card on the Player Hub.
4. **Fixture detail and match report pages.**
   - Links from My Fixtures, My Results, the team pages and Match Centre.
5. **Public player profile with statistics.**
   - Appearances (including substitute appearances), goals, assists, goals per game (shown empty when
     there are no appearances), MOTM, goal contributions, career history.
   - A goalkeeper statistics variant.
6. **Player Hub redesign** (IMG_0522): states for no team, pending request and in a team.
7. **Captain Hub layout** (IMG_0543): next fixture, request management card, squad management.
   - Payments stay gated (D6).
8. **Match Centre hub and Teams directory/team sub-views** (IMG_0532–IMG_0540): search, counts, points.
9. **Home redesign** (IMG_0562/IMG_0561) with published competition data.
10. **Admin:** reconcile the 15 sections with the specified 14; left sidebar; global filters.
    - Integrate PR #110 (Needs Attention).
11. **Lucide icons:** adopt them across the navigation and cards.
12. **Shared components:** headings, cards, buttons, status pills and empty states. Several pages still
    use one-off markup, such as the very long lines in `admin.tsx` and `captain.tsx`.
13. **Blocked:**
    - official logo asset (D5);
    - legal terms (PUB-10);
    - Stripe/Connect and email/SMS provider set-up (D6, INF-03);
    - hosted migrations (INF-01);
    - GitHub write access (INF-01/INT-01);
    - licensed photography.

## 10. Test results (2026-11-14, local)

| Suite | Result |
| --- | --- |
| `npx tsc --noEmit` | pass |
| `npx vitest run` | 195/195 |
| `npm run build` | pass |
| Playwright e2e (`tests/e2e`, 6 widths) | 74/74 |
| Clean migration replay and SQL behavioural tests | 153 migrations, 41/41 |
| Security assertions; generated types; navigation, edge-function and migration verifiers | pass |
| End-to-end journeys (spec §16, 1–8) against a real Supabase project | **not run.** Needs a staging project with test accounts per role (INF-02). |

# Open Play — definitive page-by-page audit and implementation plan (Phase 1)

| | |
| --- | --- |
| **Date** | 2026-11-14 |
| **Commit audited** | `171d2af893cb43652d1d2295cfcbba825d4ff936` |
| **Branch** | `claude/open-play-master-blueprint-rhtuih` |
| **Working tree** | clean |
| **Scope** | Phase 1 of the owner's alignment assignment. This is the audit and the plan only; no structural changes were made. |
| **Published?** | Not yet: GitHub write access returns 403 for the Claude App, so this commit and its history are local only |

**Related documents:**
- `docs/audit/repository-audit-2026-11-14.md` (architecture, database and PR stack)
- `docs/project-knowledge/screen-register.md` (routes, interactions, permission matrix)
- `docs/project-knowledge/completion-register.md` (requirement tracker)

## 0. Reconciliation update (2026-11-14, workstream 1)

This audit, `screen-register.md` and `completion-register.md` now use one definition of complete. The
register also carries separate **Functional** and **Visual** columns.

| Row(s) | Change | Reason |
| --- | --- | --- |
| My Fixtures, My Results | Class 1 → 3 | Their fixture-detail and match-report destinations do not exist yet |
| MOTM | Class 1 → 2 | The Captain Hub card does not yet match IMG_0543 |
| Team fixture payments | Class 5 → fixed (class 3) | The Pay buttons are now hidden behind the owner flag |

**New class-5 defect found and fixed during implementation.** Seven routes were nested under parent
routes that render no `<Outlet/>`, so each URL showed its parent page instead of its own:
- `/teams/$teamId` showed the Teams directory.
- `/admin/analytics`, `/admin/referees`, `/admin/retention` and `/admin/guardian-consents` showed the
  Admin Dashboard.
- `/referee/matchday` and `/referee/report/$fixtureId` showed the Referee Workspace.

The Analytics & Reports, Referee admin, retention, guardian-consent, referee matchday and match-report
pages were therefore unreachable, despite earlier PRs and audits describing them as present.
- **Fix:** the routes are un-nested (`parent_.child`).
- **Prevention:** a static guard and an e2e test now stop this recurring.
- **Consequence:** the class 2 ratings for those admin and referee pages covered their code only. Their
  in-browser behaviour still needs signed-in verification.

Section 6 totals below are the pre-reconciliation snapshot. Current figures come from
`node scripts/completion-percentage.mjs`.

## 1. Classification used (owner definition)

| # | Class | Meaning |
| --- | --- | --- |
| 1 | **Complete and verified** | Interactions, permissions, validation, persistence, loading/error states and responsive behaviour are implemented, with automated or recorded browser evidence |
| 2 | **Functional, visually incomplete** | Works end to end in code and tests, but does not yet match the reference design |
| 3 | **Partially implemented** | Some of the required functionality is missing |
| 4 | **Missing** | No implementation |
| 5 | **Implemented but failing or incorrectly connected** | Code exists but behaves wrongly, or is wired to something unavailable |

"Verified" means local automated checks and browser checks run against stand-in data. **No page has been
accepted against a real Supabase project, real email delivery or real Stripe.** No staging environment
exists (INF-02). Class 1 therefore means locally verified only, never release-accepted.

## 2. Test evidence at `171d2af8`

All checks below were run locally against the exact commit. CI could not run because the commit cannot
be pushed.

| Check | Command / harness | Result |
| --- | --- | --- |
| TypeScript | `npx tsc --noEmit` | pass |
| Unit/domain tests | `npx vitest run` | 24 files, 195/195 |
| Production build | `npm run build` | pass |
| Cloudflare Worker bundle | `npx wrangler deploy --dry-run` | pass (2,732 KiB, 575 KiB gzip; dry run only, nothing deployed) |
| Clean migration replay | PG16 + Supabase stubs, CI order | 153 migrations, 41/41 SQL behavioural suites |
| Database security assertions | `verify-security-assertions.mjs` | pass |
| Generated types | `verify-generated-types.mjs` | match (61 tables, 221 functions, 9 enums) |
| Migration manifest; draft parity; navigation; Edge Function boundaries | repository verifiers | pass |
| Responsive/PWA acceptance | `playwright.config.ts` (12 public routes × 320/375/390/430/820/1440 px, PWA) | 74/74 |
| PostHog consent/network acceptance | `playwright.analytics.config.ts` | 3/3 |
| Hosted-order verifier, last step | needs the Supabase CLI local stack (Docker) | **not runnable here.** Ordering portion passed: 99 baseline + 54 pending. |
| Deno check of Edge Functions | `deno check` | **not run.** Deno is not installed here; it runs in CI. |
| Real Supabase / Stripe / Resend / PostHog ingestion | — | **not tested.** No staging; owner approval required. |

**Dead-link scan:** every internal `to=`/`href=` destination resolves to an existing route, and every
admin anchor has a target. The one "Not yet configurable here" panel in admin Settings is an honest
disclosure, not a dead control.

## 3. Navigation: contradictory instructions (owner decision required before any change)

Three instructions now conflict. **No navigation change will be made until the owner confirms which one
is authoritative.**

| Source | Visitor | Registered player | Captain | Referee |
| --- | --- | --- | --- | --- |
| Today's alignment assignment (Phase 3) | Home, Match Centre, Teams, Join Open Play, More (**5**) | Player Hub, Match Centre, Teams, More (**4**) | Player Hub, Club, Matchday, More (**4**) | Referee Home, Match Centre, Matchday, More |
| Screen-by-screen specification (earlier today, §5) | 5 (same) | Home/Player Hub, Match Centre, Teams, **Join Open Play**, More (**5**); "Do not remove Join Open Play" | the 5 player tabs; Club and Matchday "without destroying the five-tab player navigation" | — |
| Reference images | 4 (IMG_0581, IMG_0562) | 4 without Join (IMG_0522, IMG_0572–IMG_0580) | Home, Match Centre, Teams, Captain's Hub, More (IMG_0543) | not shown |

**Inconsistencies within the instructions:**
- The alignment assignment lists five visitor tabs but also states "the approved mobile navigation has
  exactly four tabs".
- The registration bar has been 4 tabs (Home, Match Centre, Join Open Play, More) in every source.

**Current code (`171d2af8`):**
- Implements the screen-by-screen specification: 5 tabs everywhere, and 4 on registration screens.
- Referee navigation is already Home, Match Centre, Matchday, More (`referee-bottom-navigation.tsx`).
- The Phase 3 player and captain layouts are exactly what the code had before commit `c72a0658`. Adopting
  Phase 3 is a small, tested change to `src/lib/navigation/account-navigation.ts` only.

**Recommended decision:** adopt today's Phase 3 table, the most recent and most specific instruction:
- visitor: 5 tabs, which fit on one row at 320 px (proven by e2e);
- player: 4 tabs;
- captain: Player Hub, Club, Matchday, More;
- referee: unchanged;
- registration screens: 4 tabs.

## 4. Reference images

- **Stored:** `docs/reference-assets/visual-references/` holds 32 owner images (IMG_0522–IMG_0583), each
  inspected and indexed.
- **No reference image exists for:**
  - referee screens;
  - any admin screen;
  - captain Club and Matchday as separate screens (IMG_0543 shows a combined Captain's Hub);
  - fixture detail, match report and gallery;
  - More, sign-in, sign-up and reset password;
  - notification preferences.

  For these, the design system and specifications apply and nothing is invented. If designs exist, the
  owner should supply them.
- **Mockup photographs are not usable:** credited third-party photos and a real person's portrait.
  Licensed imagery is required.
- **Logo:** the official OP logo binary is still not in the repository (D5, issue #18). Every page uses the
  existing `/open-play-logo.png`.

## 5. Page-by-page audit

### Public website

| Page | Route / files | Class | Evidence | What is missing or wrong |
| --- | --- | --- | --- | --- |
| Home | `/`, `src/routes/index.tsx` | **3** | e2e responsive pass; auth-redirect assertions | Cream/light sections break the dark identity. No published competition data, latest results or Browse Teams block. IMG_0562 four-steps layout absent. Does not use the global header. |
| Match Centre | `/match-centre`, `src/lib/competition/standings.ts` | **2** | Standings and D7 unit tests; SQL points tests; e2e | Fixtures, results, points-only table and tied-final notice work. Missing: IMG_0532 hub (hero, four tiles, table preview), fixture → detail and result → report links (pages missing), team-stats view, mobile table adaptation (currently a horizontally scrolling table container). |
| League/location discovery | `/leagues` | **2** | e2e; data scoped to published, active rows | Missing: Active/Upcoming sections with status pills, per-card actions and "View league details" (IMG_0583/IMG_0579). |
| Teams directory | `/teams` | **3** | e2e | Lists approved teams for the selected season, plus Club Leaders when signed in. Missing: search, initials/badges, squad counts, played and points (IMG_0533). |
| Team profile | `/teams/$teamId` | **3** | UUID validation; published data only | Missing: position/points/played strip, squad view, team navigation (squad, fixtures, results, statistics), paginated team fixtures and results (IMG_0535/0536/0540/0538), and SEND TRANSFER REQUEST for eligible players without a club. |
| Join Open Play (signed out) | `/join`, `src/components/public-join-landing.tsx` | **1** | Playwright at 390 and 320 px; e2e all widths | Matches IMG_0581. |
| Join Open Play (signed-in workspace) | `/join` | **3** | `request_team_membership` and `register_team` are server-checked | Single join form and single team form. Missing: IMG_0582 "Your next move" cards, IMG_0567 post-submit choice, and the 4-step team wizard (IMG_0568–IMG_0571) with crest, Instagram, WhatsApp, notes and five versioned declarations. |
| More | `/more` | **2** | Protected links shown only after server RPC checks; verifier assertions | No reference image. Styling is basic. Sign-out lives on the profile page, not here. |
| Sign in / Sign up / Reset password | `/sign-in`, `/sign-up`, `/reset-password` | **2** | Auth lifecycle tests in CI; non-enumerating reset | Email verification and reset not verified with a real provider (Resend not configured). Visual alignment pending. |
| Gallery | `/gallery`, `public-gallery` function | **2** | Published-only filter in the function | The `public-gallery` function is among the four deployed hosted functions; other functions are branch-only. No collection view; no reference image. |
| Privacy and permissions | `/privacy-security` | **3** | Consent controls work (e2e consent 3/3) | Legal privacy notice and terms not published (PUB-10, blocked on legal text and controller name). |

### Registration

| Page | Route | Class | Evidence | What is missing or wrong |
| --- | --- | --- | --- | --- |
| Player registration | `/register-player` | **3** | Age tiers and guardian consent (`age_tier_guardian_consent.sql`, `registration_safeguards.sql`); phone canonicalisation; duplicate identity review (PR #49 content) | Single form. Missing: the 5-stage wizard (IMG_0563–IMG_0567); first/last name, home town and preferred position fields; emergency contact storage; versioned declaration records with timestamps; discovery source; separate email/SMS marketing consent. Needs a forward migration. |
| Team registration | inside `/join` | **3** | `register_team` server checks; admin approval required; no captaincy before approval | See the Join workspace row. Instagram and crest are in PR #122 (not integrated). Weekly-fee declaration not recorded. |

### Player

| Page | Route / files | Class | Evidence | What is missing or wrong |
| --- | --- | --- | --- | --- |
| Player Hub | `/player` | **3** | Ban redirect; disciplinary notice; availability; notification preferences | Missing: IMG_0522 layout (welcome, season pill, stats strip, six tiles, Next Match), pending-request status card, and the distinct states for no club, pending and in a club. **Contains a Stripe "pay fixture" action; see class 5 below.** |
| My Team | — | **4** | — | No dedicated page. Members reach their team only through `/teams/$teamId`, which has no squad view. |
| My Profile (account) | `/player/profile`, `player-profile.tsx`, `lib/profile/avatar.ts` | **1** | Avatar unit tests; storage policy SQL (`profile_avatar_only_permissions.sql`); Playwright | Real storage upload not verified. Terms link pending legal text. |
| Player statistics / public profile | — | **4** | Server statistics exist (`get_admin_season_statistics`, player club statistics, MOTM counts) | No public player profile page. Season and career statistics, goals per game, contributions, career history and goalkeeper variant missing (IMG_0542). |
| My Fixtures | `/player/fixtures`, `lib/competition/player-matches.ts` | **3** | Unit tests (upcoming-only, 4 per page, paging); Playwright | Fixture → detail link missing because the detail page does not exist. |
| My Results | `/player/results` | **3** | Unit tests (completed and published only, W/D/L); Playwright | Result → match report link missing because the report page does not exist. |
| League table (Player Hub) | — (table only in Match Centre) | **3** | Standings logic tested | No IMG_0574 page with Your Team highlight and position summary. |
| Notifications / Inbox | `/inbox`, `lib/notifications` | **1** | Unit tests; Playwright; RLS limits rows to the owner | Email/SMS delivery not configured (NOT-02); push missing (NOT-03, PR #130). |
| Notification preferences | `/player#notification-preferences` | **3** | — | Category preferences PRs #128 and #129 compete; neither is integrated. |
| Fixture detail | — | **4** | — | Missing. |
| Match report | — | **4** | Published match events exist server-side | Missing. |

### Captain

| Page | Route / files | Class | Evidence | What is missing or wrong |
| --- | --- | --- | --- | --- |
| Captain Hub | `/captain` (`#captain-club`, `#captain-matchday`) | **2** | `get_captain_dashboard`; captain-only RPC checks; session-isolation fixes (PRs #116/#117) | Missing: IMG_0543 layout (next-fixture header, request card with pending count, finance summary). |
| Club and squad management | `/captain` | **3** | `set_team_squad_number`, `handover_team_captain` | Captain-requested removal needing player approval (PR #112) and future-season transitions (PR #93) not integrated. No squad search. |
| Membership requests and player approvals | `/captain` | **2** | `resolve_team_membership_request`, `resolve_player_transfer_request`; `membership_approval_authorization_locks.sql`; `player_transfer_workflow.sql` | Location-wide exclusivity (PR #113) not integrated. |
| Team sheets | `/captain` | **2** | `save_team_sheet_draft` and `submit_team_sheet` enforce 6+3 / 7+4, goalkeeper and eligibility | **Gap:** no negative SQL test proves that wrong-size sheets are rejected. |
| Matchday | `/captain#captain-matchday` | **2** | `get_captain_fixtures`, `get_captain_availability` | Visual alignment pending. |
| Man of the Match nominations | `captain-motm-nominations.tsx`; migration `20261113150000` | **2** | `fixture_motm_nominations.sql` | Self-nomination allowed under the same eligibility as any player (matches the specification). |
| Matchday reporting (captain) | — | **4** | — | Only referees and admins report matches. Captain reporting "where authorised" has no defined authority; owner to confirm whether it is required. |
| Team fixture payments | `captain-team-payments.tsx`, `create-team-fixture-checkout` | **3** | Function rejects non-`sk_test_` keys | Fixed after this audit: Pay actions are hidden behind the owner-controlled `online_card_payments` flag (off), and both checkout functions refuse checkout while it is off (D6). Remains blocked on D6 and Stripe configuration. |

### Referee

| Page | Route / files | Class | Evidence | What is missing or wrong |
| --- | --- | --- | --- | --- |
| Referee Hub and application | `/referee` | **2** | `referee_application_workflow.sql`; portal state RPC | No reference image; visual alignment pending. |
| Assigned fixtures | `/referee/matchday` | **2** | `referee_fixture_assignments.sql` (availability) | — |
| Match reporting | `/referee/report/$fixtureId` | **2** | `referee_match_reports.sql` (deadline, rejection, resubmission, approval, corrections, finance) | — |
| Stripe Connect onboarding | `/referee`, `create-referee-connect-account` | **3** | Live keys rejected; signature tests; PR #64 content present byte-identically | **Blocked externally:** no Connect test account, no webhook endpoint, functions not deployed, staging not approved. |
| Payment status and payout history | `/referee`, `/admin/referees` | **3** | `referee_connect_payouts.sql` (one £22 entitlement and one outbox job; ambiguity handling) | Real transfer and webhook round trip not tested; same blockers. |
| Matchday history | `/referee` | **3** | Reports listed | No dedicated history view. |

### Admin

`/admin` is a single long page with 15 anchor sections. The specified 14 sections and a left sidebar are
not yet matched.

| Specified section | Current location | Class | Evidence | What is missing or wrong |
| --- | --- | --- | --- | --- |
| Overview | `#admin-dashboard`, `/admin/analytics` | **3** | `get_admin_dashboard_contextual` | Needs Attention task centre is PR #110 (not integrated). Metrics are not linked to filtered registers. |
| Locations and Leagues | `#admin-competitions` | **2** | Location scope SQL tests | — |
| Seasons | `#admin-season-setup` | **2** | Manual recruitment, points rules, title final, completion guard (SQL) | — |
| Teams | `#admin-team-registers` | **2** | `resolve_team_registration`; squad add/remove | Crest and Instagram (PR #122). |
| Players | `#admin-players` | **2** | Contextual register, ban, identity review, retention, guardian consents | No side-panel detail pattern (ADM-04). |
| Applications and Approvals | `#admin-team-approvals`, `#admin-player-approvals` | **2** | Approval RPCs, audit | The specification has one combined Approvals section. |
| Fixtures | `#admin-fixtures` | **2** | Round-robin generator; venues; postponements (SQL) | — |
| Team Sheets | `#admin-team-sheets` | **2** | `admin_amend_team_sheet`; historical players test | — |
| Results and Match Events | `#admin-results` | **2** | Goals, assists, own goals, MOTM corrections (SQL) | Card and disciplinary events partial. |
| Statistics | `#admin-reports`, `/admin/analytics` | **3** | Season stats SQL | Labelled "Analytics & Reports". Several analytics tabs show honest "unavailable" states because PostHog ingestion is unverified. |
| Gallery | `#admin-gallery` | **2** | Register and publish RPCs | Upload pipeline relies on storage paths. |
| Finance | `/finance` | **2** | Ledger, summary, fixture fees, operating costs | Stripe payments reader shows test data only; no live reconciliation. |
| Feature Management | `#admin-settings` | **2** | `admin_set_platform_feature_flag` | Combined with Settings. |
| Settings | `#admin-settings` | **3** | — | Branding, role creation and competition-rule overrides are listed as not yet configurable (honest disclosure). |
| Referees (extra) | `/admin/referees` | **2** | Referee SQL suites | — |
| Communications (extra) | `#admin-communications`, `/admin-messages` | **3** | Messaging SQL | Delivery providers not configured. |
| Role management and first super-admin | `admin-league-admin-roles.tsx` | **3** | Location assignment audit | First super-admin bootstrap awaits owner approval (PR #108 runbook). |

**Admin-wide:**
- Global filters (location, league, season) exist and persist through `save_admin_context_preference`.
- "All locations" is only offered to global admins.
- Registers are not yet searchable side-panel layouts.
- `admin.tsx` packs most of the workspace into a few lines of 2,000–8,700 characters. This is the main
  maintainability risk and the main obstacle to the visual work.

### Global components

| Component | Class | Evidence | What is missing or wrong |
| --- | --- | --- | --- |
| Global header | **1** | Unit tests; e2e header-overlap check at 6 widths | Logo asset pending (D5). |
| Bottom navigation | **1** (mechanics) | Unit tests; e2e one-row/no-clip check at 6 widths | Final tab set awaits the decision in section 3. Icons are inline SVG, not Lucide. |
| Design system (cards, buttons, headings, status pills, empty/loading/error states) | **3** | Tokens exist (`--op-*`, Oswald/Inter) | No shared component library. Headings are mixed case with orange second lines, while the references use uppercase white. Light cream surfaces remain on Home. |

## 6. Totals

Counted from the rows in section 5 (58 rows):

| Class | Rows | Which |
| --- | --- | --- |
| 1 Complete and verified (locally) | 8 | Join (public), My Profile, My Fixtures, My Results, Inbox, MOTM nominations, global header, bottom navigation (mechanics) |
| 2 Functional, visually incomplete | 24 | — |
| 3 Partially implemented | 20 | — |
| 4 Missing | 5 | My Team, public player profile/statistics, fixture detail, match report, captain matchday reporting |
| 5 Failing or incorrectly connected | 1 row, 2 places | Captain team payments, plus the same Pay action inside the Player Hub (a class-3 row) |

## 7. Preserved engineering (Phase 6)

| PR | Status in the working branch | Outstanding manual acceptance |
| --- | --- | --- |
| **#49** Registration safeguards (head `f6fa3d7e`, targets `test/auth-email-lifecycle-2026-11-08`) | Not an ancestor, but **all 115 migrations are byte-identical** in HEAD, and its functions and UI are present through #109 | Staging Resend sender and the 90/30/7-day warning emails; guardian and reactivation email round trips; retention worker in staging; legal review of retained competition identities; privacy notice (controller name); avatar deletion in staging; real-device acceptance. **Not signed off.** |
| **#64** Stripe Connect referee payments (head `4da5a4ce`) | All migrations byte-identical in HEAD; payment-safety fixes from #114 are present through #109 (`dc31eb4e` is an ancestor of HEAD) | Isolated staging; test-only frontend, function and Vault configuration; real UK test onboarding; one £22 transfer; signed webhook, replay, reversal, stale-event and timeout reconciliation; device acceptance. The Stripe test account has zero connected accounts and zero webhooks. |
| **#109** Canonical integration candidate (head `9fa59d15`) | Functional heads `57161e8e` and `dc31eb4e` are ancestors of HEAD. Not included: 3 documentation commits, including `docs/feature-completion-inventory-2026-11-13.md` | Super-admin bootstrap approval, branch protection, Cloudflare target verification, logo binary, PostHog ingestion, staging email and payment round trips, full manual Analytics acceptance |

Also preserved:
- security and membership-approval locks (#138, #116, #117);
- PostHog consent provider (e2e 3/3);
- statistics and competition history (points-only, title final, assists and own goals);
- location and season functionality (venues, manual recruitment, round-robin).

**No competing implementation will be created.**

## 8. Completion estimates, measured separately

The owner's independent estimate is about 63% overall. Measured strictly per page and section, using the
classes above (class 1 = 1.0, class 2 = 0.75, class 3 = 0.4, classes 4 and 5 = 0):

| Measure | Estimate | Basis |
| --- | --- | --- |
| **Functional completion** | **≈ 59%** | Weighted page classes (34.0 / 58 rows); server workflows are strong, but the wizards, detail pages and transfer request on team pages are missing |
| **Visual completion against the references** | **≈ 30%** | Only 8 screens or components match their references; most screens predate the reference set |
| **Automated test coverage** | **≈ 55%** | Server rules are well covered (41 SQL suites, 195 unit tests); browser e2e covers public routes and consent only, with no signed-in e2e journeys |
| **Release readiness** | **≈ 15%** | No staging; 54 hosted migrations pending approval; no real email, payment or ingestion verification; legal text and logo outstanding; GitHub publishing blocked |

These replace the register's requirement-weighted 75% feature figure for planning purposes. The register
counts requirements, not finished pages.

## 9. Prioritised implementation plan

Each step is one focused pull request on a single branch line. No competing branches touch the same
components. Every step reruns the section 2 checks at the exact commit.

| # | Pull request | Contents | Depends on |
| --- | --- | --- | --- |
| 0 | **Owner decisions** | (a) navigation table (section 3); (b) captain matchday reporting required?; (c) GD display; (d) admin 14 vs 15 sections; (e) IMG_0567 vs IMG_0582 post-registration flow | — |
| 1 | **Fix incorrect connections** | Gate the Player Hub and captain Pay buttons behind an owner-controlled flag (D6) with honest copy; apply the navigation decision; add negative SQL tests for team-sheet size | 0(a) |
| 2 | **Design system and shared components** | `PageHeader`, `Card`, `Button`, `StatusPill`, `EmptyState`/`ErrorState`/`Loading`, `StatTile`; Lucide icons (pinned); uppercase white headings; remove cream surfaces; no behaviour changes | 1 |
| 3 | **Public pages** | Home (IMG_0562), Match Centre hub (IMG_0532), Leagues (IMG_0583/IMG_0579), Teams directory (IMG_0533), team profile with squad, fixtures and results sub-views (IMG_0535–IMG_0540); responsive tables | 2 |
| 4 | **Fixture detail, match report, public player profile with statistics** | New routes from published data only; goals per game shown empty when there are no appearances; goalkeeper variant | 3 |
| 5 | **Player registration wizard** | Forward migration (emergency contact, versioned declarations, discovery, separate marketing consents) with positive and negative SQL tests; 5-stage UI; IMG_0567 next step | 2 |
| 6 | **Team registration wizard and SEND TRANSFER REQUEST** | Integrate PR #122 (Instagram, crest); 4-stage wizard with declarations including weekly fee; transfer request on team pages with pending, approved and declined states; Player Hub status card | 5, PR #113 |
| 7 | **Player Hub (IMG_0522), League table page (IMG_0574), My Team** | Per-state Player Hub content | 3, 4 |
| 8 | **Captain experience (IMG_0543)** | Integrate PRs #113, #112, #93 (restack); Club/Matchday layout; squad management | 6 |
| 9 | **Referee experience** | Visual alignment; dedicated history; Connect status (still test-mode and blocked externally) | 2 |
| 10 | **Admin** | Split `admin.tsx` into section components (no behaviour change first); sidebar; agreed sections; PR #110 Needs Attention; searchable registers and side panels | 0(d), 2 |
| 11 | **Notifications** | Choose #128 or #129; integrate #115; #131 after the D4 decision | — |
| 12 | **Signed-in e2e suites** | Visitor, player, pending, captain and admin journeys against a seeded local Supabase stack in CI | 3–10 |
| 13 | **External acceptance** (owner-approved only) | Staging, hosted migrations, Resend, Stripe test Connect, PostHog ingestion, real devices | Owner approval |

## 10. External configuration still required (owner)

- GitHub write access for the Claude App. Without it, no PR can be opened or updated and CI cannot run on
  this work.
- Staging Supabase project and budget approval.
- Approval to apply the 54 forward-only migrations (`--include-all`, after a backup).
- Resend sender and secrets.
- Stripe test Connect account and webhook.
- PostHog project keys and ingestion verification.
- Official logo binary.
- Licensed photography.
- Legal privacy notice and terms (controller's full name).
- First super-admin identity.

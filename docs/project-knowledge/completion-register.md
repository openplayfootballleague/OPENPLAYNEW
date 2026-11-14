# Open Play — Evidence-Based Completion Register

**Single authoritative register.** Branch `claude/open-play-master-blueprint-rhtuih`, which is built on integration tip PR #140 (`6445e3f`).
Requirement sources: `docs/project-knowledge/*`, `docs/owner-decisions-2026-11-13.md`, visual references `IMG_0564`–`IMG_0583`.
Percentages: computed by `node scripts/completion-percentage.mjs`, never typed by hand. Four separate stages: **Feature implementation** (all rows except INT-/INF-/SEC-), **Integration** (INT-), **Security & infrastructure** (SEC- and INF-), **Formal acceptance** (rows with status Accepted, across everything).

## Rules

- **Complete:** the agreed implementation is present (UI + server/DB + permissions + validation/states), and its relevant automated checks pass at the stated commit. This is *not* acceptance.
- **Partially Complete:** some of the agreed implementation exists; the gap is stated.
- **Not Started:** no implementation of the agreed requirement.
- **Blocked:** cannot proceed without an owner decision, asset, provider or approval. Counts as 0.
- **Accepted:** formally accepted by the owner. Nothing is Accepted yet.
- **Credit:** Complete/Accepted = 1.0, Partially Complete = 0.5, everything else = 0.
- **Weights:** 1 = small, 2 = standard workflow, 3 = core workflow, 5 = foundational or high-risk.
- **Evidence:** "SQL" means a `supabase/tests` regression passes in a clean replay; "unit" means Vitest; "browser" means a Playwright check at 390px with test-only data. Local checks were run on this branch; GitHub CI has **not** run on it (unpushed, push 403).
- **Manual acceptance** (real identities, devices, providers) is outstanding for every row and is not repeated per row.

## Register

| ID | Requirement | Screen / workflow | Frontend | Backend / DB | Security | Validation & states | Automated evidence | PR / commit | Status | Weight |
|---|---|---|---|---|---|---|---|---|---|---|
| PUB-01 | Home: hero, CTAs, live competitions/fixtures/results/stats/gallery previews | `/` | Hero + CTAs | Only player/membership lookups; no live competition sections | Public read via RLS | Partial | build | tip | Partially Complete | 3 |
| PUB-02 | Match Centre: season selection, fixtures, results, table | `/match-centre` | Yes; title-final label | Published data via RLS | Public-only data | Loading/empty/error | unit (standings) | tip, `9172928` | Complete | 3 |
| PUB-03 | League table: points only, shared positions, final when level first | Match Centre, Admin stats | Yes | `get_admin_season_statistics`, `season_joint_leaders` | Admin RPC scoped | Pre-season tie suppressed | unit + SQL (mutation-checked) | `9172928` | Complete | 3 |
| PUB-04 | Team directory and public team profiles | `/teams`, `/teams/$teamId` | Yes | Published data | Public-only | Error state | CI green at `f89c1f1` | #139 | Complete | 2 |
| PUB-05 | League discovery, Active/Upcoming (IMG_0583/0579) | `/leagues` | Yes | Published seasons | Public-only | Empty states | CI green at `6445e3f` | #140 | Complete | 2 |
| PUB-06 | Public Join Open Play page (IMG_0581): three pathways, player-first | `/join` | Existing join form; no IMG_0581 layout | — | — | — | — | — | Partially Complete | 2 |
| PUB-07 | Public gallery (published only) | `/gallery` | Yes | `public-gallery` function | Published only | — | SQL (gallery) | tip | Complete | 2 |
| PUB-08 | Shared header: signed-in/out variants, notifications, location selector (IMG_0577/0578) | All | Header without location selector or notification control | — | — | — | — | — | Partially Complete | 2 |
| PUB-09 | Privacy, policies and terms pages | `/privacy-security`, More | Yes | — | — | — | build | tip | Complete | 1 |
| PUB-10 | Legally reviewed Terms and Conditions and privacy notice published | Profile, More | Profile shows "awaiting publication" | — | — | — | — | owner/legal content | Blocked | 1 |
| NAV-01 | Viewer bottom navigation (4 vs 5 tabs) | All public | 5 tabs; wraps at 390px | — | — | — | — | — | Blocked | 2 |
| NAV-02 | Registered player navigation: exactly 4 tabs | Player | Yes | — | Session-derived | — | verify-player-navigation | tip | Complete | 2 |
| NAV-03 | Captain navigation: Club and Matchday | Captain | Yes | — | Captain RPCs | — | verify-player-navigation | tip | Complete | 1 |
| REG-01 | Sign-up, sign-in, sign-out, password reset, verification | auth routes | Yes | Supabase Auth | Session boundary (#117) | Error states | unit + auth lifecycle test | tip, `d415b81` | Complete | 3 |
| REG-02 | Player registration: DOB mandatory, duplicate identity review, age tiers, guardian consent | `/register-player` | Yes | `register_player`, guardian consent | Server-validated | Yes | SQL (identity, guardian) | tip | Complete | 5 |
| REG-03 | Registration: emergency contact step (IMG_0564) | `/register-player` | Not in player flow (admin view only) | Fields exist in profiles | Restricted | — | — | — | Partially Complete | 2 |
| REG-04 | Registration: fitness and versioned declarations (IMG_0565) | `/register-player` | No | No | — | — | — | — | Blocked | 3 |
| REG-05 | Registration: discovery source and separate email/SMS marketing consent (IMG_0566) | `/register-player` | No | No consent records | — | — | — | — | Not Started | 2 |
| REG-06 | Post-registration choice: create club, join club, continue as individual (IMG_0567/0582) | onboarding | Partial completion handoff | — | — | — | — | tip | Partially Complete | 2 |
| REG-07 | Team registration four-step wizard with drafts and versioned declarations (IMG_0568–0571) | `/join` | Single form, no wizard or drafts | `register_team` (pending application) | Auth required | — | SQL (team registration) | tip | Partially Complete | 5 |
| REG-08 | Team Instagram URL and crest upload | wizard, profiles | No | No | — | — | — | #122 (unintegrated) | Not Started | 1 |
| REG-09 | Team approval makes the applicant captain atomically | Admin approvals | Yes | `resolve_team_registration` | Admin-scoped, audited | Yes | SQL | tip | Complete | 3 |
| REG-10 | Join requests; captain approve/decline, safe against handover races | Captain, Join | Yes | `resolve_team_membership_request` with row locks | Captain/location scope | Yes | SQL incl. `membership_approval_authorization_locks` | `def2a4f` (#138) | Complete | 3 |
| REG-11 | No conflicting active memberships location-wide | Membership | — | Season-level only | — | — | — | #113 (unintegrated) | Partially Complete | 2 |
| PH-01 | Player Hub dashboard (team, fixtures, results, table, stats, notifications) | `/player` | Yes | RLS + RPCs | Session isolation (#116) | Load error kept | unit + browser | `6e41bb6` | Complete | 3 |
| PH-02 | My Fixtures page: chronological, home/away, kick-off, pitch, postponed/cancelled states, detail, pagination (IMG_0572) | `/player/fixtures` | Yes | RLS-scoped fixtures, venues | Own team only, session boundary | Loading/empty/error/no-team | unit (domain) + browser (0px overflow) | this commit | Complete | 2 |
| PH-03 | My Results page: published only, W/D/L from team perspective, detail, pagination (IMG_0573) | `/player/results` | Yes | RLS-scoped confirmed results | Own team only, session boundary | Loading/empty/error/no-team | unit (domain) + browser | this commit | Complete | 2 |
| PH-04 | League table screen with Your Team highlight and position summary (IMG_0574) | Player Hub | Table exists; highlight/summary not verified to spec | Standings service | — | — | — | — | Partially Complete | 2 |
| PH-05 | Statistics: apps 4(3), goals, assists, GPG, MOTM, contributions; season and career | Player Hub | Yes | `get_my_player_statistics`, MOTM awards | Self-scoped RPC | Unavailable states | SQL (mutation-checked) + browser | `6d94841`, `c7ec99a` | Complete | 3 |
| PH-06 | Player profile screen: picture-only edit, read-only personal and football details, settings links, log out (IMG_0575) | `/player/profile` | Yes | Own rows under RLS; shared avatar module | Picture-only privileges; session boundary | Upload validation, loading/error | unit (avatar) + browser | this commit | Complete | 2 |
| PH-07 | Inbox: All / Messages / Notifications (IMG_0576) | `/inbox` | Yes | Recipient-scoped reads, mark-read RPC | Session boundary | Loading/empty/error | unit + browser (0px overflow) | `7541042` | Complete | 3 |
| PH-08 | Notification preferences by category | Profile | Global preferences only | — | — | — | — | #128 vs #129 (competing) | Partially Complete | 1 |
| PH-09 | Account-switch isolation of protected state | All protected | Yes | — | Client isolation | — | unit (5) | `d415b81`, `6e41bb6` | Complete | 2 |
| CAP-01 | Captain dashboard, squad, squad numbers | `/captain` | Yes | Captain RPCs | Captain-scoped | Yes | SQL | tip | Complete | 3 |
| CAP-02 | Team sheets: 6+3 / 7+4, GK among starters, drafts, lock, next-required fixture | `/captain` | Yes | `submit_team_sheet` | Captain-scoped | Yes | unit + SQL | tip | Complete | 5 |
| CAP-03 | Former players preserved on historical team sheets | Admin sheets | Yes | `get_admin_team_sheets_contextual` | Admin-scoped | Former-player fallback | SQL (fixed test, mutation-checked) | `49c9d29` (#137) | Complete | 1 |
| CAP-04 | Man of the Match nominations; self-nomination when on the sheet | `/captain`, Admin | Yes | `submit_fixture_motm_nomination` | Eligibility enforced | Yes | SQL | `c7ec99a` | Complete | 2 |
| CAP-05 | Captain-requested removal needs player approval | Captain | No | No | — | — | — | #112 (unintegrated) | Not Started | 1 |
| CAP-06 | Future-season membership and captaincy transitions | Seasons | No | No | — | — | — | #93 (unintegrated) | Not Started | 2 |
| REF-01 | Referee applications, portal, assigned fixtures | `/referee` | Yes | Referee RPCs | Assigned fixtures only | Yes | SQL (applications, assignments) | tip | Complete | 3 |
| REF-02 | Match reports, approval, corrections, discipline, return queue | `/referee/*`, Admin | Yes | Yes | Scoped, audited | Yes | SQL (match reports) | tip | Complete | 3 |
| REF-03 | Referee Stripe Connect payouts (test mode); ambiguous responses never marked failed | Referee, Finance | Yes | Payout functions + transfer policy | Signature-verified webhook, idempotency keys | Timeout/409/429/5xx stay ambiguous | SQL (connect payouts) + Deno tests (CI) | #64, #114 integrated via `eadd1059` | Blocked | 3 |
| COMP-01 | Locations, leagues, seasons, lifecycle, manual recruitment | Admin | Yes | Yes | Location-scoped | Yes | SQL | tip | Complete | 3 |
| COMP-02 | Venues and operating hours | Admin | Yes | `venues` + scoped RPCs | Location-scoped | Yes | SQL (behavioural, mutation-checked) | `259b2b5` | Complete | 2 |
| COMP-03 | Round-robin generator: single and double (8 teams: 56/14/4), review before publish | Admin Fixtures | Yes | `admin_generate_round_robin_fixtures` | Location-scoped, preview hash | Yes | SQL (56/14/4, 7+7, single 28/7) | `259b2b5` | Complete | 3 |
| COMP-04 | Fixture changes, postponements, weather renumbering with history | Admin | Yes | Yes | Scoped, audited | Yes | SQL (weather) | tip | Complete | 3 |
| COMP-05 | Results, scorer validation, audited corrections, published-only | Admin | Yes | Yes | Scoped | Yes | SQL | tip, `abd79a1` | Complete | 3 |
| COMP-06 | Assists and own goals as structured events | Admin | Yes | `admin_record_fixture_goal_events` | Scoped, audited | Yes | unit + SQL (mutation-checked) | `6d94841` | Complete | 2 |
| COMP-07 | Title final for level first place; completion guard | Admin | Yes | Trigger + RPC | Scoped, audited | Draw/3+ rules pending | SQL (mutation-checked) | `9172928` | Complete | 3 |
| COMP-08 | Configurable win/draw/loss points, per season, locked after first published result | Admin stats, Match Centre | Admin editor + Match Centre | `seasons.points_for_*`, `admin_set_season_points`; stats and title-final helper use them | Location-scoped, audited | Ordering, lock, reason | unit + SQL (mutation-checked) | this commit | Complete | 2 |
| COMP-09 | Season completion/recruitment guards while fixtures remain (cancelled = final; confirmed results) | Seasons | — | Triggers | — | Yes | SQL (extended, mutation-checked) | `740f771` (#111) | Complete | 1 |
| ADM-01 | Admin information architecture (sidebar sections) | `/admin` | Section navigation present | — | — | — | — | tip | Partially Complete | 3 |
| ADM-02 | Needs Attention task centre | `/admin` | Basic queue | — | — | — | — | #110 (unintegrated) | Partially Complete | 3 |
| ADM-03 | Approvals: player and team applications | `/admin` | Yes | Yes | Scoped | Yes | SQL | tip | Complete | 3 |
| ADM-04 | Searchable registers, filters, side panels | `/admin` | Player register + detail panel | Yes | Scoped | Partial | SQL | tip | Partially Complete | 2 |
| ADM-05 | Audit history reader | `/admin` | Yes | Deny-all table + RPC | Platform role | — | SQL | tip | Complete | 2 |
| ADM-06 | Role management and first-admin bootstrap | Admin | League-admin management only | Yes | Global-admin only | — | SQL (role matrix) | tip; #108 docs | Blocked | 3 |
| ADM-07 | Gallery management | Admin | Yes | Yes | Scoped | — | SQL (gallery) | tip | Complete | 2 |
| ADM-08 | Feature management, recruitment and announcement toggles | Admin | Yes | Yes | Scoped | — | SQL (feature management) | tip | Complete | 2 |
| ADM-09 | Support case management | Admin, Inbox | Support conversations only | — | — | — | — | #131 (unintegrated) | Partially Complete | 2 |
| FIN-01 | Finance ledger: charges, receipts, refunds, credits, fines | `/finance` | Yes | Append-only ledger | Finance permission | Yes | unit + SQL | tip | Complete | 3 |
| FIN-02 | Team weekly fixture payments, deadlines (Stripe test) | Captain, Finance | Yes | Checkout + signed webhooks | Verified webhooks | — | SQL (team weekly payment) | tip | Blocked | 3 |
| FIN-03 | Operating costs and business performance reporting | Analytics | Yes | Yes | Finance scope | Insufficient-data states | SQL | tip (#133/#135) | Complete | 2 |
| ANA-01 | 10-tab Analytics & Reports workspace | `/admin/analytics` | Yes | Scoped RPCs | Scope + finance gating | Unavailable states | SQL + browser CI | tip | Complete | 3 |
| ANA-02 | Consent-gated PostHog with allow-list and GPC | All | Yes | — | No PII | — | CI PostHog acceptance | tip | Blocked | 2 |
| ANA-03 | CSV export formula-injection protection | Analytics | Yes | — | — | — | unit (7 assertions) | integration line (#118 superseded) | Complete | 1 |
| ANA-04 | Registration conversion cohorts in exports | Analytics | Yes | Aggregate RPC | Scoped | — | unit | `3e4a09c` (#136) | Complete | 1 |
| NOT-01 | In-app notification outbox and fixture reminders | Inbox | Yes | Outbox + pg_cron | Recipient-scoped | — | unit + SQL | tip | Complete | 3 |
| NOT-02 | Email/SMS delivery | Providers | — | Edge function | — | — | unit | tip | Blocked | 2 |
| NOT-03 | Push notifications and devices | — | — | — | — | — | — | #130 (unintegrated) | Not Started | 1 |
| MSG-01 | Secure messaging: same-team direct, team groups, blocks, reports, admin moderation | Inbox Messages | Yes | Messaging RPCs | Same-active-team rule | Yes | SQL (messaging) | tip | Complete | 3 |
| SEC-01 | RLS, SECURITY DEFINER guards, no anon definer functions | DB | — | Yes | Yes | — | 26 security assertions + SQL | `6e41bb6` | Complete | 5 |
| SEC-02 | Database recreatable from repository migrations (D3) | DB | — | 99 sources match hosted ledger; all 153 versions fixed (no CI-generated versions) | — | Generated types verified against replay | migration-source verifier + replay (153 migrations, 41/41 SQL) + `verify-generated-types.mjs` | `d382d822`, `def2a4f` | Complete | 5 |
| SEC-03 | Accessibility: global focus states, reduced motion | All | Yes | — | — | — | build | `2548a95` (#141) | Complete | 2 |
| SEC-04 | Official logo asset (D5) | All | 192×115 placeholder | — | — | — | — | issue #18 | Blocked | 1 |
| SEC-05 | Local development and Worker build tooling | Tooling | — | — | — | — | dev server + dry-run | `1798158` | Complete | 1 |
| SEC-06 | PWA install shell | All | Yes | — | No auth caching | — | CI PWA acceptance | tip | Complete | 1 |
| INT-01 | Working branch published to GitHub with green exact-head CI | GitHub | — | — | — | — | Local equivalents only | push returns 403 | Blocked | 3 |
| INT-02 | Open PRs on the current lineage consolidated into one integration branch | GitHub | — | — | — | — | Per-PR verification recorded | 11 integrated or superseded this session; 10 remain (#131, #130, #129/#128, #122, #115, #113, #112, #110, #106, #105) | Partially Complete | 3 |
| INT-03 | Consolidated line promoted to `main` (owner-approved merge) | GitHub | — | — | — | — | — | — | Not Started | 3 |
| INF-01 | Pending migrations applied to the hosted Supabase project | Supabase | — | 54 pending forward migrations (listed in `docs/migration-integrity-audit-2026-11-14.md`) | — | — | Clean replay only | owner approval required | Blocked | 3 |
| INF-02 | Staging environment (Supabase + Cloudflare preview) | Infra | — | — | — | — | — | staging budget approval | Blocked | 2 |
| INF-03 | Provider configuration: Stripe test webhooks/Connect, PostHog ingestion, email/SMS | Providers | — | — | — | — | — | owner approval; no connectors attached | Blocked | 3 |
| INF-04 | Production deployment on Cloudflare Workers | Infra | — | — | — | — | Worker dry-run passes | owner approval | Blocked | 2 |

## Visual gaps recorded

- The shared location/season selector (`PlayerCompetitionSelector`) renders a light cream panel inside dark player screens. The design system calls for dark charcoal surfaces; restyle it centrally.
- The visitor bottom navigation shows five tabs and wraps at 390px (NAV-01, awaiting the owner's 4- vs 5-tab decision).
- Messaging panel controls inherited low-contrast styles (light "Contact admin support" button, light composer).

## Integration position (recomputed 13 Nov 2026)

- Working head: see `git log -1`. GitHub CI has not run on it; every push is refused with 403.
- **Fully included:** #6, #28, #38, #41, #43, #44, #89, #100, #102, #104, #121, #125, #135, #139, #140.
- **Integrated:** #143 (docs), #138, #117, #116, #136, #141, #120, #137 (test fixed), #111 (defects fixed), plus the generator branch, #124 venues and #91 MOTM (ported).
- **Verified superseded (content already on branch):** #118, #119, #49 (registration safeguards; `registration_safeguards.sql` passes), #64 and #114 (referee Connect; integrated via `eadd1059`).
- **Unique work not yet integrated (recent lineage):** #131, #130, #129/#128 (competing), #122, #115, #113, #112, #110, #106, #105.
- **Superseded / stale (older bases, functionality since reworked on the integration line):** #1, #2, #4, #8, #12, #13, #20, #21, #26, #27, #29, #32, #35, #36, #49, #51–#57, #59, #63, #64, #70, #72–#75, #78, #82, #83, #86, #87, #92, #93 (its unique future-season work is still Not Started here), #94, #103, #108 (docs only).
- **Exact-head CI:** green for #116, #117, #138 and #140. Failed for `feat/round-robin-fixture-generator-2026-11-13` at `24e1fe0` (run 43419405437) and for #137 at `5fb544e` (runs 43448347397/43448362145); both were fixed during integration.

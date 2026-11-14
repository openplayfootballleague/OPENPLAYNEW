# Open Play repository audit — 2026-11-14 (issue #142)

**Auditor:** Claude. **Branch:** `claude/open-play-master-blueprint-rhtuih`, local HEAD after `ea5a70d5`. This
branch contains integration candidate PR #135 (`e7dd1868`), and every Git operation below is
local. **Not yet published:** `git push` and GitHub write calls return 403, because the Claude GitHub
App has no write access.

**Evidence rule:** the status of every item rests on code, a replayed database or an automated check
that was actually run. A specification describing a feature is not evidence that it exists, and a
successful build is not evidence that it works.

## Status scale

| Status | Meaning |
| --- | --- |
| **Missing** | No code path delivers the feature. |
| **Partial** | Some code exists; part of the agreed behaviour is absent. |
| **Implemented** | Code exists, with no automated test evidence. |
| **Auto-tested** | Code plus a passing SQL, unit or e2e test that exercises the behaviour. |
| **Manually verified** | A person checked it in a running environment. None so far. |
| **Owner-accepted** | None so far. |
| **Deployed** | Not established. See [Deployment](#deployment-and-infrastructure). |

The requirement-by-requirement tracker is
[`docs/project-knowledge/completion-register.md`](../project-knowledge/completion-register.md): 84 rows,
each with screen, frontend, backend, security, validation, evidence, commit and weight. Mapped to this
scale, it gives:

| Status | Rows |
| --- | --- |
| Missing | 6 |
| Partial | 14 |
| Blocked | 14 |
| Implemented | 6 |
| Auto-tested | 44 |
| Manually verified / Owner-accepted / Deployed | 0 |

## Checks run for this audit

| Check | Command | Result |
| --- | --- | --- |
| Type-check | `npx tsc --noEmit` | pass |
| Unit tests | `npx vitest run` | 186/186 pass |
| Production build | `npm run build` (Vite, Worker bundle) | pass |
| Clean migration replay | `/var/tmp/harness/ci-replay.sh` (PG16 + Supabase stubs) | 153 migrations apply; 41/41 SQL behavioural tests pass |
| Security assertions | `scripts/verify-security-assertions.mjs` | pass |
| Migration sources | `scripts/verify-migration-source-manifest.mjs` | 99 applied + 54 pending verified |
| Draft parity | `scripts/verify-ci-migration-generation.mjs` | 23/23 identical |
| Generated types | `scripts/verify-generated-types.mjs` (new) | 61 tables / 221 functions / 9 enums match |
| Navigation rules | `scripts/verify-player-navigation.mjs` | pass |
| Edge Function security | `scripts/verify-edge-function-security.mjs` | pass |
| Replayed schema | catalog queries | RLS on 61/61 public tables; 62 policies; 247 `SECURITY DEFINER` functions, none executable by `anon` |
| UI at 390 px, three account states | Playwright, test-only session and stand-in responses | see [visual comparison](../reference-assets/visual-references/README.md#comparison-with-the-current-application-2026-11-14) |
| Browser e2e | `tests/e2e/*.spec.ts` (consent, device acceptance) | not run locally; last green CI on `e7dd1868` (run 43433867395) |

## 1. Frontend architecture and routes

- **Stack:**
  - TanStack Start 1.169.4, React 19.2 and TypeScript 5.9, built with Vite 8.
  - Deployed as a Cloudflare Worker (`wrangler.jsonc`; custom domains `openplayfootball.co.uk` and
    `www`; compatibility date 2026-11-07).
  - Supabase JS 2.80.0.
- **Routes** (`src/routes`, 30 files): public, player, captain, referee and admin route files.
- **Domain logic** lives in `src/lib/{competition,finance,payments,referee,notifications,profile,auth,analytics}`,
  with 186 unit tests.
- **Debt:**
  - `src/routes/admin.tsx` packs 46 RPC calls into a few lines of up to 8,700 characters (lines 63, 169,
    224). The same pattern appears in `captain.tsx:347`.
  - These files mix business logic with presentation, against the AGENTS.md rule to keep business logic
    out of presentation components.
  - `posthog-js`, `posthog-node` and `@posthog/react` use caret ranges, which breaks the "dependencies
    pinned" rule.

## 2. Public workflows

| Feature | Location | Status | Evidence / gap |
| --- | --- | --- | --- |
| Home | `src/routes/index.tsx` | Partial | Marketing hero. Its cream sections break the charcoal direction, and there are no data-driven previews (PUB-01). |
| Match Centre (fixtures, results, table, leaders) | `src/routes/match-centre.tsx`, `src/lib/competition/standings.ts` | Auto-tested | Standings unit tests; D7 points-only tests. Club Leaders requires sign-in, because `anon` cannot run definer functions. |
| League discovery | `src/routes/leagues.tsx` | Partial | Lists locations, leagues and seasons. The Active/Upcoming layout of IMG_0583/IMG_0579 is missing. |
| Team directory and profile | `src/routes/teams.tsx`, `teams.$teamId.tsx` | Partial | No player counts, initials or location scoping (IMG_0580). |
| Join Open Play (public) | `src/routes/join.tsx` | **Missing** | Signed-out visitors are redirected to sign-in (Playwright `out /join`). IMG_0581 is not implemented. |
| Gallery | `src/routes/gallery.tsx`, `supabase/functions/public-gallery` | Implemented | |
| Global header (bell, avatar, location selector) | `src/routes/__root.tsx` | Partial | Logo only on player pages (IMG_0577/IMG_0578). |
| Visitor navigation | `src/components/player-bottom-navigation.tsx` | Partial | Shows 5 tabs that wrap at 390 px; IMG_0581 shows 4. |
| Terms and privacy notice | — | Blocked | Needs legal text (PUB-10). |

## 3. Player registration and Player Hub

| Feature | Location | Status | Evidence / gap |
| --- | --- | --- | --- |
| Account sign-up, sign-in, reset | `sign-up.tsx`, `sign-in.tsx`, `reset-password.tsx` | Implemented | Supabase Auth. Not exercised against a real project. |
| Player registration (DOB mandatory, 16+, guardian consent) | `register-player.tsx`, `src/lib/player-age.ts`, `supabase/functions/guardian-consent` | Auto-tested | `player-age.test.ts`; SQL `age_tier_guardian_consent.sql`, `registration_safeguards.sql`. |
| Emergency contact, declarations, marketing consent (REG-03..05) | `register-player.tsx` (single form) | Missing / Partial | References IMG_0563–IMG_0566 define the 4-step wizard; not implemented. |
| Post-registration "next move" (REG-06) | `join.tsx` | Partial | See IMG_0582. |
| Player Hub | `src/routes/player.tsx` | Implemented | |
| My Fixtures, My Results | `player_.fixtures.tsx`, `player_.results.tsx`, `src/lib/competition/player-matches.ts` | Auto-tested | Unit tests; Playwright with stand-in data. |
| Profile (avatar is the only edit) | `src/components/player-profile.tsx`, `src/lib/profile/avatar.ts` | Auto-tested | Avatar unit tests. Storage policy limits writes to the user's own folder. |
| League table page with Your Team highlight (PH-04) | — | Partial | The table exists in Match Centre only. |
| Notification preferences by category (PH-08) | `player.tsx#notification-preferences` | Partial | PRs #128/#129 compete and neither is integrated. |
| Account retention and reactivation | `admin.retention.tsx`, `supabase/functions/player-account-retention` | Auto-tested | SQL `player_account_retention.sql`, `player_retention_holds.sql`. |

## 4. Captain functionality

| Feature | Location | Status | Evidence / gap |
| --- | --- | --- | --- |
| Team application | `join.tsx` (single form) | Partial | The 4-step wizard (IMG_0568–IMG_0571), drafts, crest, Instagram (PR #122) and versioned declarations are missing. |
| Team sheets (6+3 / 7+4), confirmation | `captain.tsx`; SQL team-sheet RPCs (`Select exactly % starting players`) | Implemented | Team sheets are used inside `registration_safeguards.sql` and `admin_team_sheet_historical_players.sql`. **Gap:** no negative test rejects a 5- or 8-starter sheet, or an over-limit bench. |
| MOTM nominations | `src/components/captain-motm-nominations.tsx`; migration `20261113150000` | Auto-tested | SQL `fixture_motm_nominations.sql`. |
| Team fixture payments | `src/components/captain-team-payments.tsx`, `create-team-fixture-checkout`, `team-stripe-webhook` | Blocked | Owner decision D6: no new card payments without approval (FIN-02). |
| Captain-requested removal needing player approval (CAP-05) | — | Missing | PR #112 is not integrated. |
| Future-season membership and captaincy (CAP-06) | — | Missing | PR #93 is not integrated. |
| Location-wide membership exclusivity (REG-11) | — | Partial | PR #113 is not integrated. |

## 5. Referee functionality

| Feature | Location | Status | Evidence / gap |
| --- | --- | --- | --- |
| Application and admin review | `referee.tsx`, `admin/referees.tsx` | Auto-tested | SQL `referee_application_workflow.sql`. |
| Fixture assignment with availability | `admin/referees.tsx`; migration `20261110133643` | Auto-tested | SQL `referee_fixture_assignments.sql`. Time-of-day flake fixed 2026-11-14. |
| Match reports and corrections | `referee/report.$fixtureId.tsx`, `referee/matchday.tsx` | Auto-tested | SQL `referee_match_reports.sql`. |
| Stripe Connect payouts | `create-referee-connect-account`, `pay-referee-payout`, `process-referee-payout-queue`, `referee-connect-webhook` | Blocked | Gated under D6. Needs test-mode keys and webhooks (INF-03). PR #114's ambiguous-transfer fix was superseded by eadd1059. |

## 6. Administrator functionality

| Feature | Location | Status | Evidence / gap |
| --- | --- | --- | --- |
| Setup: location, league, season, team, player | `admin.tsx` | Auto-tested | SQL scope tests (`location_admin_role_scope.sql`, `authorization_scope_regression.sql`). |
| Fixture generator (single/double round-robin) | `src/components/admin-fixture-generator.tsx`; migration `20261113190006` | Auto-tested | SQL `season_matchday_and_round_robin.sql`. |
| Results, goals, assists, own goals | `admin-goal-events.tsx`; migration `20261113170000` | Auto-tested | SQL `goal_assists_and_own_goals.sql`. |
| Points rules, title final, season completion guard | `admin-season-points.tsx`, `admin-title-final.tsx` | Auto-tested | SQL `season_points_rules.sql`, `title_final_season_completion.sql`. |
| Gameweek postponement | `admin-gameweek-postponements.tsx`, `supabase/functions/admin-postpone-gameweek` | Auto-tested | SQL `weather_gameweek_postponements.sql`. |
| Venues and operating hours | `admin-venue-manager.tsx` | Auto-tested | SQL `location_venues_and_operating_hours.sql`. |
| Disciplinary, guardian consents, retention | `admin-disciplinary-suspensions.tsx`, `admin.guardian-consents.tsx`, `admin.retention.tsx` | Auto-tested | SQL `referee_match_reports.sql` (discipline), `age_tier_guardian_consent.sql`, `player_account_retention.sql`, `player_retention_holds.sql`. |
| Needs Attention task centre (ADM-02) | `admin/analytics.tsx` (counts only) | Partial | PR #110 is not integrated. |
| Searchable registers and side panels (ADM-04) | `admin.tsx` | Partial | |
| Role management and first-admin bootstrap (ADM-06) | `admin-league-admin-roles.tsx` | Blocked | Privileged-role provisioning needs owner approval. Runbook in PR #108. |
| Support case management (ADM-09) | `admin-messages.tsx` (conversations) | Partial | PR #131 is not integrated. |
| Audit history | `admin.tsx` "Audit history" | Auto-tested | `audit_log` writes asserted in SQL tests. |

## 7. Finance and payments

| Feature | Location | Status | Evidence / gap |
| --- | --- | --- | --- |
| Finance ledger and reports | `src/routes/finance.tsx`, `src/lib/finance` | Auto-tested | SQL `finance_balance_semantics.sql`; finance unit tests. |
| Operating costs and business performance | `admin/analytics.tsx` (PR #135) | Implemented | Covered by PR #135 CI. No local SQL test file targets operating costs. |
| Player and team checkout | `create-player-checkout`, `create-team-fixture-checkout` | Blocked | D6. |
| Webhook signature verification | `stripe-webhook`, `team-stripe-webhook`, `referee-connect-webhook` (`constructEvent`) | Implemented | Statically asserted by `verify-edge-function-security.mjs`. No live Stripe test. |
| Fee snapshot on payment requests | SQL obligations | Auto-tested | `team_weekly_payment_workflow.sql`. |

## 8. Messaging and notifications

| Feature | Location | Status | Evidence / gap |
| --- | --- | --- | --- |
| Inbox (D4) | `src/routes/inbox.tsx`, `src/lib/notifications` | Auto-tested | Unit tests plus Playwright. |
| Restricted messaging, reports, blocks | `src/components/messages-panel.tsx`; migration `20261111194000` | Auto-tested | SQL `secure_messaging_platform.sql`. Pagination fix in PR #115 is not integrated. |
| Notification queue and delivery worker | `deliver-notifications`; SQL claim/complete functions | Auto-tested (SQL) | Email/SMS providers not configured (NOT-02, blocked). |
| Push notifications (NOT-03) | — | Missing | PR #130 (OneSignal) is not integrated. |

## 9. Statistics and reporting

| Feature | Location | Status | Evidence / gap |
| --- | --- | --- | --- |
| Player and club statistics, leaders | `match-centre.tsx`; `get_admin_season_statistics` | Auto-tested | SQL `player_transfer_statistics.sql`, `league_points_tie_ranking.sql`, `season_points_rules.sql`. |
| Admin analytics: growth, conversion, engagement, app usage, exports | `admin/analytics.tsx`, `supabase/functions/admin-product-analytics` | Auto-tested | SQL `admin_analytics_user_growth.sql`, `admin_analytics_registration_conversion.sql`, `admin_product_analytics_scope.sql`; Deno `policy_test.ts`. PR #133/#127 history was superseded by #134/#135. |

## 10. Authentication and authorisation

- **Auth:** Supabase Auth.
- **Session isolation across account changes:** `src/components/authenticated-session-boundary.tsx`
  (PRs #116/#117, integrated).
- **Roles:** `user_roles`, plus the helpers `has_platform_role()` and `can_administer_location()`. All
  privileged RPCs are `SECURITY DEFINER` with `search_path=''`. The replay shows 0 `anon`-executable
  definer functions.
- **RLS:** enabled on 61 of 61 public tables, with 62 policies.
- **Evidence:** `verify-security-assertions.mjs`, `authorization_scope_regression.sql` and
  `membership_approval_authorization_locks.sql` (PR #138).
- **Gaps:**
  - The client mode resolution in `player-bottom-navigation.tsx` is presentation only. It is not
    authorisation, and the server checks are what enforce access.
  - No end-to-end test runs against real Supabase Auth.

## 11. Supabase schema, migrations and RLS (reconciliation)

| Previously reported problem | Still present? | Evidence |
| --- | --- | --- |
| Messaging RPCs only in draft SQL | No | The drafts are byte-identical to committed migration `20261111194000`. |
| `admin_record_fixture_result_with_appearances` in types without a migration | No | Defined in committed migrations; exists after replay. |
| Generated types vs canonical migrations | Fixed 2026-11-14 | Types were missing 28 tables, 2 columns and 73 functions, and held 2 stale entries. They now match, and CI runs the verifier. |
| 8 draft-only migrations versioned by CI at runtime | Fixed 2026-11-14 | Committed as `20261113190000`–`20261113190007`. |
| Hosted history vs committed files | **Unverified** | The last record is 99 applied migrations matching the manifest. No Supabase access this session. 54 forward migrations are pending ([list](../migration-integrity-audit-2026-11-14.md)). |

## 12. PostHog and Stripe

- **PostHog:** consent-gated (`src/components/analytics-provider.tsx`, `src/lib/analytics/consent`), with an
  allow-list and GPC support. e2e: `tests/e2e/analytics-consent.spec.ts`, green in CI on `e7dd1868`.
  Ingestion keys and project settings have not been verified (ANA-02, blocked).
- **Stripe:** code paths and signature checks exist (section 7). No test-mode keys are configured and no
  webhook endpoints are registered. Online card payments are frozen by D6.

## Deployment and infrastructure

- **Cloudflare:** Workers Builds ran successful preview builds of `openplaynew` for this commit line
  (check run 131951928240, branch preview `feat-public-team-profiles-2026-11-13`). Custom domains are set
  in `wrangler.jsonc`.
- **Not established:** whether production serves this line. No production deploy has been made or
  approved.
- **Staging:** no environment exists (INF-02, blocked).

## Integration candidate PR #135

- **Head and base:** head `e7dd1868` on `integration/finance-performance-reconciled-2026-11-13`, base
  `628bfd9e` (`integration/app-usage-reconciled-2026-11-13`, PR #134).
- **Head vs base:** head is not a descendant of the current base. The one base commit missing from head
  ("Keep engagement query assertions separate from App Usage") leaves `policy_test.ts` identical to HEAD,
  so no content is lost.
- **CI on `e7dd1868`:** all four jobs succeeded in runs 43433867395 and 43433848421 (2026-11-13 13:28 and
  13:32 UTC):
  - build;
  - clean Supabase replay and security assertions;
  - Chromium responsive/PWA acceptance;
  - PostHog consent.

  Later runs on the same SHA (15:51) were cancelled by concurrency, apart from a successful build.
- **Stack:** `main` ← `integration/complete-product-build` ← #89 ← #109 ← #121 ← #123 ← #125 ← #134 ←
  #135. Children of #135: #136, #137, #138, #139 (← #140) and #143. #141 branches from #109.
- **Working branch:** contains #135 and all of its children. It also adds the round-robin generator,
  MOTM, goals and assists, points rules, the title final, Inbox, and the player screens.

### What must be incorporated before a reliable release candidate exists

Checked by ancestry and patch-equivalence (`git cherry`) against the working branch.

| PR | Content | Status in working branch | Needed for RC |
| --- | --- | --- | --- |
| #110 | Needs Attention task centre | Not integrated | Yes (ADM-02) |
| #112 | Captain removal needs player approval | Not integrated | Yes (CAP-05) |
| #113 | Location-wide membership/captaincy exclusivity | Not integrated | Yes (REG-11) |
| #115 | Messaging equal-timestamp pagination | Not integrated | Yes (correctness) |
| #122 | Team Instagram (supersedes #92) | Not integrated | Yes (REG-08) |
| #128 / #129 | Notification categories (competing) | Not integrated | Pick one (PH-08) |
| #131 | Support case management | Not integrated; stacked on #128 | After the D4 decision |
| #93 | Future-season transitions | Not integrated; old base | Yes (CAP-06); needs a restack |
| #130 | OneSignal push | Not integrated | Later (NOT-03); provider approval |
| #105, #106 | Referee analytics; location-activation test matrix | Not integrated (small) | Desirable |
| #103, #108, #109 docs | Docs-only residue | Not integrated | Review only |
| #91, #124, #94 | MOTM, venues, manual recruitment | Ported (equivalent content) | Done |
| #114, #118, #119, #127, #133, #134 | — | Superseded or equivalent | Close as superseded |
| #75, #78, #82, #83, #86, #87 | Pre-integration lines | Superseded by #89 line | Close after owner review |

## Genuine blockers and dependencies

1. **GitHub write access for the Claude App:** without it, nothing here can be published, CI cannot run
   on HEAD, and #142/#143 cannot be updated.
2. **Hosted Supabase:**
   - A read-only diff is needed to confirm drift.
   - The 54 pending migrations need owner approval and a backup before they are applied.
3. **Official logo asset (D5, issue #18).**
4. **Licensed photography:** the reference images use third-party credited photos. Owner-licensed imagery is needed (all 32 references are now stored).
5. **Provider configuration** (Stripe test mode, Connect, email/SMS, PostHog keys, push) needs owner
   approval (D6, INF-03).
6. **Legal text** for the terms and privacy notice (PUB-10).
7. **Owner decisions:**
   - navigation for signed-in users without a team, and captain navigation;
   - GD column display;
   - drawn final;
   - 3+ teams level on points;
   - support conversations vs D4;
   - the 23:59 availability edge case.
8. **Staging environment** (INF-02).

## Recommended development sequence

1. **Account-state navigation and global header (PUB-08, NAV-01).** Signed-out visitors get 4 tabs
   (IMG_0581). Signed-in users without a team get 5 transitional tabs that must not wrap. Players in a
   team get 4.
2. **Public Join page (IMG_0581, PUB-06)** and the post-registration "next move" (IMG_0582, REG-06).
3. **Find your league and League teams** (IMG_0583/IMG_0579/IMG_0580).
4. **Team registration wizard** (IMG_0568–IMG_0571, REG-07/08). Integrate #122 for Instagram and crest.
5. **Membership rules:** integrate #113, #112 and #93 (restack).
6. **Admin:** #110 Needs Attention; registers and side panels.
7. **Messaging and notifications:** #115, then choose #128 or #129, then #131 after the D4 decision.
8. **Player Hub league table page (IMG_0574)** and data-driven Home.
9. **Release candidate:** publish the branch, get CI green on the exact head, run the read-only hosted
   diff, then hand over for owner acceptance testing.

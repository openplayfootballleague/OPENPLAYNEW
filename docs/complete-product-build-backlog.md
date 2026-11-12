# Open Play New — Complete Product Build

**Umbrella tracker:** https://github.com/openplayfootballleague/OPENPLAYNEW/issues/37  
**Integration workspace:** `integration/complete-product-build`  
**Base snapshot:** `feat/stripe-test-checkout-lifecycle` at `7b8a72e8988fae6a1284462276c77715466c477d`  
**Status:** Build inventory established; feature integration in progress. No merge or release authorised.

## Development operating model

Repeat steps 1–5 continuously:
1. Select the next incomplete requirement from issue #37 and the authoritative product specifications.
2. Implement on a dedicated, dependency-aware branch; integrate into the shared development workspace only after source/ancestry review.
3. Commit code, migrations, tests and documentation.
4. Update issue #37 and the relevant feature issue/PR with exact scope, commit, tests, dependencies and blockers.
5. Move immediately to the next incomplete requirement.

Run targeted checks for changed code and never leave a known failing check unresolved. Defer the complete cross-product acceptance campaign until the scope is assembled. Keep merge, hosted migrations and release behind the later approval gate.

## Product inventory

The complete feature-level checklist, including the 15-section admin workspace, public/player/captain experiences, location/season lifecycle, registration, competition, finance, analytics, communications, gallery, security and release prerequisites, is maintained in [issue #37](https://github.com/openplayfootballleague/OPENPLAYNEW/issues/37). The authoritative admin requirements remain in `docs/admin-dashboard-location-season-analytics-master-specification.md`.

## Current integration risks

- Existing pull requests are based on several different feature branches. Compare ancestry and merge bases; never merge by PR number or title alone.
- PostHog has competing implementations: PR #29 is consent-gated; PR #35 describes a direct provider and identity configuration. Reconcile to one privacy-first design before integration or enabling capture.
- PR #36 initial-squad validation CI failed on three tests because the fixtures did not preserve the nominated captain and did not exceed the maximum squad size. Corrected tests have been committed to the feature branch; rerun and verify the new head.
- Migration reconciliation and role-scope fixes must remain forward-only and replayable in an isolated database. No hosted migration is authorised.
- The exact canonical OP logo binary, approved non-production Auth Admin test identities, SMTP, Stripe test webhook/secrets and provider privacy settings require approved external paths/configuration.
- Notification dispatch remains inactive; no production data, privileged identities, payments, future-location activations or production deployment may be created as part of this build.

## Status vocabulary

- **Implemented:** code exists on a branch.
- **Integrated:** reconciled into the shared development workspace.
- **Verified:** relevant automated and acceptance evidence passes.
- **Released:** explicitly approved and deployed.

Do not conflate these states or claim completion from a successful build alone.


## Pull-request dependency map (reviewed 8 November 2026)

### Baseline family A — application/Stripe feature baseline
These PRs declare the same base SHA `7b8a72e8988fae6a1284462276c77715466c477d`:
- #36 initial squad validation (head `54efcf302ce829d583e59e27a1facdf0bd329635`, CI green). Safe to port as a domain helper; not yet a complete registration feature.
- #29 consent-gated PostHog foundation (head `f9fe77d4f640692798ddfad11190a7f3156be26b`, previously green). Candidate privacy architecture; route/provider/package changes need reconciliation before porting.
- #32 profile self-service permission regression test (head `4239bd5aea5c13d5b0c72ccc9158562ad24820c7`). Candidate security regression test; must be rerun on its own head.
- #28 migration source reconciliation (base SHA differs: `e7a64f32940dedaba16d0e38453d95b188dbce76`). Treat as a separate migration-history integration lane; do not transplant partial files.
- #6 Stripe test checkout lifecycle is the common feature baseline, but it remains a draft and requires test credentials/identities and E2E acceptance.

### Baseline family B — main
- #13 visual system refresh and #12 admin workspace selector both branch from main SHA `8fd92113c97dc696362ac4c3c812270dd0c477bf`. They can be compared against one another and main; do not assume either includes the Stripe/application baseline.
- #35 PostHog wizard branch also targets main. It is a competing analytics implementation and must not be merged with #29. Select #29's consent-first architecture; port only compatible UI/analytics needs from #35 after review.
- #7 Bideford location policy source restoration targets main and is a security-sensitive migration-source recovery. Reconcile against #28's canonical migration inventory, not independently.
- #21 migration recovery targets the feature baseline but starts from a different base SHA; reconcile through #28's applied-ledger manifest.

### Dependent visual/PWA family
- #27 visual refresh targets the Stripe feature branch but GitHub currently reports it non-mergeable; #13 is its head lineage.
- #26 PWA branding targets the visual refresh branch and is also currently non-mergeable; #1 is the underlying PWA/branding source.
- The correct promotion order is main foundation → Stripe/application baseline → visual refresh → PWA branding, with security/migration changes reconciled against the canonical migration lane. This is a dependency map, not permission to merge any PR.

### Integration workspace policy
The integration workspace is a controlled assembly area. Feature code may be ported only after:
1. checking the exact source head and CI evidence;
2. comparing changed files against the workspace baseline;
3. reviewing overlapping route, package, migration and generated-type edits;
4. preserving one canonical implementation where branches compete;
5. running the relevant targeted tests after each port.

The initial-squad helper and tests from PR #36 are now present in this workspace at commits `193fca0b72055d4a3f61b056a72dfe0cb7ac81bb` and `25c6fa4c5d23b4592968c81824e8a7a8a09be539`. The workspace is not yet a complete runnable integration because it is deliberately not pretending that feature branches with different ancestry have been merged.


## Owner-confirmed player, club and weekly match-sheet workflow (8 November 2026)

This is the authoritative workflow. It supersedes any implication that a club creator submits an initial squad.

1. Every player completes individual player registration first.
2. After registration, the player may either:
   - select an existing club and request to join it; or
   - create a club by completing the team/club registration form. The creator becomes captain once the club is successfully created/approved.
3. There is **no initial squad submission form**. Club creation does not collect a starting lineup or a list of substitutes.
4. Other registered players can subsequently request to join a club. The captain accepts or rejects each request. Only players associated with the club for the relevant season may be selected for that club's match sheet.
5. From the first gameweek onward, the captain completes a separate fixture-specific match sheet every gameweek, selecting only players associated with their club. This is not a player-registration or club-registration form.

### Implementation consequences
- Re-scope PR #36's initial-squad helper/tests. They are not an approved product workflow and must not be wired into the registration form or used to require an initial roster.
- Implement the individual player registration → join/create club choice.
- Implement club creation with creator-as-captain.
- Implement join requests and captain accept/reject.
- Implement a fixture-linked weekly match sheet with server-side club membership and fixture eligibility checks.
- Keep player approval, club approval and membership approval as distinct states where the existing security model requires them.


The detailed owner-confirmed acceptance specification is now documented in `docs/player-club-matchday-workflow.md` (commit `20a728799d3563e8359081e7511d5eed90bde66b`). It distinguishes implemented code observations from end-to-end verification and lists the acceptance checks for each phase. The unapproved initial-squad helper and tests were removed from this workspace (commits `ba0e84e53025f2fc8e4d0602b56efdd551e62aff` and `2e79a0fbd87388a62731e7c9958018437f7b26fe`).


### Captain next-fixture sequencing and post-match amendments (8 November 2026)

Implemented on `integration/complete-product-build`:
- Migration `20261108021000_captain_next_required_fixture_and_admin_amendment.sql` adds the server-side next-required fixture resolver, limits the captain fixture projection, enforces captain sheet access/writes at the database boundary, and restricts admin amendments to locked sheets on completed fixtures with a reason and audit record.
- The captain screen automatically selects the first available next-required fixture. Where a user captains more than one club, the remaining choices are limited to one next-required fixture per club, never arbitrary earlier/later gameweeks.
- `supabase/tests/captain_next_required_fixture_regression.sql` adds isolated-database regression assertions for the resolver, guards, projection, sheet reader and amendment safeguards.
- `docs/player-club-matchday-workflow.md` records completed/cancelled/postponed/in-progress progression semantics and post-match admin correction rules.

Verification status: **implemented, not yet verified**. The repository CI workflow does not execute `supabase/tests/*.sql`; the SQL regression file requires replay against an isolated Supabase/PostgreSQL database. The GitHub Actions run lookup for the latest branch head has not yet returned a run. No hosted migration, merge or deployment has been performed.


## Stage 1 — app-wide account foundations

The authoritative Stage 1 scope and live completion checklist is maintained in [`docs/stage-1-account-foundations.md`](stage-1-account-foundations.md). It covers the entire application: account lifecycle, player identity, profile privacy, role/location permissions, protected route/data access, session handling and operational privacy/security policy. Password recovery has been improved so expired links can request a fresh email. Stage 1 remains in progress; unresolved Auth provider configuration, anti-abuse settings, super-admin bootstrap, role matrix and privacy/policy decisions are explicitly tracked. No paid test infrastructure, hosted migration, merge or deployment is authorised.


### Stage 1 permission audit update — 8 November 2026

A read-only catalog audit of the deployed Supabase project is recorded in `docs/stage-1-account-foundations.md` (commit `c2f8df496fcbd2d9fc12b71116004788ecbd5a30`). It confirms owner/admin read boundaries and SELECT-only authenticated grants for `user_roles`, `profiles`, `players` and `team_memberships`, and deny-all/no client grants for `audit_log`. It also identified deployed-policy/migration-source drift in `season_teams`; this must be reconciled against the applied migration ledger before any corrective migration is authored. No hosted changes were made. CI has not yet produced a run/status for the latest docs commit. Stage 1 remains in progress.


## Player Hub verified statistics — implementation update (11 November 2026)

Implemented on `integration/complete-product-build-visual-referee-2026-11-11`:
- Added forward-only migration `20261111201000_player_self_service_statistics.sql` and the typed `get_my_player_statistics(uuid)` RPC.
- The RPC derives the signed-in player's own statistics from their permanent competition identity. It requires an active registered, non-banned account, a statistics-enabled non-anonymised identity and a published season. It counts only actual appearances from locked team sheets, goals from confirmed results and non-voided goal records.
- Season and career totals include appearances, starts, substitute appearances, goals, goals per game, goalkeeper appearances and goalkeeper clean sheets. Career totals follow the permanent competition identity across club transfers.
- Added the statistics panel to Player Hub with responsive cards, season/career totals, loading/error states and an explicit disclosure that assists and Man of the Match are not shown until their audited capture workflows are implemented.
- Added SQL regression assertions for verified season totals, anonymous EXECUTE denial and career totals across a club transfer; added static source assertions for identity, locked-sheet, confirmed-result, non-voided-goal and grant rules.
- Updated generated Supabase function types and the expected pending migration manifest.

Verification: source files and the migration manifest were re-fetched from the branch and the expected implementation markers were confirmed. GitHub Actions Build verification run `43097186184` and Analytics browser acceptance run `43097186187` were created for the latest implementation head `2ce3403734961ac6bb83b90ee396cbd9a2f28487`, but both were still queued at the last check. The SQL regression has not yet been executed in an isolated PostgreSQL replay in this session. Therefore this work is **implemented; automated and database verification pending**, not signed off. No hosted migration, merge or deployment was performed.


### Weather postponement regression isolation — 11 November 2026

Updated `supabase/tests/weather_gameweek_postponement.sql` to create its own active test location instead of selecting a location created by an earlier regression. The old test failed on a clean/reordered test run when no active location existed, despite the test's stated disposable-database scope. The new fixture uses the same explicit location columns as the self-contained feature-management regression. The location is then assigned to the synthetic admin and used for the test league, season and fixtures.

Commit: `538735d64bae6eb53d915ee19fd84f9b3b0cd2e8`.

Verification: source re-fetched and the dependency on pre-existing active location removed. The new commit's Build verification run `43097474686` was queued at the last check; SQL regression execution remains pending. This is a test-fixture correction, not evidence that the full weather migration or refund workflow is verified.


### Canonical weather workflow ported to the visual integration branch — 11 November 2026

Ported the stable-ID weather/gameweek implementation from the workflow branch onto the visual integration branch: stable `season_gameweeks` migration, matching draft and SQL regression, protected `admin-postpone-gameweek` Edge Function, `AdminGameweekPostponements` component, Admin route wiring, RPC types, migration manifest and function JWT configuration. Removed the competing integer-gameweek migration, draft, test, duplicate Admin form and legacy history RPC usage. The component requires explicit confirmation and a replacement kickoff at least 36 hours away; the Edge Function checks an authenticated administrator's location scope, restricts Stripe to test mode, reconciles active/completed checkout state before invoking the postponement RPC, and does not permit a live Stripe secret.

Static source checks and file/draft parity checks are the next verification gate. The stable migration has not yet passed exact-head CI/local SQL replay on this branch, and no hosted migration or live payment action has been performed.


Additional CI coverage: the canonical `admin-postpone-gameweek` Edge Function is now explicitly included in the Deno type-check command, and the security verifier asserts that inclusion. The operational and acceptance runbooks have also been ported to PR #89.


### Disciplinary return review integrated into visual Admin — 11 November 2026

Ported the location-scoped disciplinary return queue migration and Admin component from the workflow branch to PR #89. The UI lists players whose third approved straight-red strike has made them ineligible, requires a reason before approving a return, and states that permanent strike history is retained. The migration enforces administrator/location access, locks the player row during reactivation, writes an audit event and enqueues an in-app notification. The existing referee match-report SQL regression now asserts that a permitted administrator sees the suspended player in the queue; it already exercises reactivation and preservation of strike totals. CI migration generation and the expected migration manifest include this migration. Exact-head SQL replay/build verification is pending.


### Global league-administrator role management integrated — 11 November 2026

Added a global-admin-only role management workflow to complement existing location assignment controls. Eligible existing accounts can be searched; granting `league_admin` requires a reason and creates no location access by itself. Locations are assigned separately. Revoking the role first removes and audits every location assignment, then removes and audits the role. Platform-admin and finance-admin roles are protected, self-role changes are denied, and search/mutations are enforced server-side. The UI is visible only in the global-admin workspace. The existing role/RLS SQL regression now covers search eligibility, finance-role exclusion, grant, separate location assignment, revocation cleanup, audit events, self-change denial and finance-admin denial. CI migration generation and expected-pending manifest are updated; exact-head replay is pending.


### Exact-head CI defects corrected — 11 November 2026

The first clean local migration replay exposed a PostgreSQL PL/pgSQL error in `get_my_player_statistics`: a composite `public.players` row variable was included in a multi-target `INTO` list with a scalar. The migration now fetches the player composite and profile retention status in separate statements. Added the canonical player-statistics draft and explicit pinned-CLI generation/draft-parity steps for both `player_self_service_statistics` and `optional_goal_attribution`. The CI workflow also had double-escaped newline sequences in migration manifest/duplicate-version checks; these are now single shell newline escapes. Exact-head replay and build are rerunning; the earlier 146 unit tests and Deno checks passed, but do not count the previous failed build/replay as green.

# Continuous development session — 8 November 2026 (Analytics foundation)

Branch: `feat/visual-system-refresh-2026-11-08`
Pull request: #13 (open, draft, unmerged)
Latest verified commit at report time: `6f0522da6fe1062781543f71f4e3d9fb03e6168b`
CI run: `42467516708` — passed.

## Completed

1. Added `docs/analytics-section-48-posthog-implementation-spec.md` with the full nine-section Analytics requirements, metric catalogue, global filters, comparison rules, export requirements, event contract, privacy constraints, source-of-truth boundaries and acceptance criteria.
2. Verified the connected PostHog project is EU Cloud (`https://eu.i.posthog.com`) and has Web Analytics, Product Analytics and Session Replay enabled. No token or credentials were committed.
3. Added pure finance analytics calculations in `src/lib/analytics/metrics.ts`:
   - charges/fines as expected income;
   - payments less refunds as net cash received;
   - credits/refunds/payments reducing outstanding team debt;
   - overpayments cannot offset another team's debt;
   - expenditure/profit/margin remain null because expenses are not recorded in the current ledger;
   - reporting windows are start-inclusive/end-exclusive.
4. Added team retention calculation using distinct previous-season teams as the denominator; returns unavailable when no eligible previous cohort exists.
5. Added competition calculations in `src/lib/analytics/competition.ts`:
   - confirmed/published result required to count a fixture as completed;
   - postponed/cancelled/missing-result counts are separate;
   - participation counts distinct eligible registered players who actually appeared, not account holders.
6. Found and fixed a refund sign mismatch in the shared finance calculation helper so it agrees with the Finance database summary. Updated the regression test.
7. Inspected the live PostHog event/property schema and recorded the existing Open Play content-view events, location/league/team context, current UTM dimensions and missing registration/approval/participation instrumentation.
8. Added a role-aware More navigation menu. Account/sign-in, Admin dashboard, Finance and Admin Help destinations are now grouped under More; Matchday remains visible only to active approved captains, and Join Open Play remains state-dependent.
9. Re-ran the full CI after the navigation changes. Run `42467801899` passed Deno Edge Function type-check, all 42 tests, TypeScript/production build and Cloudflare Worker dry-run validation.
10. Updated PR #13 description to record Analytics scope and outstanding gates.

## Verification

Latest CI run `42467516708` passed all jobs:
- Deno type-check of Supabase notification Edge Function;
- `npm test`: 42 tests passed across 5 test files;
- TypeScript check and Vite production build;
- Cloudflare Worker `wrangler deploy --dry-run`.

One first run exposed an incorrect expected value in the new analytics finance test (expected 2,250 pence; correct ledger calculation is 1,750 pence). The assertion was corrected and the latest full CI run passed. Earlier Deno setup transiently returned HTTP 504; retry later succeeded. No outstanding CI failure remains at the latest commit.

## Important limitations / blockers

- The PostHog SDK is not yet installed or initialized. The local execution environment could not reach GitHub/npm, so package-manager installation and lockfile update could not be performed safely in this session.
- The app is deployed on Cloudflare/TanStack Start. The TanStack Start PostHog guide describes Node SDK server setup, but the Cloudflare Worker runtime is edge-based; do not blindly add a Node-only server SDK. Choose an edge-compatible server event transport and keep the PostHog project token server-side where required.
- Consent management, input masking, session replay exclusions and privacy review are not implemented/verified. Replay/autocapture must remain disabled until these controls are in place.
- No analytics route or global filter UI yet.
- No role-scoped aggregate RPCs/data contracts for date/location/league/season reporting yet.
- No PostHog event instrumentation, marketing attribution validation or in-app analytics query API yet.
- No PDF/CSV/XLSX export implementation.
- No live browser/device acceptance, PostHog event ingestion verification or reconciliation against real records.
- No production deployment or database changes were performed.

## Next tasks

1. Integrate the PostHog browser SDK with the verified EU host, environment configuration, privacy/consent gate, stable Supabase Auth UUID identification and reset-on-logout. Resolve the Cloudflare edge-safe server-event architecture before adding trusted backend events.
2. Implement authorised, aggregated Analytics database contracts for location/league/season/date filters, preserving Finance permissions and player privacy.
3. Build the nine-section Analytics admin interface and global filters.
4. Add UTM/QR campaign tracking and instrument conversion/workflow actions with no sensitive values.
5. Add report exports and reconciliation/permission acceptance tests.
6. Complete the previously outstanding logo asset integration, More navigation, account-state navigation verification and all other master-prompt items.
7. Complete production acceptance and deployment only after approval.

## Completion status

This session completes a specification and calculation foundation, not the Analytics feature. No overall project percentage is claimed from these partial foundations; the previous 35% estimate remains provisional and has not been remeasured. Project completion remains well below acceptance because core integrations, role-scoped reporting, UI, exports, privacy review and production verification are outstanding.

## Follow-on continuous development — 8 November 2026

### Additional metric foundations

11. Corrected outstanding-balance semantics: balances are now point-in-time amounts as of the reporting period end and include earlier ledger entries. Period-flow measures (charges, fines, payments, refunds and credits) remain restricted to the selected start-inclusive/end-exclusive window. This avoids incorrectly reporting old unpaid charges as zero in a current-period report.
12. Added a regression test proving earlier charges contribute to the current outstanding balance while transactions at/after the exclusive end are excluded.
13. Added distinct-cohort player retention calculation, returning unavailable for an empty prior cohort, with tests for duplicates and empty cohorts.
14. Added registration growth calculations for distinct registered records, withdrawals, and location-level recruitment counts, plus returning-team cohort counts. Pending/rejected registrations are not counted as registered growth. Added boundary, duplicate and cohort tests.

### CI status

- Commit `96d0e7b4c8a3eb00f945dac7bda7a53fe949e866`: CI passed.
- Commit `2ffb0588954e3ac7396f8ff0ffad74e4d24efe83`: CI passed, including the player-retention test.
- Intermediate commits `779e10e` and `23b998e` failed at the Deno setup action before tests ran; logs show GitHub release download HTTP 504, not an application test failure.
- The registration-growth commits `4953719` and `ce251f4` have a CI run queued at report update time; verification is pending.

### Updated next tasks

1. Verify CI for registration-growth calculations.
2. Integrate PostHog client SDK using package-manager installation and a committed lockfile; add EU host config, consent-gated capture, stable Supabase Auth UUID identify/reset, and pageview handling. Do not enable autocapture or replay before consent/masking/privacy review.
3. Resolve a Cloudflare Worker-compatible trusted server-event transport; do not add a Node-only SDK to the edge runtime without compatibility verification.
4. Design and implement secure, role-scoped aggregate data contracts; do not apply database migrations until the outstanding migration-source reconciliation is complete.
5. Build all nine Analytics sections, global filters and comparison periods.
6. Implement authorised PDF/CSV/Excel-compatible exports and acceptance reconciliation.

The PostHog SDK, UI, aggregate reporting, exports, and end-to-end acceptance remain unimplemented. No production database changes, merge or deployment occurred.

15. Added comparison-window helpers for immediately preceding equal-duration periods and previous-calendar-year periods, including safe leap-day handling. Added boundary and invalid-range tests.
16. CI passed for both registration-growth commits `4953719497dd04963e6c46d8c1fa52cc608a4e03` and `ce251f412aaf8eede5812825cdefba3a75aa85cb`. This verifies the growth implementation and its tests.
17. Added comparison-period helper files `src/lib/analytics/periods.ts` and `src/lib/analytics/periods.test.ts`. CI for this latest addition is queued/in progress and not yet verified.

## Continuous execution follow-up — 8 November 2026, 10:xx UTC

18. Rechecked the 98-row hosted Supabase migration ledger and repository branch ancestry. Current SQL source-file counts: production ledger 98 records, Stripe checkout branch 94 files, main 62 files, visual-refresh branch 63 files. PR #2 (migration reconciliation), PR #6 (Stripe checkout), PR #8 (audit docs) and PR #13 (visual refresh) remain open/unmerged. PR #13 is based on main, not the Stripe branch. This is a material integration gap; do not merge branches independently or assume migration filenames alone resolve it. Updated `docs/supabase-migration-source-recovery-2026-11-08.md` on the recovery branch with this evidence. Six missing applied source files and three unmatched files remain unresolved from the previous recovery audit.
19. Added public individual team profiles at `src/routes/teams.$teamId.tsx`. Public directory names link to the matching season-team profile. The profile filters to approved entries in public active/completed seasons and conditionally renders the team Instagram link only when the validated team URL exists. Added responsive-compatible profile styling. No player/member data is exposed by this route.
20. Updated `docs/team-instagram-profile-feature-2026-11-08.md` to record the individual profile route and its remaining acceptance checks.

### Verification and blockers

- Existing baseline CI at commit `d341295ad9d9f7ae8f88200e5b42e7f5c87d10f2` passed: 61 tests, Supabase Edge Function type-check, TypeScript/production build and Cloudflare Worker dry run.
- New team profile route commits `241d8a6`, `e30cc67`, and `a4accbb` have not yet passed CI. Three workflow attempts failed at the Deno setup step before application tests ran; this is an infrastructure setup failure, not evidence of a code failure. The latest docs-triggered run `42470183329` has been re-run (attempt 2) and is pending.
- No Supabase dev branch was provisioned because the connector requires cost confirmation. No production migration was applied.
- No PR was merged and no deployment occurred.
- Database migration reconciliation, the six original SQL sources, three unmatched source mappings, SQL execution and live role tests remain outstanding.
- The individual team profile has not yet been browser-tested or verified against production RLS.

### Next execution order

1. Complete CI for the individual team profile route; fix any code failures.
2. Continue authoritative migration-source recovery and branch integration planning. Do not synthesize missing originals or merge PRs without preserving the reviewed migration set.
3. Once migration history is reconciled and a safe isolated DB is available, fix security issue #9, then #10 and #11 with role-based regression tests.
4. Continue PostHog SDK/consent integration and Section 48 Analytics UI/data contracts.

21. CI verification for the Instagram team profile feature completed successfully: workflow run `42470183329`, attempt 4, on application commit `a1566308fbe3fc30497981cf6d65e0c04a5c0a1d`. Deno setup, Supabase Edge Function type-check, domain tests, TypeScript/production build and Cloudflare Worker dry run all passed. Attempts 1–3 failed only at Deno download with HTTP 504 before tests. Feature report updated with this evidence.
22. Reviewed the official canonical asset in the Library (`Connected Orange OP Monogram.png`, 781,549 bytes). The GitHub connector supports base64 blob upload but the current tool bridge cannot transfer the mounted binary bytes into that API call. No alternate or AI-recreated logo was committed. Exact asset integration remains an explicit file-transfer task.
23. Rechecked PostHog readiness: no SDK dependency or cookie/analytics consent component currently exists in this branch. The approved Section 48 specification requires consented session replay and privacy controls. No behavioural collection was enabled without the required user-facing consent flow and approved privacy wording.

### Current verified state and next task

- Instagram route + directory link code: CI passed at commit `a156630`.
- Subsequent report-only commits do not change app code.
- Database migration/RLS and browser/device acceptance remain unverified.
- Production migrations, records, PR merges and deployment remain untouched.

**Next highest-priority task:** resolve the development branch integration/migration-history gap. Recover the six missing applied migration sources from an authoritative original source and map the three unmatched files to exact ledger records; then construct a combined feature branch preserving Stripe, Bideford policy, admin-scope and visual-refresh work. Do not synthesize original SQL or merge until the exact source set is reconciled and CI passes.

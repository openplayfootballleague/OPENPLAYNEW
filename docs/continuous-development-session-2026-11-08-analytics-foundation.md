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

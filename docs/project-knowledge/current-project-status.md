# Open Play — Current Project Status

**Snapshot date:** 2026-11-13. This is a point-in-time record, not a live status feed. Recheck GitHub and provider dashboards before acting.

## Development
The repository has active stacked branches and draft PRs. Inspect current open PRs, base/head relationships and exact SHAs before coding. PR #109 was an earlier broad integration candidate; do not assume it remains the latest integration branch.

At documentation creation, the active integration branch observed was integration/finance-performance-reconciled-2026-11-13. This knowledge-base work is on docs/shared-open-play-master-specs-2026-11-13, based on that integration branch. Documentation only; it requires normal review before merge.

## Recent draft work observed
- #141 keyboard focus and reduced-motion support.
- #140 public league/location discovery, stacked on #139.
- #139 public team profiles.
- #138 serialized membership-approval authorization.
- #137 former-player history on historical team sheets.
- #136 registration conversion cohorts in exports.
- #135 App Usage and finance performance integration.
- #134 consented platform App Usage reporting.
- #133 finance-led business performance reporting.
- #131 audited support case management.
- #130 OneSignal push delivery/device management.
- #129 notification category preferences.
All were open draft PRs at the snapshot; this list must be refreshed before coordination.

## External service state previously observed — revalidate
- Supabase Open Play New project in eu-west-1.
- Hosted migration ledger previously showed 99 applied migrations; candidate migrations remained pending hosted application. Isolated CI replay is not hosted deployment.
- Hosted Edge Functions previously included deliver-notifications, create-player-checkout, stripe-webhook and public-gallery. Candidate referee payout functions were not deployed.
- No global-admin or finance-admin rows in the previously inspected role table. No bootstrap without approval.
- Stripe was in test mode; no connected accounts, transfers or webhook endpoints had been created.
- PostHog project OPENPLAYNEW, ID 340435, had no verified custom Open Play event ingestion at last inspection. Recheck.
- Cloudflare is the hosting target. A Worker build/preview is not a production deployment.

## Release gates
Reconcile stacked PRs; prove full feature coverage; resolve role bootstrap; confirm branch protection; configure Cloudflare target/domains; confirm official logo asset; approve staging budget; complete Stripe Connect sandbox roundtrip and payout semantics; configure approved notification providers; verify consented PostHog ingestion; complete physical-device, accessibility, privacy and E2E acceptance; prepare support, monitoring, backup and rollback.

## Progress reporting
Report requirements in scope, implemented, automated-tested at exact SHA, manually verified, owner-accepted and deployed separately. Do not claim a percentage without a defined requirement inventory and defensible status for every item. CI passing is not feature-completion proof.

# Open Play — feature completion inventory (13 November 2026)

**Scope:** Canonical integration candidate PR #109.  
**Purpose:** Evidence-led reconciliation against the authoritative product specification.  
**Status:** Working inventory, not an acceptance sign-off.  
**Rule:** A visible route or passing CI check does not by itself mean a feature is complete.

## Verified integration baseline

- PR #109 is an open draft integration candidate; it is not merged.
- Exact candidate head at the time of this inventory: `9938b018c495791430f85d3ca2525a233fa555ae`.
- The immediately preceding exact head `60c45903bb72856422a1b23ac09b3e3e200c6556` passed all four CI jobs in run [#43450775828](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/43450775828). The inventory commit itself still requires its own CI run.
- Hosted Supabase remains at 99 migrations; 38 candidate migrations are pending and have only been replayed in isolated CI.
- Hosted Supabase has four deployed Edge Functions; the candidate referee payout and Connect webhook functions are not deployed.
- Stripe test-mode account has zero connected accounts, transfers and webhook endpoints.
- No production deployment, hosted migration, role provisioning, Stripe resource creation or payment is authorised by this inventory.

## 1. Admin information architecture

The 15 required navigation labels are present in `src/routes/admin.tsx`:

1. Dashboard
2. Locations & Competitions
3. Seasons
4. Team Approvals
5. Player Approvals
6. Teams & Squads
7. Players
8. Fixtures
9. Team Sheets
10. Results & Match Events
11. Finance
12. Analytics & Reports
13. Communications
14. Gallery
15. Settings & Feature Management

**Important qualification:** presence of a navigation item is not proof of a complete department. Communications is rendered as unavailable to non-global administrators; Finance is linked to its own route. The analytics department is a separate `/admin/analytics` route.

## 2. Analytics & Reports — evidence and gaps

### Existing implementation

- `src/routes/admin/analytics.tsx` provides ten tabs: Overview, App usage, User growth, Registration, Engagement, Feature performance, Locations, Competition, Business, Reports & exports.
- The route loads administrator context and contextual dashboard/fixture data through Supabase RPCs.
- `src/lib/analytics/overview.ts` derives counts for locations, leagues, seasons, approved teams, current squad memberships, fixtures, completed scored results, goals and outstanding approval queues.
- Competition statistics are loaded from the existing season-statistics RPC.
- Location comparisons use accessible location/season/team/fixture records.
- Finance summaries are permission-gated and derived from the finance ledger RPCs.
- CSV and print/PDF summary actions exist; the export deliberately excludes player names, contact details, dates of birth, message content and payment references.
- The analytics page explicitly labels unavailable product analytics rather than fabricating figures.

### Not yet complete

| Area | Verified current state | Work still required |
|---|---|---|
| App usage | Explicit unavailable state | Connect consented PostHog events to the reporting workspace; show real unique users, sessions, page/section activity and device/browser trends |
| User growth | Explicit unavailable state | Add an authorised account-creation aggregate and PostHog first-time/returning cohort trends; distinguish account signup from player registration |
| Registration | Current pending queues and approved-team count | Build the full funnel and conversion/drop-off from consented events plus authoritative Supabase approval outcomes |
| Engagement & retention | Explicit unavailable state | Implement meaningful activity definitions, repeat use and 1/7/30-day cohort retention from verified event history |
| Feature performance | Explicit unavailable state | Build feature-level adoption, repeat interaction, outcome and failure measures from governed event taxonomy |
| Location comparison | Competition counts by accessible location | Add comparable active users, registration conversion, retention, participation and finance measures with equivalent-period controls |
| Competition performance | Season results, goals, standings and player count | Add participation rates, squad capacity, progress and season-over-season comparisons |
| Business performance | Ledger charges, payments, refunds, fines and outstanding balance | Add recorded operating costs, sponsorship income and defensible net operating surplus; do not infer unrecorded costs |
| Reports & exports | Aggregate CSV and print/PDF summary | Add reusable report definitions, date/period comparisons, complete scoped report coverage and export acceptance |

### PostHog project inspection

Read-only inspection of the connected PostHog project identified:

- Project name: `OPENPLAYNEW`.
- Project ID: `340435`.
- Project timezone: UTC.
- PostHog reports `ingested_event: false`.
- The event-schema reader lists only built-in PostHog events; none were seen in the last 30 days. No Open Play custom event has yet been verified as ingested.
- Project-level settings show IP anonymisation enabled and session recording disabled. Do not enable replay/autocapture as a shortcut.
- The application provider requires `VITE_POSTHOG_PROJECT_TOKEN`, `VITE_POSTHOG_HOST` and `VITE_POSTHOG_PRIVACY_SETTINGS_VERIFIED=true` before it mounts PostHog after explicit consent.
- The app event allow-list exists in `src/lib/analytics/events.ts`; it rejects unapproved properties and excludes admin/finance actors from product analytics.

**Conclusion:** The consent-aware SDK integration and event taxonomy are present in the candidate, but production-like event ingestion is not verified. The analytics tabs for app usage, user growth, engagement and feature performance are intentionally honest placeholders, not completed reporting features.

### Required next steps for analytics

1. Confirm the intended PostHog project and its privacy configuration with the owner; do not expose or copy privileged API credentials into the browser.
2. Verify the three required Vite build variables are configured in the intended non-production deployment without disclosing secret values.
3. Add/verify event capture at the actual user action boundaries for signup, verification, profile completion, team/player registration, location/season switching, navigation and key feature outcomes.
4. Keep explicit opt-in, Global Privacy Control, actor gating, event/property allow-lists and analytics identity reset on logout/account changes.
5. Verify a synthetic consented event arrives in the intended PostHog project, then verify opt-out and GPC produce no event. Use a non-production test identity and no personal data.
6. Build real PostHog-backed trends/funnels/retention/feature reports; build account, competition and finance truth from permission-checked Supabase aggregates.
7. Show reporting period, timezone, last refresh, coverage and data delay. Never render missing data as zero.
8. Add tests for metric definitions, role/location scope, data-source boundaries, export privacy and consent revocation.

## 3. Other admin departments — next audit pass

The admin route contains operational implementations for location/league/season creation, approval queues, team/player registers, fixture scheduling, team-sheet review/amendment, result entry, season statistics, notifications, gallery and feature controls. These must now be audited against each specification workflow, not counted complete from their route presence.

Specific evidence-based follow-up checks:

- **Locations & Competitions:** current UI has basic location creation, league creation and draft season creation. The master specification additionally requires venue management, guided review, robust identifiers, timezone/operating-day configuration, conflict handling and complete lifecycle audit.
- **Seasons:** verify independent lifecycle and recruitment state, manual-only activation, previous-season final fixture plus published-result gate, and no future memberships.
- **Approvals:** verify full pending/approved/rejected/history registers, age/guardian workflows and direct RPC authorization.
- **Teams & Squads / Players:** verify pagination/search, historical memberships, captain succession, bans, retention/erasure and all player-statistics requirements.
- **Fixtures:** verify round-robin generation, calendars, gameweeks, venue constraints, referee allocation, postponement, rescheduling and audit history.
- **Team Sheets:** verify format-specific starters/substitutes, eligibility, both teams, late amendments, locked historical records and referee report dependencies.
- **Results & Match Events:** verify scorer/appearance attribution, cards, disciplinary actions, walkovers, publication, correction and safe statistics recalculation.
- **Finance:** verify hosted payment reconciliation, refunds, credits, weekly team fees, referee entitlements, Connect transfer reconciliation and audit history.
- **Communications:** verify announcement lifecycle, message permissions, delivery status, retry/hold, consent and notification dispatch safeguards.
- **Gallery:** verify media privacy, location scoping, publish/unpublish, storage policy and removal/audit.
- **Settings & Feature Management:** verify every advertised control has a real permission-checked server action; record the owner decision for Super Admin role authority before provisioning.

## 4. Release gates — remain blocked

- Owner-approved first Super Admin identity and role model.
- Protected GitHub branch/review process and review of the integrated candidate.
- Confirm exact Cloudflare/Vercel deployment targets and canonical supplied logo asset.
- Owner-approved isolated staging budget/environment.
- Staging-only deployment of pending migrations/functions and secret configuration.
- Stripe test Connect onboarding, £22 entitlement/transfer and signed webhook round trip, including ambiguity/reversal scenarios.
- Confirm payout policy around the £22 gross amount and £20 minimum-net wording.
- Email/SMS delivery round trips in staging.
- PostHog consented event ingestion and opt-out/GPC acceptance.
- Full manual acceptance on physical iPhone/iPad and desktop.
- Full feature-by-feature acceptance against the complete Open Play master specification.
- Explicit owner approval before any merge, production migration or deployment.

## 5. Working completion rule

Do not assign a percentage based only on CI, changed-file count or route count. A feature is complete only when its requirement is mapped to its UI, server/database action, permissions, error/empty states, audit/privacy behavior and appropriate automated plus manual acceptance evidence. Keep implemented, partially implemented, blocked and accepted states distinct.

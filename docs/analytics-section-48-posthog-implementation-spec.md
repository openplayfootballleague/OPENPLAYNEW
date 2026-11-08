# Open Play Analytics — Section 48 implementation specification

Status: approved product requirement; implementation and acceptance remain outstanding.

## 1. Product boundary and sources of truth

Analytics is a dedicated administrator-only business-intelligence area. It is separate from Football Statistics and Finance.

- **Supabase/Open Play database is authoritative** for players, genuine/approved player status, team applications and season-team entries, memberships, fixtures, confirmed results, team sheets and appearances, finance ledger entries, location/league/season definitions, audit history and administrative workflow states.
- **PostHog is authoritative for product and marketing behaviour it actually receives**: website/app visits, page and funnel behaviour, acquisition/referral attribution, campaign UTMs, session activity, returning usage, engagement frequency, navigation paths, web performance, consented session replay, frontend exceptions, surveys, feature-flag/experiment exposure and other instrumented product events.
- Do not add PostHog event totals to Supabase record totals. Do not treat a PostHog person as a registered player, a login as a match appearance, a pageview as a registration, or a captured payment event as a finance ledger transaction.
- Finance cards reconcile to the append-only finance ledger. A charge is expected income; only a recorded payment is received income. Refunds and credits reduce received/net income according to a documented calculation. Outstanding balance is derived from charges/fines less payments/refunds/credits and must reconcile with Finance.
- All cross-source measures must state their source, definition, reporting period, timezone, freshness and completeness. If sources cannot be reconciled, show a warning and do not silently merge them.

## 2. Admin navigation

Create an Analytics area with these nine subsections:
1. Analytics Overview
2. Business Performance
3. Growth & Recruitment
4. Player Engagement
5. Competition Performance
6. Marketing Performance
7. Location Performance
8. Season Comparisons
9. Reports & Exports

Analytics must have a dedicated admin route and navigation entry. Access must be enforced by server/database authorization, not merely hidden navigation. Respect platform, location, league and finance permissions. A finance-only role must not gain access to unrelated private player data by entering an Analytics URL.

## 3. Global filters and reporting contract

Global filters:
- scope: organisation / location / league / season;
- location, league and season selectors, populated from actual records;
- reporting date range and comparison mode: previous period, previous season, previous year or selected custom period;
- reporting timezone, defaulting to the configured organisation timezone once explicitly established.

Filters must be applied consistently to every card, chart, table, drill-down and export. Changing a parent scope resets invalid child selections. Historical/archived seasons remain selectable for reporting but are labelled archived/completed. Ongoing seasons must not be presented as completed or compared as if their durations were equivalent. For comparisons, use equivalent elapsed windows or disclose the mismatch.

Every metric has a definition, source, scope, grain, date field, null/zero handling, permission requirement, and drill-down destination. Display unavailable, partial, stale and zero as distinct states. Never render missing data as zero.

## 4. Metric catalogue

### 4.1 Executive overview

**Business (Supabase Finance ledger):**
- gross charges / expected income;
- payments actually received;
- refunds;
- credits;
- fines;
- net received income;
- recorded expenditure (only once an expenditure ledger category/source exists);
- net operating profit and profit margin (unavailable until all relevant income and expenditure are represented);
- outstanding balances;
- revenue/payment trend by month, season, location and competition.

**Growth (Supabase registers, not PostHog persons):**
- approved season-team entries;
- new team entries in period;
- new player registrations by status;
- registered and genuine players as separate counts;
- returning teams across comparable seasons;
- team retention rate with explicit eligible-cohort denominator;
- registration withdrawals/rejections and pending queues.

**Operations (Supabase competition records):**
- active competitions and seasons;
- fixtures scheduled;
- completed fixtures with confirmed/published result;
- postponed and cancelled fixtures;
- fixtures awaiting result publication;
- fixture completion rate with explicit denominator and cancellation policy;
- missing/incomplete team sheets or registration records where the underlying workflow exposes them.

**Engagement (two distinct measures):**
- PostHog active/returning product users and engagement frequency;
- Supabase players who appeared in confirmed matches during the configured participation window;
- player participation rate = distinct eligible genuine registered players with a confirmed appearance / eligible genuine registered players in the selected scope and period. Account activity alone never qualifies as football participation.

Each overview metric links to its filtered report/register where permissions allow.

### 4.2 Business Performance

Supabase-led:
- income by season, location, league/competition, month and year;
- team entry charges, other recorded charges, fines, payments, refunds and credits;
- actual cash received versus expected/charged income;
- outstanding balances and ageing only when due dates support it;
- expenditure by category only when expenditure records are captured;
- net operating profit and margin only when all relevant costs are recorded.

PostHog may contribute campaign/source context to acquisition reporting but never financial amounts unless a separately verified transaction integration is introduced and reconciled to Finance. No online payments or Stripe connection is implied by this specification.

### 4.3 Growth & Recruitment

Supabase-led:
- new team applications, approvals, rejections and withdrawals;
- approved season-team entries;
- new player registrations, approved registrations, pending reviews, rejected registrations and withdrawals;
- team/player growth over time and by location/league/season;
- returning teams and team retention by eligible season cohort;
- player retention only where stable player identity and comparable participation/registration windows support a valid denominator.

PostHog-led:
- landing/home visits;
- Join Open Play / team registration / player registration page visits;
- registration form started, validation failed, submitted, completed/approved where safely instrumented;
- funnel conversion and step drop-off;
- campaign, UTM source/medium/campaign/content/term, referrer and QR attribution;
- anonymous-to-authenticated conversion where consent and identity policy permit linking.

Never claim PostHog alone proves an approved player/team registration. The authoritative completion event comes from the database workflow.

### 4.4 Player Engagement

Supabase-led:
- registered/genuine/non-banned player counts;
- distinct players with confirmed fixture appearances;
- appearances, starts and substitute appearances;
- participation frequency by reporting window;
- player registration trends;
- membership requests, approvals, departures, suspensions and transfers;
- retention only with a stated cohort definition.

PostHog-led:
- active product users, new/returning users, lifecycle buckets;
- sessions and engaged sessions;
- engagement frequency/stickiness;
- key navigation paths and feature usage;
- visits to Player Hub, Match Centre, Teams and Matchday;
- use of availability, team-sheet, notification preference and transfer request workflows (action events only, no private form values).

Business reporting is aggregated. No player-level behaviour, sensitive profile attributes, emergency contacts, date of birth, phone, email, private notes or raw session replay is exposed in Analytics. Any individual drill-down must route to an existing authorised register and enforce its own access controls.

### 4.5 Competition Performance

Supabase-led:
- approved participating teams and genuine eligible players;
- fixtures scheduled/completed/postponed/cancelled;
- confirmed results and results awaiting publication;
- fixture completion rate;
- team registration completeness and pending approvals;
- team-sheet submission/lock completion;
- missing roster, result or administrative steps;
- season registration capacity/utilisation where capacity is configured.

PostHog can show usage of competition workflows (e.g. Match Centre visits, Matchday access, availability updates, team-sheet draft/submission actions) but cannot replace the operational record.

### 4.6 Marketing Performance

PostHog Web Analytics and instrumented product events:
- unique visitors, pageviews, sessions, bounce rate and session duration;
- top landing pages and page paths;
- referrers, traffic source, medium, campaign and UTM dimensions;
- device/browser/OS and country/region breakdowns where available and privacy-appropriate;
- visits to registration entry points;
- registration funnel starts, validation errors and confirmed conversion;
- campaign and QR-code referral performance (distinct UTM campaign parameters per print placement/location);
- website performance/Core Web Vitals: LCP, INP, CLS, FCP and TTFB where available;
- web error rates and affected routes where error tracking is enabled.

Social impressions, likes, reach and follower growth are unavailable unless an authorised social-platform integration supplies them. Do not infer them from link clicks. QR referrals require tagged destination URLs. UTM naming conventions must be documented and consistently applied.

### 4.7 Location Performance

Supabase-led per location:
- active leagues and seasons;
- approved teams and eligible registered players;
- actual finance ledger income, expenditure and outstanding balance;
- profit only when cost coverage is complete;
- team retention and player growth using consistent cohorts;
- scheduled/completed/postponed/cancelled fixtures and completion rate.

PostHog-led per location:
- tagged landing/QR visits and registration funnel performance;
- visits and product engagement where location context is legitimately known (e.g. explicit selected location), not inferred from sensitive or imprecise geolocation.

New locations automatically appear from database records. No hard-coded Bideford-only analytics dimension.

### 4.8 Season Comparisons

Compare:
- team entries and returning teams;
- registered/genuine players and player retention;
- actual received income, refunds/credits, charges and recorded expenditure;
- profit only where comparable cost coverage exists;
- scheduled/completed/postponed/cancelled fixtures;
- results publication and team-sheet completion;
- distinct players with confirmed appearances and participation frequency;
- PostHog visits, acquisition funnels and product engagement when event history covers both seasons.

Show season status, start/end dates, elapsed/total duration and the exact comparison window. Avoid comparing a partial current season to a completed full season without a like-for-like window.

### 4.9 Reports & Exports

Report templates:
- financial performance;
- team growth/recruitment;
- player growth/recruitment;
- location comparison;
- season comparison;
- competition operations;
- marketing performance.

Support PDF, CSV and Excel-compatible export. Every export includes generated-at timestamp, timezone, filters, comparison period, metric definitions, data source and completeness warnings. Exports must enforce the same server-side permissions as on-screen data and exclude private player fields by default.

## 5.1 Existing PostHog event inventory (verified 8 November 2026)

The connected project's event schema currently includes these Open Play product events:
- `league_table_viewed`
- `results_viewed`
- `fixtures_viewed`
- `player_stats_viewed`
- `team_profile_viewed`
- `gallery_viewed`
- `gallery_photo_viewed`
- `$pageview`

The existing custom event schemas include public context such as `location`, `league`, and where relevant `team`; they also expose UTM/referrer and device/browser context. The inspected event schemas expose `utm_source`, `utm_medium`, and `utm_content`; `utm_campaign` was not present in the inspected property schema and must be added/verified before campaign-name reporting is promised.

The project schema also lists `$web_vitals`, `$exception`, `$identify`, and other standard PostHog system events, but the schema snapshot explicitly marks them as not seen in the last 30 days. Treat those capabilities as available event types, not as evidence that Open Play is currently collecting usable data for them. Web Vitals, exception monitoring, identity linkage and session replay therefore need integration and ingestion verification before their cards can show values.

The current product events support a first layer of content/competition interest reporting (table, results, fixtures, player stats, team profiles and gallery). They do not yet establish signup/registration funnel conversion, payment, membership approval, player participation or team retention. Those outcomes must come from explicit new instrumentation and/or authoritative Supabase records. Existing location/league/team labels must be normalised to stable opaque IDs before they are used as cross-system filter keys; do not assume the current text labels are canonical identifiers.

## 5. PostHog product instrumentation contract

Use PostHog's React/web SDK only after the correct project token and cloud region are configured. Keep credentials in environment/Worker secrets as appropriate; never hard-code tokens. Do not collect passwords, form contents, full names, DOB, contact details, emergency contacts, private notes, payment references or other sensitive personal/financial fields.

Use the Supabase Auth UUID as the stable PostHog distinct ID only after authentication; do not use email as distinct ID. Identify once the authenticated session is known, reset on sign-out, and avoid setting personal profile properties unless there is a documented lawful need. Prefer coarse, non-identifying properties.

Recommended event names (capture actions, not duplicate pageviews):
- `account_signup_completed`
- `account_login_succeeded`
- `account_logout`
- `player_registration_started`
- `player_registration_submitted`
- `team_application_started`
- `team_application_submitted`
- `team_application_decision_recorded` (server/database authoritative)
- `membership_request_submitted`
- `membership_request_decision_recorded` (server/database authoritative)
- `transfer_request_submitted`
- `transfer_request_decision_recorded` (server/database authoritative)
- `player_hub_opened`
- `match_centre_opened`
- `team_directory_opened`
- `matchday_opened`
- `fixture_availability_updated`
- `team_sheet_draft_saved`
- `team_sheet_submitted`
- `notification_preferences_updated`
- `location_selected`
- `season_selected`
- `registration_validation_failed` (error category only; never field values)
- `admin_workflow_action_completed` (allowlisted action category only; no private payload)
- `qr_campaign_landing` (normally derived from tagged landing traffic, not duplicated unnecessarily).

Allowed event properties, only when needed:
- opaque location_id, league_id, season_id;
- public route/page category;
- workflow type and outcome/status category;
- competition format;
- campaign UTM source/medium/campaign/content/term;
- error category/code without raw user input;
- device/browser properties provided by PostHog under the approved privacy configuration.

Do not send raw names, emails, phone numbers, player IDs, team-sheet contents, scores linked to individual identities, finance amounts, payment references, DOB, or free-text notes to PostHog. Keep business record detail in Supabase and return aggregated results to Analytics.

Server/database events are required for final authoritative state changes. They must use a trusted server-side PostHog integration or another verified server-side event path, with idempotency and no service-role key in the browser. Client events may measure starts, navigation and user interactions; they must not be treated as final approval/completion unless reconciled with the database.

## 6. Privacy, consent and security

- Determine and document the lawful basis and consent requirements before enabling non-essential analytics, cookies, autocapture, session replay or surveys for UK users.
- Respect the site's consent choice and opt-out. Do not enable broad autocapture or session replay by default until privacy review, masking, exclusion rules and consent gating have been verified.
- Mask all form inputs and sensitive/private pages; exclude authentication, Player Hub private details, registration details, finance and admin private data from replay unless a separate approved design proves safe.
- Disable capture of text input values and redact URLs/query strings that may contain tokens or personal data.
- Avoid capturing sensitive user data in error payloads, exception messages, console logs or event properties.
- Use least privilege and role-scoped database RPCs for analytics aggregates. Do not expose service keys or unrestricted PostHog API keys in client code.
- Analytics route and each report must be authorised server-side. Finance metrics require finance permission; platform metrics require platform admin; location/league scope must be enforced.
- Record metric provenance and query versions. Review data retention and deletion workflows with the privacy notice before launch.

## 7. Analytics interface

Use the established Open Play charcoal/orange visual system. Provide compact metric cards, trend/comparison indicators, a small number of meaningful charts, accessible data tables and drill-down links. Include loading, empty, unavailable, partial, stale and error states. Provide metric-definition tooltips or a compact methodology drawer. No fabricated demo numbers in production.

## 8. Acceptance and reconciliation

1. Location filter changes every relevant database and PostHog result.
2. League and season filters propagate consistently.
3. Date range and comparison calculations use the stated timezone and exact period.
4. Finance actuals reconcile exactly to Finance ledger entries; unpaid charges are not receipts.
5. Team totals reconcile to the Teams Register and approved season-team entries.
6. Player totals reconcile to the Players Register using the selected registration/genuine cohort.
7. Fixture totals reconcile to Fixtures and confirmed result state.
8. Participation reconciles to confirmed team-sheet appearance records, not account logins.
9. PostHog visitor/session/funnel/referrer metrics reconcile to the same PostHog project, filters and time range.
10. Missing events/integrations/permissions produce explicit unavailable/partial states.
11. Exports reproduce the on-screen filters and calculations.
12. Finance-only, location-scoped, league-scoped, non-admin and signed-out accounts cannot access unauthorised reports.
13. Privacy/consent controls, masking and session-replay exclusions are tested before activation.
14. Test and production projects/environments are distinguishable; test traffic is excluded from business reporting where configured.

## 9. Delivery gates

- Connected PostHog project metadata has been verified: EU Cloud ingestion host is `https://eu.i.posthog.com`. The project token is available through the connected project configuration; provision it as `VITE_PUBLIC_POSTHOG_PROJECT_TOKEN` in the app build environment and never commit the real value to source control. Provision `VITE_PUBLIC_POSTHOG_HOST=https://eu.i.posthog.com` through the environment as well.
- Add SDK via package manager and lockfile, configure environment variables and proxy/host correctly for Cloudflare/TanStack Start.
- Implement consent-aware provider, auth identify/reset, pageview policy, event catalogue and server-side authoritative events.
- Implement analytics data contracts/RPCs with location/league/season permission enforcement and reconciliation tests.
- Build all nine admin sections and global filters.
- Build PDF/CSV/XLSX exports and verify role-scoped output.
- Run automated tests, CI, browser tests at phone/iPad/desktop sizes, PostHog event verification and database reconciliation.
- Do not activate session replay/autocapture or publish privacy changes without the required privacy/legal review.

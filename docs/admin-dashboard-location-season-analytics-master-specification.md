# Open Play — Master Admin Dashboard, Location & Season Management Specification

**Status:** Authoritative product requirement  
**Priority:** Critical platform architecture  
**Initial operating location:** Bideford only  
**Future locations:** Barnstaple, Torrington and other areas remain draft/unpublished until explicitly launched  
**Platforms:** Existing Open Play web application and PWA  
**Backend:** Existing Supabase application; PostHog for product analytics only

This document consolidates the supplied Location & Season Management System, Master Administrative Dashboard, Category Overview and Analytics requirements. It is an addition to the existing Open Play master development prompt, not permission to replace working features or alter production.

## 1. Product objective and governing rules

Deliver one integrated, secure, responsive league-management platform. The location, league and season context must govern every applicable administrative query, register, metric, action and export.

Preserve existing authentication, account-state, Player Hub, Captain Hub, competition rules, team/fixture workflows, audit history, finance safeguards, notification controls and the canonical supplied orange connected OP logo. Reuse existing database entities and RPCs. Do not duplicate player accounts, teams, seasons, fixtures or finance records.

Do not use mock figures or invented operational data in the live application. Do not expose unfinished controls as working features. Every visible action must have a real, permission-checked destination and a verified outcome.

Production remains Bideford-focused. Do not publish or activate Barnstaple, Torrington or other future locations merely because they have been configured.

## 2. Domain hierarchy and isolation

The three domain concepts are distinct:

- **Location:** geographical operating area.
- **League:** competition belonging to a location; one location may eventually contain multiple leagues.
- **Season:** dated competition instance belonging to a league and location.

Required hierarchy: **Location → League → Season → season-specific teams and memberships, fixtures, results, statistics, registrations, configuration and financial records.**

A player account is a persistent identity; a player's participation is season-specific. A team may return in multiple seasons, but each season's team profile, squad, captaincy, fixtures and statistics remain independently recorded. Historical seasons must not be overwritten by current-season changes.

Inspect the existing schema before implementation. Extend existing location, league, season and season-team relationships where possible. Add foreign keys, uniqueness constraints, indexes and database validation for valid parent-child relationships. A selected location/season is never a substitute for server-side authorization.

### Initial operating state

- Bideford is the only active/public operating location for the initial release.
- Barnstaple and Torrington may exist as drafts or unpublished records but must not be publicly accessible or accept registrations.
- Creating a location does not create or publish a league or season automatically.
- Activating a location does not open registrations.
- Registration opens only through an explicit, authorised season configuration change.

## 3. Player and public location/season experience

### Location selection

When location choice is required, show a clear responsive selection screen with large accessible cards containing location name, venue/supporting information, competition context and explicit status. The entire card is selectable by pointer, touch and keyboard. Selected state must be programmatically exposed and not communicated by colour alone.

Show only available active/public locations to ordinary users. If future locations are shown, label them accurately as Coming Soon / Not Yet Active / Registration Not Open and disable entry.

After selection, validate location availability and user access, then load the location's available leagues and seasons. Preserve signed-out public browsing and all existing account-state rules. Account creation alone does not register a player or grant captain/admin privileges.

Remember the last valid selection where appropriate. Revalidate it on return; if it is no longer available, explain and offer the available locations. Provide a clear switch-location action. Switching must clear or reload all location/league/season-scoped data and must never carry team, fixture, registration or finance data across contexts.

### Season selection

Location selection and season selection are separate steps. Keep competition lifecycle separate from recruitment state. Competition lifecycle is Draft, Upcoming, Active, Completed or Archived; recruitment state is Closed, Open or Closed After Opening. Do not infer either state from dates alone.

- Draft/Upcoming: read-only preview while recruitment remains closed.
- Open recruitment: accept configured player and team registrations only after explicit authorised Admin activation.
- Active: current competition activity; recruitment may remain open or be closed.
- Completed: historical read-only experience except authorised audited corrections.
- Archived: retained history, never an active competition.

Upcoming seasons remain inactive and closed to all registrations. Do not create pending future memberships or advance team applications.

No location with no seasons or no active season should produce a broken or blank screen; explain the state and provide a safe return path.

## 4. Location, venue, league and season administration

### Location register

Provide a searchable, filterable, sortable register with name, identifier/slug, primary venue, league and season counts, current active season, status, created/updated timestamps and available actions. Filters: All, Active, Inactive, Draft, Archived. Sort by name, created date, status and last updated. Search name and identifier.

### Guided location creation

Use a guided workflow with validation and a review step:

1. **Basic details:** required name and unique identifier; optional description, town/area and public description. Prevent duplicate identifiers and warn/reject accidental duplicate names.
2. **Venues:** primary venue name, address, postcode, optional map location, contact details and venue information. Support multiple venues per location.
3. **Operating information:** preferred matchday, match start/end, Europe/London default timezone, normal operating hours and private admin notes. Never hard-code Friday for every location.
4. **League:** create a league within the location; configure name, format, team/squad limits, match duration, points/table rules, venue and operating day. Reuse existing competition rules; do not invent new rules.
5. **Season:** name, start/end, registration opening/closing, status, team entry limits and season-specific settings. Do not publish automatically.
6. **Review and save:** complete summary, publication status and Back / Save as Draft / Create actions. Confirm only after database success.

### Lifecycle and safety

Authorised administrators may view, edit, activate, deactivate and archive. Activation does not open registrations. Deactivation blocks new public participation/registrations as configured while preserving accounts, teams, memberships, results, finance and audit history. Archiving preserves history. No ordinary permanent-delete action for a location with dependencies. Exceptional deletion requires elevated authorisation, dependency checks and explicit confirmation.

Record who created/edited/activated/deactivated/archived, when, what changed and relevant reason in the existing audit system. Protect against concurrent edits and stale writes; show conflict and recovery rather than silently overwriting another administrator's changes.

## 5. Unified administrative dashboard

Build one central admin workspace, not disconnected location-management pages. Header shows the exact official OP asset, Dashboard heading, current location, league, season, user/profile, notifications and navigation. The entire official logo area remains interactive and routes to Player Hub, as already specified.

Location/league/season context must remain visible and quickly switchable throughout the dashboard. All applicable sections use the same validated context and refresh dependent data when it changes.

### Main dashboard

Provide actual, clickable operational metrics for:
- Active locations and competitions.
- Current seasons.
- Registered teams and players.
- Pending team and player approvals.
- Upcoming and completed fixtures.
- Results awaiting publication.
- Outstanding payments.
- Season progress.

Every metric links to the corresponding filtered register. Figures come from actual database records and respect permissions/context.

Provide Quick Actions (only when permitted): Add Team, Add Player, Create Competition, Create Season, Generate Fixtures, Add Result, Manage Approvals, Open Gallery. Each opens a complete workflow, not a decorative control.

### Needs Attention task centre

Centralise actionable outstanding work:
- Pending team/player registrations and membership requests.
- Missing team sheets.
- Unpublished results.
- Outstanding payments.
- Unanswered enquiries where that workflow exists.
- Incomplete team registrations.
- Fixtures requiring attention.
- Other verified operational issues.

Each item states what needs doing, affected count/record, grounded priority, age/deadline if known, and a direct action. Tasks disappear or update when source records change. Never invent urgency or deadlines. Avoid duplicate tasks for the same underlying issue.

Include upcoming fixtures/matchday, recent activity, registration progress, announcements and financial summary only where data is available and permission allows.

## 6. Administrative navigation — authoritative 15-section structure

The final navigation is the following **15-section** structure. This resolves the earlier 14-section list: Fixtures and Team Sheets are separate departments, and Analytics & Reports is a mandatory independent department. The older 14-section list is superseded where it conflicts with this list.

| No. | Section | Landing experience |
|---|---|---|
| 01 | Dashboard | Overview |
| 02 | Locations & Competitions | Overview |
| 03 | Seasons | Overview |
| 04 | Team Approvals | Overview |
| 05 | Player Approvals | Overview |
| 06 | Teams & Squads | Overview |
| 07 | Players | Overview |
| 08 | Fixtures | Overview |
| 09 | Team Sheets | Direct operational workspace; no forced overview |
| 10 | Results & Match Events | Overview |
| 11 | Finance | Overview |
| 12 | Analytics & Reports | Dedicated analytics overview |
| 13 | Communications | Overview |
| 14 | Gallery | Direct visual workspace; no forced overview |
| 15 | Settings & Feature Management | Organised settings workspace; no forced overview |

### Category overview pattern

Where an overview is useful, show category name/purpose, context, category tabs, approximately 4–6 relevant KPIs, meaningful charts/progress, category-specific Needs Attention, recent activity and quick actions. Metrics link to their filtered records. Do not force overview pages into Team Sheets, Gallery or Settings.

Category-specific tabs and measures:

- **Locations & Competitions:** Overview, Locations, Leagues, Venues, Administrators. Active locations, competitions, venues, active seasons, teams by location, upcoming launches, incomplete configurations.
- **Seasons:** Overview, Current, Upcoming, Past, Configuration. Active/upcoming/completed seasons, team/player registrations, capacity, registration completion, fixtures completed/remaining, fees and balances.
- **Team Approvals:** Overview, Pending, Approved, Rejected, History. Applications received, pending, approved/rejected, processing time and oldest outstanding.
- **Player Approvals:** Overview, Pending, Membership Requests, Approved, Rejected, History. Pending applications, requests, new registrations, approved/rejected and processing time.
- **Teams & Squads:** Overview, All Teams, Active, Registration, Performance, Archived. Total/active/pending teams, average squad size, squad members/capacity, incomplete registrations, outstanding fees.
- **Players:** Overview, All Players, Active, Pending, Activity, Archived. Unique accounts, active players, new registrations, pending, linked/unlinked players, returning users and season participation. Never double-count one identity.
- **Fixtures:** Overview, Fixture List, Calendar, Gameweeks, Referee Allocation, Management. Scheduled/completed/upcoming/postponed/cancelled, awaiting confirmation/results, missing referee allocation.
- **Team Sheets:** Direct workspace. Expected/submitted/missing/awaiting review/approved/returned sheets; inspect both teams for a fixture and record audited amendments.
- **Results & Match Events:** Overview, Enter Results, Published, Unpublished, Match Events, Corrections. Matches played, entered/published/unpublished/correction-required, goals, average goals, cards and walkovers.
- **Finance:** Overview, Payments, Outstanding Balances, Fees & Pricing, Refunds, Transactions, Financial Reports. Expected revenue, actual receipts, outstanding/overdue, collection rate, payments, refunds, revenue by team/location/season and recorded costs. Clearly distinguish forecast, charge, receipt, balance and net operating surplus.
- **Analytics & Reports:** Dedicated analytics department, described in section 8 below.
- **Communications:** Overview, Announcements, Messages, Scheduled, Sent History. Published/scheduled messages, delivery status/failures and outstanding communications tasks.
- **Gallery:** Direct workspace for albums, matchday uploads, unpublished/published/archived media; upload, edit, caption, publish/unpublish and archive/delete with permissions and image privacy.
- **Settings:** General, Competition Rules, Registration, Squad Configuration, Points/Table Rules, Fixtures, Notifications, Branding, User Roles, Permissions, Feature Management, Security, Audit History.

## 7. Administrative workflows

A. **Create location:** Competitions → Add Location → Venue(s) → League → Season → Configure → Review → Save Draft or create → Activate only when ready.

B. **Register team:** Team registration → initial full squad submission → team approval → player approvals where required → team activated → visible in relevant season. Submission alone does not activate the team.

C. **Manage team:** Teams & Squads → select season-specific team → profile → captain/vice-captain where supported → squad → membership changes. Preserve historical season records.

D. **Manage fixtures:** Create/generate → review schedule → allocate slots/venue/referee → publish → notify correct teams. Reschedule/cancel with validation and audit; never corrupt completed history.

E. **Matchday:** Select fixture → review both team sheets → validate eligible players → record events → enter score → review → publish. Amendments remain auditable.

F. **Tables/statistics:** Published result → atomically/consistently update team records, table and player statistics. Corrections recalculate all dependent outputs safely.

G. **Finance:** Fee assigned → confirmed hosted payment or authorised manual payment record → ledger/balance updated. Outstanding balances feed Needs Attention. Never trust client-side amount or payment status.

H. **Season completion:** Verify fixtures/results → finalise table → reconcile finance → close registrations → mark completed → preserve read-only history.

### Manual season recruitment activation

- The location header is the primary public status surface across the location's app pages. It shows **Coming Soon / Recruiting Closed** while an upcoming season is closed, then **Recruiting Open** after manual activation.
- Admin controls provide **Keep Closed**, **Open Recruitment** and **Close Recruitment**. Opening requires a reason and a deliberate location/season-scoped Admin action.
- The server rechecks that the previous season in the same league has a final fixture marked completed and that the fixture has a published result. The scheduled date passing is not sufficient. If no prior season exists, the first season may be opened by an authorised administrator.
- Activation and closure are transactional, permission-checked server-side and audit logged. Direct status updates must not bypass the activation RPC.
- Opening makes normal player and team registration workflows available. Existing memberships remain tied to their original season.
- Do not add scheduled opening, countdown-triggered activation, scheduler jobs, automatic membership activation, advance team applications or pending future memberships.


## 8. Analytics & Reports — independent department

Analytics is a first-class department, not a few dashboard charts. Use PostHog for product usage/journeys and Supabase/Open Play's authorised records for competition, registration, payments and financial truth.

### Navigation

Analytics Overview; App Usage; User Growth; Registration & Conversion; Engagement & Retention; Feature Performance; Location Comparison; Competition Performance; Business Performance; Reports & Exports.

### Analytics scope

- **Overview:** accounts, new/active/returning users, DAU/WAU/MAU, sessions, section usage, registration starts/completions, conversion, approved teams/players, feature adoption, technical errors/performance and device/browser distribution. Show equivalent previous-period comparisons.
- **App Usage:** unique visitors, authenticated active users, sessions, page/screen views, sections/navigation, trends, device/browser, mobile/desktop. Distinguish anonymous visitors from authenticated users; page views are not unique users.
- **User Growth:** accounts by day/week/month, active/returning/first-time, growth rate/source/location where available and cohort analysis.
- **Registration & Conversion:** funnel from visitor → registration options → account signup → verification → profile completion → team/player request → approval → operational player/team. Show conversion/drop-off per stage. Account creation is not player registration.
- **Engagement & Retention:** DAU/WAU/MAU, returning users, retention, repeat sessions, activity by location/season, fixture/result/team/announcement engagement and 1/7/30-day cohorts. Define meaningful activity; an open tab is not engagement.
- **Feature Performance:** Player Hub, Match Centre, teams, tables, fixtures, results, registration, team management, gallery, announcements, profile, location and season switching. Unique users, interactions, adoption, repeat usage, trend and failure rate.
- **Location Comparison:** users, active players, teams, registrations/conversion, retention, app engagement, fixtures, participation, revenue, outstanding balances and collection rate. Compare equivalent periods/seasons and identify incomplete seasons. Location admins only see assigned locations.
- **Competition Performance:** teams, active players, squad capacity, registration growth, fixture completion, match participation, goals, goals/match, team participation, season progress, fees and revenue.
- **Business Performance:** verified receipts, expected income, outstanding balances, pitch/referee/other recorded costs, sponsorship income, operating surplus, cost/revenue per team and growth. Show profitability only when relevant cost data is complete. Supabase finance records remain source of truth.
- **Reports & Exports:** reusable growth, engagement, conversion, feature, location, season, participation, match and financial reports; CSV/print exports with sensitive-data permission controls.

### PostHog integration and event governance

The paired ChatGPT PostHog connection is not the same as the application's SDK connection. Inspect the actual PostHog project and current app configuration before choosing a project/key. Integrate the supported client SDK using environment configuration and the public project ingestion key only. Never expose personal/server API keys or privileged credentials in browser code.

Use consistent meaningful event names, including:
`account_signup_started`, `account_signup_completed`, `account_verification_completed`, `player_profile_completed`, `onboarding_completed`, `team_registration_started`, `team_registration_submitted`, `player_join_request_submitted`, `team_application_approved`, `team_application_rejected`, `player_application_approved`, `player_application_rejected`, `location_selected`, `location_switched`, `season_selected`, `season_switched`, `navigation_section_viewed`, `fixture_viewed`, `result_viewed`, `league_table_viewed`, `team_profile_viewed`, `player_profile_viewed`, `gallery_viewed`, `announcement_viewed`, `feature_opened`, `feature_action_completed`, `feature_action_failed`, `application_error`, `workflow_error`, `data_load_failed`.

Capture only meaningful actions/outcomes, not repeated component renders. Use opaque IDs for location/league/season and pseudonymous account identity. Suitable properties include role, device type, app version, feature/workflow and timestamp. Never send passwords, email, phone, address, payment/card data, private notes, complete team sheets, private messages or sensitive registration details.

Respect UK GDPR/PECR, consent and opt-out requirements; minimise capture, disable sensitive autocapture/session replay by default unless specifically reviewed and lawfully enabled. Logout/account changes must correctly reset analytics identity. No PII or financial transaction truth belongs in PostHog.

### Analytics accuracy

- PostHog: visits, product usage, funnels, retention, feature adoption, technical interactions.
- Supabase: actual accounts, approved registrations, memberships, teams, seasons, fixtures, results, statistics, payments, balances and costs.
- Funnel starts in PostHog do not equal submitted/approved records in Supabase. Explain discrepancies and definitions.
- No misleading zero while data is loading or unavailable. Show reporting period, timezone, last successful refresh and data delay.
- Use date filters Today, 7/30/90 days, This Month, Last Month, This Season, Previous Season and Custom. Compare equivalent periods.
- Charts have titles, labels, legends, accessible text/table alternatives and do not rely on colour alone.

## 9. Permissions and audit

Reuse existing Open Play authentication and roles. Public visitors browse permitted public information only. Players select available contexts and see their permitted data. Captains retain only existing team/season-scoped captain actions. Location administrators manage only assigned locations/leagues/seasons. Super administrators have system-wide authority.

All checks must be enforced in database RLS and server-side RPCs/Edge Functions. UI visibility is not security. Users cannot grant themselves roles or assignments. Direct URLs and direct RPC calls must not bypass authorization. Sensitive player/finance fields are disclosed only to authorised roles and for a justified workflow.

Audit location/league/season lifecycle, approvals, squad/captain changes, fixture/result amendments, finance adjustments/refunds, communications and permission changes. Include actor, timestamp, entity, reason and before/after data where appropriate; minimise sensitive values.

## 10. Responsive design, accessibility and interaction

Use the established Open Play design system and exact supplied OP logo; do not copy EVRi branding or create a second palette. Retain player-facing design tokens and keep admin styling isolated from player-facing CSS. Use existing typography, orange accent for primary actions/selection, readable neutral surfaces, subtle borders and consistent components. The header logo navigates to Player Hub.

Admin desktop/tablet: clear sidebar/navigation. Mobile: compact accessible navigation, one-column cards, full-width primary actions and no horizontal page overflow. Support iPhone, Android, iPad portrait/landscape and desktop. Do not rely on hover.

Target WCAG 2.2 AA: text contrast 4.5:1, large text 3:1, essential controls 3:1; keyboard Tab/Shift+Tab/Enter/Space/Escape and appropriate arrow keys; visible focus; semantic headings/landmarks; screen-reader labels and selected states; live announcements for save/error/load/context changes; 44×44 CSS px minimum touch targets (48×48 preferred); visible labels and corrective errors; reduced motion; no flashing. Charts must have accessible data alternatives.

Use loading/skeleton, empty, error, offline/retry, disabled and success states. Prevent double submits. Do not announce success before confirmed server success. Preserve unsaved data where practical. Handle concurrent edits with conflict detection.

## 11. Search, filters and context

Admin registers support appropriate search, filters, sorting, pagination and clear-filter actions. Global filters: location, league, season, date range. Default to administrator's assigned location, current league and active season; super admins may choose All Locations. Every applicable metric/chart/list/export updates consistently. Never rely on frontend filtering for data security.

Every page makes current location, league and season clear. Use breadcrumbs or equivalent. Switching context refreshes all dependent data. Historical views remain tied to their original records.

## 12. Required edge cases

Test: no locations; inactive/unpublished location; no seasons/active season; archived/completed season; unauthorised location; old selection becomes inactive; duplicate name/slug; missing venue; DB/network failure during save; refresh during selection; old bookmarked URL; concurrent admin edits; cross-location direct access; switch while viewing team/fixture; season completion; closed registration. Each case needs clear explanation and safe recovery, no silent failure or broken empty page.

## 13. Performance and reliability

Fetch only needed data, use scoped queries, indexes, pagination and appropriate caching. Never allow stale cached permissions/status. Avoid loading every team/player for a location card. Load detailed analytics on demand, cache safe summaries, prevent duplicate event capture, and show last refresh/data-delay state.

## 14. Acceptance and release gates

Feature completion requires:
1. The 15-section admin navigation and correct landing types.
2. Category overviews and operational workspaces as specified.
3. Real database-backed metrics with direct filtered navigation.
4. Location/league/season context consistently enforced.
5. Complete location/venue/league/season lifecycle.
6. Working approvals, teams, players, fixtures, sheets, results, finance, communications, gallery and settings workflows.
7. Dedicated PostHog-backed product analytics and Supabase-backed competition/finance analytics.
8. Verified event taxonomy, privacy, consent and identity handling.
9. Role/RLS/server permission tests, including direct URL/RPC attempts.
10. Functional keyboard, screen-reader, contrast, touch and reduced-motion checks.
11. Responsive device verification.
12. Error, concurrency, offline and historical-data preservation tests.
13. CSV/print exports with access controls.
14. Deployed-app verification after approved release.

CI compilation alone is not acceptance. Do not seed fictional live data, expose placeholders as complete, configure live payment processing, publish future locations, merge/deploy production or modify production without explicit approval.

## 15. Implementation order

1. Audit existing app, schema, dashboard, navigation, permissions, PostHog project and event taxonomy.
2. Map existing entities/workflows to the 15-section information architecture; identify gaps and avoid duplicate systems.
3. Implement shared admin navigation and validated location/league/season context.
4. Implement location/venue/league/season lifecycle and player selection flows with RLS.
5. Build main dashboard, Needs Attention and section/category overviews.
6. Complete each operational department and guided workflow.
7. Integrate PostHog SDK and governed event taxonomy with consent/privacy.
8. Build Analytics & Reports with correct data-source boundaries.
9. Complete reports/exports, audit, performance and accessibility.
10. Test permissions, all workflows, concurrency, device sizes and deployed app.

Work incrementally. Verify each slice, record migrations/tests/limitations, then continue. If a payer model, permission, legal/consent, external credential or production approval is essential and unknown, isolate that blocker and continue independent work without inventing a decision.

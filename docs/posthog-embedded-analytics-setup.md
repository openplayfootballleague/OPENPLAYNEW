# Open Play PostHog embedded reporting setup

## Purpose

The Admin Analytics Engagement & Retention and Feature Performance tabs use PostHog's query API for small, aggregate-only embedded analytics. Competition scope and administrator permissions are resolved by the signed-in user's Supabase session, not by browser-supplied IDs.

The application does not send the PostHog query credential to the browser. The Edge Function uses it only on the server and returns aggregate rows; it never returns person IDs, distinct IDs, emails, names, contact details, raw events or session recordings.

## Required Supabase function secrets

Create a PostHog personal API key with the minimum **project query read** permission and store it as a Supabase Edge Function secret:

- `POSTHOG_PERSONAL_API_KEY` — project-scoped read-only query credential; never use the public PostHog ingestion/project token here
- `POSTHOG_PROJECT_ID` — numeric PostHog project ID
- `POSTHOG_APP_HOST` — `https://eu.posthog.com` for the Open Play EU PostHog project

Optional:
- `APP_ORIGIN` — exact production application origin used for the function's CORS allowlist

Do not put the personal API key in `VITE_*` variables, GitHub source files, browser local storage or client-side configuration. Do not commit it to the repository. The function returns a clear not-configured response until the secrets are present.

The query API is intended for embedded aggregate analytics, not bulk event export. This implementation returns only three small aggregates and does not paginate or extract raw event records.

## App Usage reporting

The App Usage tab uses explicit `navigation_section_viewed` events, not PostHog autocapture or raw pageviews. The application adds a coarse `visitor_type` property to events after actor resolution:

- `anonymous` — no authenticated session
- `authenticated` — verified active account, player or captain

The visitor type is an allowlisted enum. No account ID, role-specific identifier, email or contact information is attached to the event. The platform-wide App Usage report is restricted by the Edge Function to global administrators using the authenticated `get_admin_context_preference` RPC. Location administrators cannot request it, and location/league/season filters are deliberately rejected because navigation events are not attributed to a competition location.

The report shows unique visitors by audience, navigation-section views and daily section navigation. It does not claim to measure sessions, device/browser distribution, raw pageviews, session replay or time-on-page; those collection modes remain disabled by the privacy configuration. Only events captured after visitor-type classification is deployed are included.

## Meaningful engagement event

`core_value_action` is captured only after explicit analytics consent and only for a verified non-privileged player/account/captain actor. Global Privacy Control, denied/unset consent, and admin/finance roles remain excluded.

The current event is emitted when available competition content is actually present:
- `fixtures` — the selected season has fixtures in Match Centre
- `results` — the selected season has published results in Match Centre
- `league_table` — the selected season has standings in Match Centre
- `player_statistics` — verified player statistics are displayed in Player Hub
- `team_directory` — approved teams are displayed in the public directory

Each event contains only an allowlisted feature key and the selected `season_id`. It does not contain player identity or match-level details.

## Metric definitions

- Weekly active players: unique PostHog persons with at least one `core_value_action` in a completed Monday–Sunday week.
- Weekly meaningful views: count of the same consented content-view events.
- Retention: recurring weekly activity in the selected date window. Cohort entry is first observed meaningful activity within that selected window; it is not account creation or player registration. Only complete Monday–Sunday weeks wholly contained in the selected window are included; partial first/last weeks and the current incomplete week are excluded.
- Feature performance: unique players and meaningful content views by the allowlisted feature. A player may appear in multiple feature rows.
- No events in a period is shown as no data, not as evidence of zero product engagement.

## Scope and security

- Every request must carry a valid Supabase user JWT.
- The Edge Function calls `get_admin_product_analytics_scope` with that user's session. This purpose-built RPC returns only location, league and season IDs; it does not fetch player identities, profiles, fixtures or other admin dashboard data.
- Supplied location/league/season filters are checked against that list. PostHog queries are restricted to the resulting season IDs.
- The UI receives aggregate data only. The function does not use the Supabase service-role key.
- Date filters are validated and capped at 366 inclusive days.
- PostHog's project timezone is UTC; week boundaries are Monday UTC. Supabase operational reporting retains its Europe/London definitions.
- Product analytics remain separate from Supabase registration, competition and finance truth.

## Release checklist

1. Create the minimum-scope PostHog personal API key and store the three required secrets in Supabase Function Secrets.
2. Deploy the `admin-product-analytics` Edge Function with the rest of the approved application release.
3. Confirm the consent banner and GPC behavior in the browser.
4. Verify a consented player produces `core_value_action` events with only `feature` and `season_id`.
5. Verify a global admin sees the permitted aggregate and a location admin cannot query an unassigned location or season.
6. Verify the UI stays empty when no consented events exist.

No hosted secrets, hosted migrations, production deployments or PostHog project settings are changed by this code change.

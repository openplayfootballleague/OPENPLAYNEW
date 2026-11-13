# App Usage metric definitions

## Scope and eligibility

App Usage is a platform-wide product-usage report sourced from PostHog. It counts only explicit `navigation_section_viewed` events captured after the visitor has opted into optional analytics, while Global Privacy Control is absent, and while the PostHog privacy-settings verification gate is enabled.

The event is emitted for public navigation and verified account/player/captain navigation. A single allowlisted `visitor_type` value separates:
- `anonymous`: no authenticated session
- `authenticated`: a verified active account, player or captain session

The value is a coarse audience category, not an account identity or role. No email, phone number, profile ID, player ID, team ID, session ID or other direct identifier is added by the application event.

## Report measures

| Measure | Definition | Interpretation |
| --- | --- | --- |
| Unique visitors | Distinct PostHog `person_id` values with an eligible navigation event in the selected date range, grouped by visitor type | Distinct consented PostHog persons, not a count of all app users or all visitors |
| Navigation section views | Count of eligible `navigation_section_viewed` events | Explicit navigation-section transitions only; not raw pageviews |
| Daily unique visitors | Distinct PostHog persons per calendar day and visitor type | The same person may appear on multiple days |
| Daily section views | Eligible navigation events per calendar day and visitor type | A person can generate multiple section views |
| Most viewed sections | Eligible events grouped by allowlisted `route_category` and visitor type | Shows intentionally instrumented navigation categories only |

## Access control

The Edge Function verifies the caller's Supabase JWT and checks the authenticated administrator context through `get_admin_context_preference`. Platform-wide App Usage is available only when `is_global_admin` is true. Location administrators and non-admin users cannot query this report. The endpoint rejects location, league or season filters for App Usage because these navigation events are not attributed to a competition location.

## Explicit exclusions and limitations

The current privacy configuration disables PostHog autocapture, automatic pageviews/pageleave, session recording, heatmaps, performance capture, exception capture and device/browser fingerprinting. Therefore this report does not claim to measure:
- all visits or raw pageviews;
- sessions, session duration or time-on-page;
- device, browser or operating-system distribution;
- user journeys or replay recordings;
- unconsented visitors or events captured before visitor-type classification was deployed.

No-data means no eligible consented navigation events were returned for the selected period. It must not be interpreted as zero total platform traffic.

## Reporting and release

The date range is inclusive in the Europe/London admin reporting UI and is translated to an exclusive next-day upper timestamp by the Edge Function. Only events present in the PostHog project at query time are returned; ingestion delays can affect recent dates. The browser uses only the public ingestion key. The PostHog personal query key remains a server-side Supabase Edge Function secret and is not configured by this draft.

This report is a product-usage view, not operational competition or financial truth. Supabase remains authoritative for registrations, memberships, fixtures, results and finance.

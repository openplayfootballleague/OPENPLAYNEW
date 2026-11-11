# Admin context implementation status

Updated: 8 November 2026

This document records implementation progress against `docs/admin-dashboard-location-season-analytics-master-specification.md`. It is a status record, not a replacement for the master requirements.

## Implemented on `feat/stripe-test-checkout-lifecycle`

- Added accessible navigation links to existing admin workspaces and matching section anchors.
- Added a persistent location / league / season preference selector.
- Added server-side context-aware RPCs for:
  - Dashboard counts and approval queues.
  - Player register.
  - Team sheets.
  - Transfer requests.
  - Fixtures and results list.
- Context hierarchy is validated server-side. A selected season must belong to the selected league; a selected league must belong to the selected location.
- New RPCs are SECURITY DEFINER with an empty search_path, explicit administrator checks, EXECUTE revoked from PUBLIC and anon, and EXECUTE granted to authenticated.
- The preference table has RLS enabled and no direct table grants; access is through guarded RPCs.
- Player identity reviews remain global because account verification is not season-specific. The UI labels this distinction.

## Database migrations

- `20261108130000_admin_context_preferences.sql`
- `20261108140000_context_scoped_admin_dashboard.sql`
- `20261108150000_context_scoped_admin_player_register.sql`
- `20261108160000_context_scoped_admin_team_sheets.sql`
- `20261108170000_context_scoped_admin_transfers.sql`
- `20261108180000_context_scoped_admin_fixtures.sql`

These migrations have been applied to development project `ghnrsysvrlgkjmdlwdmp` and corresponding migration files committed to the development branch.

## Verification

- CI run `42432961795` completed successfully: Edge Function type-check, domain tests, TypeScript/application build and Cloudflare Worker dry-run bundle validation all passed.
- CI run `42432955372` also completed successfully for the frontend and generated type changes preceding the final fixture migration.
- Database privilege inspection confirmed all four contextual data RPCs deny anon execution and allow authenticated execution; each is SECURITY DEFINER and checks administrator role in its function body.
- No production deployment, live payment operation, or production data modification was performed.

## Known gaps and constraints

- Context filtering is not yet wired into every administrative surface. The competition setup source still supplies full location/league/season lists for administrative creation workflows; some downstream forms and reports need scoped selectors and query arguments.
- Finance, analytics, audit history, notification outbox, and the dedicated season statistics view still need deliberate context handling.
- Current `has_platform_role()` authorises platform roles globally. The database does not yet have a location-administrator assignment model. Therefore the new context filters are not a substitute for the master specification's location-scoped administrator permissions. Do not claim location-level access control is complete.
- No authenticated browser acceptance test has been run for the new selector and context-scoped queues. Development project has no seeded user/team/fixture records for realistic end-to-end testing.
- PostHog SDK integration and consent-aware event instrumentation remain outstanding.

## Next priority

Implement the location administrator assignment model and enforce location-level access server-side across all administrative RPCs. Then complete context filtering for finance, analytics, audit, notifications, and the remaining management workspaces. Preserve super-administrator global access and keep the first public launch limited to Bideford.

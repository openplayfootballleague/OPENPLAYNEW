# Phase 2 — Backend and data architecture

## Scope
The new Supabase project is the only intended backend. No old project identifiers, credentials, or production records are reused.

## Domain model
- **Identity:** Supabase Auth owns credentials; `profiles` stores player profile and private contact/emergency details. Roles are separately granted in `user_roles`.
- **Competition:** locations contain leagues; leagues contain seasons. A season owns its competition format and lifecycle.
- **Historical teams:** `teams` is the long-lived club identity. `season_teams` stores that club's season-specific name, badge and colours, so archived records remain historically accurate.
- **People:** season registration is separate from team membership. Membership carries the season-specific captain assignment and optional squad number.
- **Matchday:** fixtures reference two season teams; results, team sheets, player selections and availability are separate records.
- **Transfers:** player movement is requested and reviewed rather than silently changing membership history.
- **Money:** fee configuration is versioned by effective gameweek. Each payment stores an immutable fee snapshot and unique Stripe references; payment state is intended to be webhook-driven.
- **Operations:** notification events and append-only audit records support delivery tracking and accountability.

## Security approach
- RLS is enabled on every application table in the initial schema.
- Client-side UI visibility is never treated as authorization.
- User role grants, financial writes, fixture result confirmation, payment state transitions and audit records must be performed by trusted server-side functions.
- Sensitive profile data is not public by default.
- Stripe webhook signature verification and idempotency are required before payment records can be marked paid.
- Archived seasons are read-only at the application/service layer and must not be mutated through ordinary captain workflows.

## Team sheet rules
- Six-a-side: exactly 6 starters and up to 3 substitutes.
- Seven-a-side: exactly 7 starters and up to 4 substitutes.
- Squad numbers are optional.
- These format-aware validations must be enforced server-side at submission, not only in the interface.

## Migration status
`20261107220000_initial_platform_schema.sql` defines the first domain schema and enables RLS. It has not been applied because the connected Supabase account does not yet expose the new **Open Play New** project. The next migration will add policies and privileged database functions after review of the project connection and schema.

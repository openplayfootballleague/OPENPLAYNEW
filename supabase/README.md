# Supabase migration and policy notes

## Applying migrations
Only apply migrations to the dedicated **Open Play New** Supabase project. Do not use the older Open Play production project.

The initial schema migration creates the core competition, player, team, matchday, transfer, finance, notification and audit tables. The RLS migration adds read and write policies with a conservative default: public visitors can read only published competition information; players can access their own private records; captains can inspect their own active team data; privileged operations remain server-side.

## Important implementation constraints
- Profile contact and emergency-contact fields are private by default.
- User role grants cannot be written by ordinary authenticated clients.
- Team membership and captain approval changes are not direct client writes.
- Fixture result confirmation and payment state transitions are privileged operations.
- Stripe webhook handling must verify signatures and be idempotent.
- Team sheet validation must enforce the competition format: six-a-side is 6 starters + up to 3 substitutes; seven-a-side is 7 starters + up to 4 substitutes.
- Squad numbers remain optional.
- Fee changes are effective from a specific gameweek. Existing payment records retain their own `fee_snapshot`.
- Audit history is read-only to application clients.

## Not yet applied
These migrations are committed to GitHub but have not been run against Supabase. The new Supabase project is not yet visible to the connected Supabase integration. Before applying, review policies against the actual project and run the migrations in a disposable test database.

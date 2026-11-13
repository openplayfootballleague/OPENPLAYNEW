# Open Play — Engineering, Security and Release

## Architecture
- TanStack Start, React and TypeScript.
- Supabase Auth and PostgreSQL.
- Cloudflare Workers hosting target.
- Stripe and Stripe Connect.
- PostHog with explicit consent/privacy controls.
- GitHub: openplayfootballleague/OPENPLAYNEW.
Do not change hosting/backend architecture without owner approval.

## Engineering
Keep generated types aligned with migrations. Version schema changes. Keep canonical SQL and generated migrations aligned where both exist. Use shared domain functions and tests. Privileged operations belong in server-side RPCs/handlers. Never expose service-role, Stripe or private analytics secrets in browser code or source control. No fake production data.

## Supabase security
RLS on exposed tables. Validate actor identity, role, scope and inputs in privileged functions. SECURITY DEFINER functions need explicit search_path, least privilege and authorisation checks. Restrict direct table grants when RPC-only access is intended. Use transactions/locking for race-prone membership and permission workflows. Keep hosted migrations separate from isolated CI replay. Never weaken security merely to clear advisor warnings; prefer deny-by-default.

## Payments/webhooks
Verify signatures, ensure idempotency, persist provider IDs/state, reconcile asynchronous outcomes and never trust client-reported success. Keep test/live modes and secrets separate. No live money movement without owner approval.

## CI and evidence
Development CI should cover domain/unit tests, type/build, clean Supabase migration replay/security assertions, sensitive SQL regressions, browser responsive/PWA acceptance, PostHog consent/network acceptance and Cloudflare Worker build/dry-run. Evidence applies only to the exact SHA tested; any later code change needs fresh exact-head evidence.

## Acceptance campaign
After agreed feature coverage is complete, test full journeys for visitor, player, captain, referee and each admin scope; positive/negative/boundary/concurrency/recovery cases; multi-location and multi-season data; mobile/tablet/desktop; accessibility/privacy; provider sandbox roundtrips; backups, recovery, monitoring and support.

## Release gates
Owner decision on role bootstrap/access; GitHub branch protection; exact Cloudflare target/environment; canonical logo asset; approved staging budget; Stripe Connect test roundtrip and payout amount semantics; approved email/SMS/push setup; verified consented PostHog ingestion; physical-device and full E2E acceptance; privacy/security/support/rollback readiness.

## No-go without owner approval
No merge/deploy, hosted migration, production secret/config change, live charge/refund/payout, role bootstrap, real outbound notification or paid infrastructure provisioning.

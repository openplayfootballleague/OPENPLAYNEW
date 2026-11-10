# Supabase advisory audit — 10 November 2026

Project: `OPENPLAYNEW` (`ghnrsysvrlgkjmdlwdmp`, EU West).

This snapshot was collected from the Supabase Security, Performance and Health advisors. It is an advisory review of the current hosted schema; the unmerged weather-postponement migration is not applied to the hosted project.

## Security

| Finding | Count | Severity | Assessment |
| --- | ---: | --- | --- |
| RLS enabled with no direct policies | 3 | Info | Deny-by-default tables: `admin_context_preferences`, `gallery_items`, `location_admin_assignments`. Access is intended through scoped security-definer RPCs or service-role Edge Functions. Keep direct table access closed. |
| Authenticated-executable SECURITY DEFINER functions | 77 | Warning | Expected for protected application RPCs, but each function must validate `auth.uid()`, role, location/season scope and input constraints. The advisor cannot infer those internal checks. CI includes role-boundary and RLS regression tests, but this warning remains an explicit manual-review item. |

No Critical or Error-level security lints were returned in this snapshot.

## Performance

| Finding | Count | Severity | Assessment |
| --- | ---: | --- | --- |
| Multiple permissive policies | 15 | Warning | Consolidate overlapping admin/self/member policies where this can be done without changing access semantics. |
| Unindexed foreign keys | 7 | Info | Review query plans and add indexes where the relationship is used in joins/deletes. |
| Unused indexes | 52 | Info | Do not remove based on a fresh-project snapshot; usage data is not representative yet. Revisit after real league traffic. |

## Health

No health lints were returned.

## Release gates

- Keep RLS enabled and retain deny-by-default behavior on sensitive tables.
- Review every SECURITY DEFINER function before live launch; ensure a fixed empty/search path, minimal grants and explicit role/scope checks.
- Keep the SQL authorization regressions and clean migration replay required in CI.
- Re-run Supabase advisors after each hosted migration and after real traffic exists.
- Do not drop currently unused indexes until there is representative production usage and query-plan evidence.

This audit does not certify physical-device behavior, Stripe live-mode readiness or external provider configuration. Those are separate release gates.

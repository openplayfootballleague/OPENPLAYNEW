# Security-definer and exposed-table review — 8 November 2026

Project: OPENPLAYNEW (`ghnrsysvrlgkjmdlwdmp`)  
Review type: read-only live catalogue/privilege review

## Executive result

The Supabase advisor reported 80 SECURITY DEFINER functions executable by `authenticated`. A direct privilege query of the live database found:

- 95 SECURITY DEFINER functions in `public` in total.
- 80 executable by `authenticated`.
- **0 executable by `anon`**.
- 15 not executable by `authenticated` (including internal notification worker/trigger functions).

This is materially different from an exposed-to-everyone finding. The authenticated execution grants are intentional API reachability in this architecture, but every exposed function still needs an appropriate in-body authorization check because SECURITY DEFINER bypasses ordinary table RLS.

## Guard scan of all 80 authenticated-callable SECURITY DEFINER functions

A catalogue source scan found:

- 43 function bodies reference `has_platform_role()`.
- 7 reference `has_finance_access()`.
- 23 reference `can_administer_location()`.
- 7 reference `is_active_team_captain()`.
- No function in this set was missing all four of those common authorization patterns or a direct `auth.uid()` check.

One function, `get_admin_stripe_payments(uuid)`, does not contain a direct `auth.uid()` check. It calls `has_finance_access()`; inspection of that helper confirms it looks up the current `auth.uid()` in `user_roles` and permits only `admin`, `super_admin`, or `finance_admin`. This is an indirect authorization guard, not an unguarded function.

This scan is a triage check, not proof that every function's predicates correctly scope the requested object. In particular, the three already-recorded defects (#9–#11) demonstrate why the order and scope of checks must be reviewed semantically.

## RLS-enabled tables with no policies

Supabase advisor returned three INFO findings:

- `public.admin_context_preferences`
- `public.gallery_items`
- `public.location_admin_assignments`

A direct `information_schema.role_table_grants` check found no `SELECT`, `INSERT`, `UPDATE`, or `DELETE` grants to `anon` or `authenticated` for these tables. They are therefore closed to direct client table access at the SQL privilege layer in the observed state. The absence of policies is consistent with a function-mediated access model; do not add broad policies just to silence the INFO finding.

## Other advisor observations

- 15 multiple-permissive-policy warnings. These need policy-by-policy review; do not merge policies without preserving their OR semantics and intended access.
- 52 unused-index warnings. The database is early in its usage lifecycle; do not drop indexes solely because the advisor has not observed use. Review query plans and FK/index requirements first.

## Existing confirmed defects remain

- Issue #9: membership request captain/admin authorization order.
- Issue #10: location activation permits assigned league admins when only global admins should control activation.
- Issue #11: player fixture fee RPC has inconsistent finance-role/location checks.

These are not fixed by this audit.

## Decision

No blanket revoke of authenticated EXECUTE grants is recommended: the application uses RPCs as its controlled API, and the reviewed functions are not executable by `anon`. Instead, continue per-function semantic authorization review, prioritize the three confirmed defects, and preserve the no-direct-table-access model for the three RLS-only tables.

No production schema, grants, policies, role assignments, user data, payments, or migration history were changed in this review.

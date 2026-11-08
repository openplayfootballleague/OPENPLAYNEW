# Live Supabase advisor snapshot — 8 November 2026

Project: `OPENPLAYNEW` (`ghnrsysvrlgkjmdlwdmp`)

## Advisor results

A read-only Supabase advisor snapshot was collected after source recovery.

### Security

- 83 findings total.
- 3 informational `rls_enabled_no_policy` findings:
  - `public.admin_context_preferences`
  - `public.gallery_items`
  - `public.location_admin_assignments`
- 80 warnings for authenticated execution of SECURITY DEFINER functions.

The three tables with RLS enabled and no policies were checked directly: RLS is enabled and neither `anon` nor `authenticated` has SELECT, INSERT, UPDATE or DELETE table privileges on any of them. They are accessed through controlled server-side functions. Do not add permissive policies merely to silence the advisor.

The SECURITY DEFINER warning is a broad static lint: the functions are exposed as RPCs to authenticated users, but intended to enforce application role checks internally. This is not proof of an exploitable authorization defect. It does require a systematic review of every function's body, EXECUTE grants, actor checks, scope checks and tests. Do not revoke execution indiscriminately because that would break legitimate app workflows.

### Performance

- 74 findings total:
  - 7 unindexed foreign keys (informational).
  - 52 unused indexes (informational; low-traffic/new project may explain this, so do not drop them without workload evidence).
  - 15 multiple-permissive-policy warnings.

The 15 multiple-policy warnings need review for overlapping conditions and avoidable repeated policy evaluation. Do not combine policies without proving the combined predicate preserves access semantics.

### Health

- 0 health advisor findings.

## Safety and actions

This was a read-only audit. No production schema, policies, grants, data or migrations were changed.

## Next verification

1. Review SECURITY DEFINER functions in groups by domain and prove role/scope checks plus grants.
2. Review overlapping RLS policies for semantic equivalence before any consolidation.
3. Add indexes for confirmed hot foreign-key lookup paths only after query-plan/workload review.
4. Keep unused indexes until production-like query activity exists; re-evaluate after representative usage.
5. Repeat advisor checks after the migration baseline is canonical and isolated replay tests pass.

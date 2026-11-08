# Supabase authorization lint triage — 8 November 2026

This is a read-only triage of the current Supabase advisor warnings, not a replacement for role-based integration tests.

## Tables flagged for RLS without policies

The advisor flagged `admin_context_preferences`, `gallery_items` and `location_admin_assignments` because RLS is enabled without table policies.

A direct privilege query confirmed for all three:
- RLS is enabled.
- `anon` has no SELECT, INSERT, UPDATE or DELETE table privileges.
- `authenticated` has no SELECT, INSERT, UPDATE or DELETE table privileges.

They are intentionally accessed through controlled SECURITY DEFINER RPCs. Do not add broad RLS policies just to clear this informational notice.

## SECURITY DEFINER functions

The advisor reports 80 SECURITY DEFINER functions callable by `authenticated`. A catalogue-level check confirmed all 80 contain at least one textual actor/role/scope guard reference: `auth.uid()`, `has_platform_role()`, `has_finance_access()` or `can_administer_location()`.

This is only a static triage signal. It does not prove each function checks the correct role, resource scope, ownership or arguments. Each callable function still requires body-level review and positive/negative authorization tests. The 15 multiple-permissive-policy findings also require semantic review before any consolidation.

## Non-public/internal SECURITY DEFINER functions

The catalogue also contains SECURITY DEFINER trigger/worker helpers that are not callable by `authenticated`; observed ACLs restrict these to `postgres` or `service_role`. These should not be made client-callable.

## Advisor snapshot

- Security: 83 findings (3 informational RLS/no-policy notices, 80 authenticated SECURITY DEFINER notices).
- Performance: 74 findings (7 unindexed foreign keys, 52 unused indexes, 15 multiple-permissive-policy warnings).
- Health: 0 findings.

## Safety

No grants, policies, functions, data or schema were changed during this review.

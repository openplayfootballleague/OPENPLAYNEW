# Open Play — Supabase SECURITY DEFINER review

**Date:** 8 November 2026 (UTC)  
**Repository:** `openplayfootballleague/OPENPLAYNEW`  
**Supabase project:** `ghnrsysvrlgkjmdlwdmp`  
**Scope:** read-only catalog and source review of `public` SECURITY DEFINER functions. No schema, ACL, data, secrets, Edge Functions or deployment settings were changed.

## Live catalog snapshot

A read-only query against `pg_proc`, `pg_namespace`, `pg_get_functiondef` and function ACLs returned:

| Measure | Result |
|---|---:|
| Public SECURITY DEFINER functions | 95 |
| Functions with explicit fixed `search_path` | 95 |
| Functions whose definition references `auth.uid()` | 79 |
| Functions with one of the inspected explicit platform/finance/captain/location guards | 57 |
| Functions with explicit ACL entries | 95 |

The Supabase Security Advisor separately reported 80 functions callable by the `authenticated` role as SECURITY DEFINER functions. The advisor's warning count and the catalog counts above are different measures; neither should be interpreted as 80 or 95 proven vulnerabilities.

## Focused review of definitions without a direct auth.uid() reference

The catalog query identified 16 definitions without a direct `auth.uid()` text reference. Source and ACL inspection grouped them as follows:

- Internal notification queue/worker functions are restricted by ACL to `postgres` and/or `service_role`; the service-role entry points check `auth.role() = 'service_role'` where called by the delivery worker.
- Trigger functions (`handle_new_auth_user`, `notify_fixture_change`, `notify_fixture_result_change`, `notify_player_ban_change`, `notify_team_membership_change`, `notify_team_registration_change`) have explicit `postgres`-only execute ACLs and are intended to run through database triggers.
- `get_admin_stripe_payments(uuid)` is executable by `authenticated`, but its function body checks `public.has_finance_access()` before returning finance/payment records.
- The notification dispatch worker is `postgres`-only and reads its dispatch enablement and credentials from Vault before invoking the delivery function.

These checks support the intended access model for the inspected functions, but are not a substitute for testing every function with anonymous, ordinary authenticated, player, captain, location-admin, finance-admin and global-admin identities.

## Security posture and remaining review

1. All 95 inspected functions pin `search_path` to the empty path, reducing search-path object-shadowing risk.
2. All 95 have explicit ACL entries in the catalog snapshot. The actual role inheritance and effective privileges still need a complete grant/role matrix review.
3. The advisor's 80 SECURITY DEFINER notices remain open as review items until each function's authorization contract and effective grants have been tested.
4. Continue reviewing the 79 functions referencing `auth.uid()`: presence of the call alone does not prove correct authorization.
5. Review all helper-function call chains, especially helpers that return boolean role/scope decisions, for correct grants and privilege boundaries.
6. Do not change a SECURITY DEFINER function to SECURITY INVOKER, revoke execute privileges, or alter ACLs based only on the advisor warning. Such changes can break required RPC workflows; make targeted changes only after source review and role-based regression tests.
7. The performance advisor's unused-index and multiple-permissive-policy findings are separate optimization/semantics work and must not be bundled into this security review without evidence.

## Verification

- Live catalog query completed successfully.
- Definitions and ACLs for the 16 no-direct-`auth.uid()` candidates were inspected.
- The finance reporting function's `has_finance_access()` guard was confirmed in its live definition.
- Health Advisor returned no lints in the same audit window.
- No mutations were made.

## Next security acceptance task

Create disposable, owner-approved test identities for each role and exercise the full RPC permission matrix, including negative cross-location and cross-user cases. Do not create or promote privileged users without explicit owner approval.
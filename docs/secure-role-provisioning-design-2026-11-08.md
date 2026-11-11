# Open Play New — secure administrator role provisioning

**Status:** design only; implementation gated on migration-source reconciliation and owner-approved bootstrap identity  
**Date:** 8 November 2026  
**Related issue:** #24

## 1. Verified live role model

Read-only inspection of Supabase project `ghnrsysvrlgkjmdlwdmp` confirms:

- `public.user_roles` stores `user_id`, `role`, `granted_by` and `granted_at`.
- Allowed roles are exactly `admin`, `super_admin`, `finance_admin` and `league_admin`.
- A unique constraint prevents duplicate user/role rows.
- Authenticated users can SELECT their own role rows; they cannot INSERT, UPDATE or DELETE role rows.
- No deployed non-system database function was found that creates or revokes `user_roles`.
- `location_admin_assignments` stores a unique user/location assignment and an `assigned_by` actor.
- Existing assignment workflows assume that the target user already has `league_admin`.
- There are currently zero Auth users and zero role rows.

This is a sound anti-self-elevation boundary, but there is no supported initial Super Admin bootstrap or ongoing role grant/revocation workflow.

## 2. Role semantics (must remain separate)

| Role | Scope | Authority |
|---|---|---|
| `super_admin` | Global | Full platform administration, role provisioning and global configuration |
| `admin` | Global | Platform administration; no implicit role-provisioning authority |
| `league_admin` | Assigned locations only | Competition and location operations for explicitly assigned locations |
| `finance_admin` | Global finance | Finance ledger, payment reporting and fee configuration; no competition/location administration |

A `league_admin` is not a global admin. A `finance_admin` is not a platform/location admin. The existing `has_platform_role()`, `has_finance_access()` and `can_administer_location(location_id)` helpers must remain separate.

## 3. Initial Super Admin bootstrap

Do not create an Auth user or grant a role until the owner explicitly confirms the exact target account.

Recommended one-time server-side bootstrap:

1. The owner creates and verifies the intended account through the normal Supabase Auth flow.
2. The owner supplies the exact Auth user UUID through a secure deployment operation; never accept an arbitrary target user from a public browser form.
3. Store `OPENPLAY_SUPER_ADMIN_BOOTSTRAP_USER_ID` and a high-entropy `OPENPLAY_SUPER_ADMIN_BOOTSTRAP_SECRET` as Edge Function secrets. Never place them in Vite variables, source control, logs or PostHog.
4. A server-only bootstrap Edge Function requires a verified caller context and the bootstrap secret using constant-time comparison.
5. The database transaction checks that no `super_admin` row exists, that the target Auth user exists and has a verified email, and that the target UUID exactly matches the configured owner-approved UUID.
6. Insert the single `super_admin` role with `granted_by = null` or a separately documented bootstrap actor, and append an `audit_log` record identifying the bootstrap operation.
7. Make the bootstrap endpoint permanently refuse further grants as soon as a `super_admin` exists. Remove the bootstrap secret after successful acceptance.

The bootstrap operation must be idempotent, transactionally serialized and impossible to invoke from an ordinary authenticated client. Do not expose a reusable public endpoint that accepts arbitrary user IDs.

## 4. Ongoing role grant/revocation

Use a server-only Edge Function for the HTTP boundary and a tightly scoped database function for the atomic mutation.

### Edge Function responsibilities

- Verify the caller's Supabase JWT with the Auth service.
- Resolve the caller's role from `user_roles`; do not trust role claims supplied by the browser.
- Require an existing `super_admin` for all global role grants/revocations in the initial implementation.
- Require a verified target Auth user.
- Validate the role against the four-value allow-list.
- Require a bounded reason (5–500 characters).
- Rate-limit attempts and return generic errors that do not disclose account existence.
- Never accept a client-supplied `granted_by`, audit actor or arbitrary SQL.
- Do not expose the service-role key to the browser.

### Database transaction responsibilities

A service-role-only function should:
- re-check that the requested target exists;
- insert a role grant or delete an existing role row for revocation;
- prevent duplicate grants and make repeated requests idempotent;
- prevent removing the last active `super_admin`;
- prevent a caller from granting themselves `super_admin` through the ordinary grant endpoint;
- on `league_admin` revocation, remove that user's location assignments in the same transaction;
- leave `finance_admin` independent of location assignments;
- write a before/after audit event for every successful grant or revocation;
- return only the minimum safe result.

The SQL function must be executable only by `service_role` (and `postgres` for controlled maintenance), with EXECUTE revoked from `PUBLIC`, `anon` and `authenticated`. Keep direct client writes to `user_roles` and `location_admin_assignments` revoked.

### Location assignment

Keep location assignment as a separate workflow:
- only a `super_admin` or global `admin` may assign a location to an existing `league_admin`;
- the target must already have the `league_admin` role;
- assignment is unique by user/location;
- every assignment/revocation records the actor and reason;
- the database enforces the location scope and prevents assignment to inactive/nonexistent locations where required.

## 5. Admin UI

Add a dedicated Role Management area visible only to `super_admin`:

- searchable list of verified accounts and current roles;
- clear global vs location-scoped role labels;
- grant/revoke confirmation with mandatory reason;
- separate location-assignment panel for `league_admin`;
- last-Super-Admin protection;
- visible audit history;
- no role editing through profile forms or direct table writes.

Do not display a control that is not backed by a working, verified server operation.

## 6. Audit and privacy

- Keep all role grants, revocations, bootstrap actions and location assignments in Supabase `audit_log`.
- Include actor, target, role, action, timestamp and reason; never log bootstrap secrets, JWTs or raw credentials.
- Do not send role-management or privileged admin/finance activity to PostHog.
- Do not expose the complete role directory to ordinary authenticated users.
- Role lookup failures must fail closed.

## 7. Acceptance matrix

Run against a disposable database and test identities after migration reconciliation:

- no Auth user / unverified email cannot receive a role;
- ordinary player cannot grant or revoke any role;
- captain cannot grant or revoke any role;
- `finance_admin` cannot grant or revoke roles;
- `league_admin` cannot grant or revoke roles;
- `admin` cannot provision roles in the initial policy;
- `super_admin` can grant/revoke `admin`, `finance_admin` and `league_admin`;
- ordinary grant endpoint cannot grant `super_admin`;
- bootstrap succeeds only once, only for the configured owner-approved UUID, and only when no Super Admin exists;
- bootstrap replay, wrong secret, wrong target, missing verified email and concurrent calls all fail safely;
- last active `super_admin` cannot be revoked or demoted;
- revoking `league_admin` removes location assignments atomically;
- revoking `finance_admin` does not modify location assignments;
- all successful mutations produce exactly one audit event;
- direct authenticated/anon INSERT/UPDATE/DELETE on role and assignment tables remains denied;
- all cross-role and cross-location negative tests pass.

## 8. Gated implementation sequence

1. Complete migration-source/version reconciliation and clean replay.
2. Obtain owner confirmation of the exact initial Super Admin account UUID.
3. Add reviewed forward migrations for the service-role-only database mutation functions.
4. Add the bootstrap and ongoing provisioning Edge Functions.
5. Add the Super Admin-only Role Management UI.
6. Run the full role matrix and audit assertions in a disposable environment.
7. Obtain owner acceptance before any production role grant or bootstrap.

No Auth user, role, location assignment, database object, secret or deployment setting was changed while preparing this design.

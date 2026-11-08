# Open Play New — Administrator Role Provisioning Design

**Status:** proposed security design; owner approval and isolated implementation tests required  
**Date:** 8 November 2026  
**Repository:** `openplayfootballleague/OPENPLAYNEW`  
**Supabase project:** `ghnrsysvrlgkjmdlwdmp`

## 1. Current verified position

The deployed project currently has no Auth users and no `public.user_roles` rows. The allowed roles are `admin`, `super_admin`, `finance_admin` and `league_admin`.

The current database deliberately prevents browser-side role writes:
- `anon` and `authenticated` have no INSERT, UPDATE or DELETE privilege on `public.user_roles`.
- `authenticated` may read only the rows allowed by the existing self/platform-role SELECT policy.
- No deployed non-system RPC or Edge Function currently grants or revokes roles.
- Location assignments are a separate relationship and must remain separate from granting `league_admin`.

This design preserves that boundary. It does not create accounts, assign roles, or modify the database.

## 2. Proposed authority matrix

Use a deny-by-default model. The following is the recommended authority policy for owner review; it is not treated as an already-approved business decision.

| Actor | Grant/revoke admin | Grant/revoke finance_admin | Grant/revoke league_admin | Grant/revoke super_admin |
|---|---:|---:|---:|---:|
| Anonymous | No | No | No | No |
| Ordinary account/player | No | No | No | No |
| Captain | No | No | No | No |
| Location-assigned league_admin | No | No | No | No |
| finance_admin | No | No | No | No |
| admin | No | No | No | No |
| super_admin | Yes | Yes | Yes | Yes, with explicit step-up confirmation and reason |
| One-time owner bootstrap | First super_admin only | No | No | No |

A role grant never creates a player registration, team membership, captain appointment or location assignment. A `league_admin` must receive an explicit location assignment through the separate location-assignment workflow.

## 3. Initial super-admin bootstrap

The first super-admin must be provisioned through a one-time owner-controlled server-side operation, not through a public sign-up form or browser RPC.

Recommended bootstrap safeguards:

1. Owner identifies the exact existing Supabase Auth user by immutable UUID and independently verifies control of that account.
2. Target Auth user must already exist and have a confirmed email; the function must not create an Auth user.
3. A high-entropy bootstrap secret is installed only as a server-side secret (Cloudflare Worker/Edge Function secret), never in source code, browser variables, URL query parameters or logs.
4. A dedicated server-side bootstrap operation checks the secret in constant time, requires the target UUID, and obtains a transaction-scoped advisory lock.
5. The operation rechecks that no `super_admin` row exists, inserts exactly one role row and appends an audit record atomically.
6. A repeated request must fail closed after the first successful bootstrap. It must not silently replace the first owner or create another super-admin.
7. After successful bootstrap, the owner removes/rotates the bootstrap secret and verifies that the bootstrap endpoint is disabled or permanently spent.
8. If the final super-admin is later lost, recovery is a separately controlled owner procedure; it must not reopen public self-service bootstrap.

No target identity or bootstrap secret is currently available or assumed.

## 4. Ongoing grant/revoke workflow

Use a server-only Edge Function backed by a narrowly scoped database operation, or an equivalent server-side-only RPC boundary. The browser must never receive a service-role credential.

Every request must:
- authenticate the actor using the caller's verified Supabase JWT;
- verify the actor currently has `super_admin` (not merely a UI flag or metadata claim);
- validate the target Auth UUID exists and is email-confirmed;
- allow only the four enumerated role values;
- reject self-grant/self-revoke and duplicate role rows;
- require a bounded, non-empty reason;
- serialise changes with a transaction lock to prevent concurrent final-super-admin removal;
- reject removal/demotion of the final active super-admin;
- make no change if the requested state already exists, returning a safe idempotent outcome;
- write the role mutation and audit record in the same transaction;
- return only a minimal result, never private user or service-role data.

The service-role secret remains server-side. Direct client table grants on `user_roles` remain revoked.

## 5. Audit contract

Each successful grant/revoke should record:
- actor user UUID;
- target user UUID;
- role name;
- action (`role.granted` or `role.revoked`);
- reason;
- before and after role state;
- timestamp and correlation/request identifier where available.

Failed authorisation attempts should be logged to a security-safe server log without including tokens, passwords, email contents or bootstrap secrets. Audit readers remain subject to the existing privileged audit-history RPC and must not expose private audit payloads to ordinary clients.

## 6. Required tests before acceptance

Run against a disposable Supabase-compatible database with JWT identities and no production data.

| Test | Expected |
|---|---|
| Anonymous caller grants any role | Denied |
| Ordinary authenticated user grants any role | Denied |
| Captain grants any role | Denied |
| Location admin grants any role | Denied |
| finance_admin grants any role | Denied |
| admin grants any role | Denied |
| Existing super_admin grants admin/finance_admin/league_admin | Allowed with reason and audit |
| Existing super_admin grants another super_admin | Allowed only through explicit step-up confirmation and audit |
| Actor attempts to grant a role to self | Denied |
| Target Auth UUID does not exist | Denied |
| Target email is unconfirmed | Denied |
| Invalid role string | Denied |
| Duplicate grant | Idempotent; no duplicate row/audit grant |
| Revoke an existing non-final role | Allowed by authority policy and audited |
| Revoke the final super_admin | Denied |
| Two concurrent attempts to remove/demote final super_admin | At most one may succeed; final-super-admin invariant remains true |
| Bootstrap with no secret or wrong secret | Denied |
| Bootstrap when a super_admin already exists | Denied |
| Concurrent bootstrap attempts | Exactly one succeeds |
| Browser direct INSERT/UPDATE/DELETE on user_roles | Denied |
| Location assignment to a user without league_admin | Denied |

Also test that role grants do not automatically create player, captain or location-assignment records.

## 7. Implementation sequence and release gates

1. Owner confirms the proposed authority matrix and identifies the first trusted super-admin account through a secure channel.
2. Implement a forward-only migration for narrowly scoped server-side role mutation privileges and atomic audit/last-super-admin enforcement.
3. Implement the bootstrap and ongoing provisioning Edge Function with explicit secret handling and no client exposure.
4. Add SQL regression assertions and Edge Function tests.
5. Replay the complete reconciled migration history in an isolated database; run the full role matrix.
6. Test the administrator UI with approved disposable identities.
7. Keep all role provisioning disabled in production until the owner approves the target identity and the full acceptance report.

## 8. Explicit non-actions

- No Auth user has been created.
- No role has been granted or revoked.
- No direct client write grant has been added.
- No bootstrap secret has been created or stored.
- No production migration or deployment has been performed.

**Decision required before implementation:** owner approval of the proposed authority matrix and secure identification of the first super-admin. All other design and test preparation can proceed without touching production.

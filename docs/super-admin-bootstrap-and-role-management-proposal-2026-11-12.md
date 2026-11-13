# Open Play — initial Super Admin bootstrap and role-management proposal

**Status:** Design proposal only — owner approval required before implementation or execution  
**Environment reviewed:** Connected Open Play New Supabase project, read-only on 12 November 2026  
**Production changes:** None

## 1. Verified current state

The connected project currently has **zero rows** in `public.user_roles`: no `admin`, `super_admin`, `finance_admin` or `league_admin) assignments.

The role table accepts only those four role names. Its `granted_by` field is nullable and references `auth.users). The audit table's `actor_user_id` is also nullable and references `auth.users`; audit records require an action and entity type, and can retain a reason plus before/after JSON.

The live privilege boundary remains:
- `authenticated`: SELECT on `public.user_roles` only, governed by `user_roles_select_self_or_admin`.
- `anon`: no direct `user_roles` table grant.
- No public-schema function was found that inserts, updates or deletes `user_roles`.
- No role-provisioning Edge Function is deployed.
- The existing league-admin management RPC grants/revokes only `league_admin`, and requires an existing global administrator. It does not bootstrap the first global administrator or manage `admin`, `super_admin` or `finance_admin`.

The current helper semantics are important: `admin` and `super_admin` both receive global location administration and finance access; `finance_admin` receives finance access; `league_admin` receives platform-role visibility but can administer only explicitly assigned locations. The current database helpers do not distinguish `admin` from `super_admin` for global operational privileges.

## 2. Recommended initial bootstrap

Use a **one-time, owner-operated Supabase SQL Editor transaction**, not a public RPC, browser control, service-role secret in the app, or self-service endpoint.

Prerequisites before execution:
1. The project owner explicitly approves the first Super Admin identity.
2. The selected person has an existing, email-confirmed Supabase Auth account.
3. The exact Auth UUID is obtained from the Auth user record and independently checked against the intended account.
4. The owner approves whether the initial role is `super_admin` only, and whether the current equivalence between `admin` and `super_admin` is intended to remain.

Illustrative guarded transaction — **not executable until the zero UUID is replaced with the owner-approved Auth UUID and the reason is confirmed**:

```sql
begin;

do $bootstrap$
declare
  v_target_user_id uuid := '00000000-0000-0000-0000-000000000000';
  v_role_id uuid;
  v_reason text := 'Owner-approved initial Super Admin bootstrap via Supabase SQL Editor';
begin
  if current_user <> 'postgres' then
    raise exception 'Run only as the Supabase database owner from SQL Editor';
  end if;

  if v_target_user_id = '00000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'Replace the placeholder with the explicitly approved Auth user UUID';
  end if;

  if not exists (
    select 1 from auth.users
    where id = v_target_user_id and email_confirmed_at is not null
  ) then
    raise exception 'Target must be an existing email-confirmed Auth user';
  end if;

  if exists (
    select 1 from public.user_roles
    where role in ('admin', 'super_admin')
  ) then
    raise exception 'A global administrator already exists; one-time bootstrap is closed';
  end if;

  if exists (
    select 1 from public.user_roles
    where user_id = v_target_user_id
  ) then
    raise exception 'Target already has a role; review explicitly instead of stacking roles';
  end if;

  insert into public.user_roles(user_id, role, granted_by)
  values (v_target_user_id, 'super_admin', null)
  returning id into v_role_id;

  insert into public.audit_log(
    actor_user_id, action, entity_type, entity_id, reason, before_data, after_data
  ) values (
    null,
    'role.super_admin.bootstrapped',
    'user_role',
    v_role_id::text,
    v_reason,
    null,
    jsonb_build_object(
      'target_user_id', v_target_user_id,
      'role', 'super_admin',
      'bootstrap_method', 'supabase_sql_editor',
      'database_role', current_user
    )
  );

  -- Verify both writes before the transaction can commit.
  if not exists (
    select 1 from public.user_roles
    where id = v_role_id and user_id = v_target_user_id and role = 'super_admin'
  ) then
    raise exception 'Super Admin role post-condition failed';
  end if;

  if not exists (
    select 1 from public.audit_log
    where action = 'role.super_admin.bootstrapped'
      and entity_type = 'user_role'
      and entity_id = v_role_id::text
      and actor_user_id is null
  ) then
    raise exception 'Super Admin bootstrap audit post-condition failed';
  end if;
end;
$bootstrap$;

commit;

-- Verify the committed role and audit record after the transaction succeeds.
select id, user_id, role, granted_by, granted_at
from public.user_roles
where role = 'super_admin';

select action, entity_type, entity_id, reason, after_data, created_at
from public.audit_log
where action = 'role.super_admin.bootstrapped'
order by created_at desc
limit 1;
```

The null `granted_by` and null audit `actor_user_id` are deliberate: the operator is the Supabase project owner acting through the database-owner session, not necessarily an Open Play Auth user. The audit reason and metadata record the owner-controlled SQL Editor method without falsely attributing the action to the target account. If the audit insert fails, the transaction must roll back.

Do not expose a reusable bootstrap RPC. Once the first global administrator exists, this one-time path must remain closed.

## 3. Ongoing role management — proposed, not approved

A server-side RPC and admin workspace can manage role grants/revocations after bootstrap. Before implementing, the owner must approve the distinction between `admin` and `super_admin`, because current helper functions treat both as global administrators.

Suggested minimum safeguards:
- Only a designated role-management authority may grant or revoke global roles; the authority must not be inferred from UI visibility.
- No user may grant, elevate, or revoke their own role.
- Never remove or demote the final remaining Super Admin.
- Search only existing Auth users; do not create accounts or disclose unrelated private profile fields during role search.
- Granting `league_admin` must not grant any location access until a separate audited location assignment exists.
- Revoking `league_admin` must revoke and audit every location assignment in the same transaction.
- `finance_admin` must not receive player, location or general platform administration by virtue of the finance role.
- Every grant/revoke records actor, target, old/new role, reason, timestamp and associated location assignments where applicable.
- No direct client INSERT/UPDATE/DELETE grant on `user_roles`; all ongoing changes go through permission-checked RPCs.

## 4. Required isolated acceptance tests

- Bootstrap rejects a non-`postgres` database role.
- Bootstrap rejects the placeholder UUID, unknown user and unconfirmed email.
- Bootstrap rejects when an `admin` or `super_admin` already exists.
- Bootstrap creates exactly one `super_admin` row and one audit record, and rolls back both if any step fails.
- No `anon`, `authenticated` or service-role client can call or bypass the bootstrap path.
- Role-management positive and negative tests cover every role and direct RPC calls, not just UI controls.
- Self-promotion, self-revocation and removal of the last Super Admin are denied.
- `finance_admin` cannot administer locations or platform roles.
- `league_admin` cannot access unassigned locations; assignment grant/revoke is audited and role revocation leaves no stale assignment.
- Audit rows identify the actual actor; the initial owner bootstrap is explicitly represented as a database-owner action with no false Auth actor.

## 5. Explicit owner decisions still required

1. Which confirmed Supabase Auth account is to receive the first `super_admin` role?
2. Should `super_admin` be the only role allowed to grant/revoke `admin`, `super_admin` and `finance_admin`, while `admin` retains global operational access but cannot manage platform roles?
3. Should an `admin` and `super_admin` continue to have identical global data access, or should a narrower distinction be introduced?

Until these decisions are approved, do not execute the bootstrap, add role-management mutation RPCs, grant roles or change hosted permissions.

# Open Play administrator role provisioning and initial bootstrap

**Status:** design/runbook proposal for owner review. This document is not an instruction to provision a live account. No role is granted by this document, and the SQL below must not be run until the owner has explicitly approved the exact target identity and confirmed that the account is ready.

## Current security baseline

- `public.user_roles.role` permits `admin`, `super_admin`, `finance_admin` and `league_admin`.
- `authenticated` retains SELECT only, subject to the self/global-admin RLS policy. `anon` has no table access. Browser clients have no INSERT, UPDATE or DELETE privileges.
- `service_role` does not have direct table privileges on `public.user_roles`.
- The existing `admin_set_league_admin_role` RPC allows global admins to grant/revoke `league_admin`, records a reason and audit row, blocks self-change and removes location assignments on role revocation.
- `admin_set_location_assignment` is a separate global-admin-only operation. A location assignment does not create the `league_admin` role, and a `league_admin` role alone does not grant access to any location.
- There is no supported initial super-admin bootstrap or general grant/revoke workflow for `admin`, `super_admin` and `finance_admin`.

## Proposed authority matrix

This is the least-privilege proposal to implement and verify before release:

| Actor | May grant/revoke | Must not grant/revoke |
| --- | --- | --- |
| `super_admin` | `admin`, `super_admin`, `finance_admin`, `league_admin` | Their own role; the final remaining `super_admin` |
| `admin` | `league_admin` only, using the existing audited workflow | `admin`, `super_admin`, `finance_admin` |
| `finance_admin` | None | All roles |
| `league_admin` / location admin | None | All roles |
| Player, captain, ordinary account, anonymous or unverified actor | None | All roles |

Additional rules:

1. Initial `super_admin` creation is a one-time, owner-operated Supabase SQL Editor action, not a public RPC, web form, Edge Function endpoint, client secret or self-service flow.
2. After bootstrap, `super_admin` role changes use a dedicated server-side/database RPC restricted to authenticated `super_admin` actors. The RPC accepts only the target Auth UUID, an enumerated role, grant/revoke intent and a mandatory reason.
3. The general role RPC must reject self-change, unknown roles, missing/deleted Auth users, duplicate grants, no-op changes, and revocation of the last active `super_admin`. It must lock the relevant role rows and serialize final-super-admin checks against concurrent changes.
4. Granting/revoking `league_admin` continues through the existing audited workflow; revoking it must revoke every location assignment in the same transaction. Location assignment remains a separate operation.
5. No browser client receives direct write privileges on `user_roles`. SECURITY DEFINER functions use an empty/fixed `search_path`, explicit schema-qualified objects, narrow EXECUTE grants, and server-side actor checks.
6. Every real change records actor, target user, role, action, reason and before/after state in `audit_log`. Audit data must not be client-writable.
7. The UI must make the distinction between platform role and location assignment explicit and must never expose role controls to finance/location administrators.

## Initial bootstrap — owner-operated runbook

### Preconditions

- The owner has explicitly approved the exact person/account to become the first super-admin.
- The target person has created their own Open Play account and completed email verification.
- The owner has independently confirmed the target identity and copied the exact Auth user UUID from this project.
- The project owner is signed into the correct **Open Play New** Supabase project and has opened its SQL Editor.
- A recent backup/restore point and the current migration-source reconciliation are confirmed before any release operation.
- This is not run as part of CI, a browser session, an Edge Function or an application migration.

### 1. Identify and independently verify the account

Run this read-only query in the project SQL Editor. Confirm the UUID and email with the owner-approved identity out of band; do not rely on display name alone.

```sql
select id, email, email_confirmed_at, created_at
from auth.users
where lower(email) = lower('OWNER-APPROVED-EMAIL')
order by created_at desc;
```

If the result is missing, duplicated or not verified, stop. Do not create an account on somebody else's behalf.

### 2. One-time guarded bootstrap SQL

Replace all three placeholders deliberately. Read the full block before execution. The advisory transaction lock serializes concurrent bootstrap attempts. The block aborts if any super-admin already exists or if the target UUID/email pair is not an existing verified account. The audit row records that the initial grant was owner-operated; the SQL Editor session itself is not represented as an authenticated application actor.

```sql
begin;

do $bootstrap$
declare
  v_target_user_id uuid := 'REPLACE-WITH-OWNER-APPROVED-AUTH-UUID';
  v_expected_email text := lower('REPLACE-WITH-OWNER-APPROVED-EMAIL');
  v_operator_reference text := 'REPLACE-WITH-OWNER-APPROVAL-REFERENCE';
  v_role_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('open_play_initial_super_admin_bootstrap'));

  if v_target_user_id is null
     or v_expected_email = ''
     or v_operator_reference = ''
     or v_target_user_id::text = 'REPLACE-WITH-OWNER-APPROVED-AUTH-UUID' then
    raise exception 'Replace all bootstrap placeholders before execution';
  end if;

  if exists (
    select 1 from public.user_roles where role = 'super_admin'
  ) then
    raise exception 'A super-admin already exists; initial bootstrap is closed';
  end if;

  if not exists (
    select 1
    from auth.users u
    where u.id = v_target_user_id
      and lower(u.email) = v_expected_email
      and u.email_confirmed_at is not null
  ) then
    raise exception 'Target UUID/email must match an existing verified Auth user';
  end if;

  insert into public.user_roles (user_id, role, granted_by)
  values (v_target_user_id, 'super_admin', null)
  returning id into v_role_id;

  insert into public.audit_log (
    actor_user_id, action, entity_type, entity_id,
    reason, before_data, after_data
  ) values (
    null,
    'role.super_admin.initial_bootstrap',
    'user_role',
    v_role_id::text,
    'Owner-operated initial bootstrap; approval reference: ' || v_operator_reference,
    null,
    jsonb_build_object(
      'user_id', v_target_user_id,
      'role', 'super_admin',
      'bootstrap_method', 'owner_supabase_sql_editor'
    )
  );
end;
$bootstrap$;

commit;
```

If the transaction fails, stop and investigate; do not remove the guard or retry with a different account without fresh owner approval. Never paste service-role keys or credentials into SQL, chat, source control or a browser.

### 3. Verify without changing anything

After the transaction, run a read-only verification query:

```sql
select ur.user_id, u.email, ur.role, ur.granted_at, ur.granted_by
from public.user_roles ur
join auth.users u on u.id = ur.user_id
where ur.role = 'super_admin';
```

Confirm exactly one row exists and that its UUID/email match the owner-approved account. Confirm the corresponding `role.super_admin.initial_bootstrap` row exists in `public.audit_log`. Then sign in as that account and verify that the app resolves its role correctly. Do not enable public recruitment or other operational features as a side effect of role provisioning.

## Implementation and acceptance checklist

- [ ] Owner confirms the proposed authority matrix or supplies amendments.
- [ ] Add a forward-only migration for the super-admin-only general role grant/revoke RPC; do not rewrite applied migrations.
- [ ] Preserve the existing league-admin workflow and location assignment separation.
- [ ] Add row/advisory locking and a race-safe final-super-admin invariant.
- [ ] Add audit rows for grants and revocations with reason and before/after data.
- [ ] Add SQL tests for super-admin grant/revoke of each permitted role, duplicate/no-op handling, self-change, unknown role, missing Auth user, missing reason, last-super-admin protection and concurrent mutation.
- [ ] Add negative tests for anon, ordinary account, player, captain, league admin, location admin, finance admin and admin attempts to manage protected roles.
- [ ] Assert anon/authenticated direct INSERT/UPDATE/DELETE on `user_roles` remain unavailable and only the intended authenticated RPC can be executed.
- [ ] Verify league-admin revocation removes all location assignments and writes both assignment and role audit history.
- [ ] Run full clean local Supabase migration replay and all role/RLS security assertions.
- [ ] Keep the bootstrap SQL manual and owner-operated; do not expose it as an app feature.
- [ ] Do not apply migrations to the hosted project, provision a live identity, merge or deploy until separately authorised.

## Explicit non-goals

- No public bootstrap endpoint, signup metadata role, client-supplied role, shared bootstrap secret, service-role browser key or self-promotion.
- No role assignment based on email domain, display name, invitation URL or player/captain status.
- No automatic promotion of the account that creates the first team, location or league.
- No automatic location assignment when a user receives `league_admin`.

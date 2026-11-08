# Secure role provisioning and initial super-admin bootstrap

## Role authority matrix

| Actor | Grant/revoke admin | Grant/revoke super_admin | Grant/revoke finance_admin | Grant/revoke league_admin |
|---|---:|---:|---:|---:|
| Anonymous / player / captain | No | No | No | No |
| finance_admin | No | No | No | No |
| league_admin (including location-assigned) | No | No | No | No |
| admin | No | No | Yes | Yes |
| super_admin | Yes | Yes | Yes | Yes |

Rules:
- Role changes are made only through `public.manage_user_role`; direct API writes to `public.user_roles` remain revoked.
- The actor must be authenticated, must not target themselves, and must provide a 10–500 character reason.
- The target must already exist in Supabase Auth.
- A super_admin is required for admin/super_admin changes. An admin or super_admin may manage finance_admin/league_admin.
- The last super_admin cannot be removed. Role changes are serialized with a transaction advisory lock and written to `audit_log`.
- A role grant does not create a player, captain, team membership or location assignment. Location assignment remains a separate operation for an existing league_admin.

## Initial bootstrap

The first super_admin is created only through the service-role-only `bootstrap_initial_super_admin` RPC, called by the `bootstrap-super-admin` Edge Function. The Edge Function requires:
1. A valid authenticated Supabase session.
2. The caller's email to be verified and exactly match `OPENPLAY_BOOTSTRAP_OWNER_EMAIL`.
3. A high-entropy `OPENPLAY_BOOTSTRAP_TOKEN` (minimum 32 characters) supplied out-of-band in the request header.
4. The request origin to match `OPENPLAY_APP_ORIGIN`.
5. The Supabase service-role key held only in Edge Function secrets.

The database operation is one-time, transaction-locked, rejects an unverified/missing target, records a bootstrap marker, and writes an audit event. It is intentionally not enabled by default. No owner email, bootstrap token, Auth user, or privileged role is committed or provisioned by this change.

### Required owner-controlled setup

- Confirm the exact owner email address and account identity out of band.
- Ensure email/password signup and email verification are configured and working.
- Set `OPENPLAY_BOOTSTRAP_OWNER_EMAIL`, `OPENPLAY_BOOTSTRAP_TOKEN`, and `OPENPLAY_APP_ORIGIN` as Edge Function secrets only after owner approval.
- Deploy the function only as part of an approved release; then the owner signs in and invokes the one-time bootstrap.
- Remove `OPENPLAY_BOOTSTRAP_TOKEN` and `OPENPLAY_BOOTSTRAP_OWNER_EMAIL` after successful bootstrap, and disable the function. The database marker permanently prevents a second bootstrap.

## Verification

The isolated SQL regression test covers the service-role-only bootstrap grant, verified account requirement, repeat-bootstrap denial, role authority matrix, self-target denial, direct-table write denial, and audit trail. It runs only in the disposable local Supabase CI database. Hosted migration application and privileged identity creation remain separate owner-approved release actions.

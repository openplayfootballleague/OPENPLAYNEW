# Phase 1 — Account and player-registration foundation

## Scope
- [x] Dedicated TanStack Start + React + TypeScript application and Cloudflare Worker build.
- [x] Supabase Auth account creation, email verification, sign-in, sign-out and password recovery/reset routes.
- [x] Account creation remains separate from player registration and role assignment.
- [x] Mandatory player registration fields: full name, phone, Auth email and date of birth.
- [x] Email confirmation and Auth-email matching enforced by the server-side registration RPC.
- [x] Permanent player identity, one registration per Auth user, advisory-lock serialization and audit event.
- [x] Automatic approval below the two-of-three identity threshold; manual review at two or more metrics against the same candidate.
- [x] Pending/rejected registration states and global-admin-only identity-review evidence.
- [x] Player Hub access only for approved registered players or active captains.
- [x] Player picture upload is the only direct profile self-service edit; storage ownership and database column grants enforce it.
- [ ] Verify authenticated end-to-end signup, email delivery, reset and registration with disposable test identities.
- [ ] Verify the exact original 1619 × 971 OP asset is integrated (the current smaller PNG is not provenance-verified).
- [ ] Complete browser and real-device accessibility/responsive acceptance.
- [ ] Complete secure first super-admin bootstrap using an owner-approved identity.

## Database release
- [x] Reconcile the 98 applied migration versions to canonical source files and Git blob SHAs.
- [x] Consolidate outstanding forward-only corrections into one release migration.
- [x] Clean local Supabase replay and all SQL authorization/identity regression tests passed in CI.
- [x] Apply the reviewed consolidated migration to the dedicated Open Play New Supabase project; hosted ledger records version `20261108194831`.

## Completion criteria
Phase 1 is complete only when the account and player-registration lifecycle is fully implemented, the consolidated database release has passed clean replay and role-matrix tests, hosted schema is verified at the intended project, and the remaining authenticated/browser acceptance gates have been completed. Implemented, verified and released remain separate states.

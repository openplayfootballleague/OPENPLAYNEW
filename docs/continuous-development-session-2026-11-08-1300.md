# Open Play New — continuous development session report

**Session:** 8 November 2026, 13:00 UTC onward  
**Repository:** `openplayfootballleague/OPENPLAYNEW`  
**Active architecture:** TanStack Start, React, Supabase and Cloudflare Workers  
**Scope:** read-only review, CI verification and GitHub documentation comments. No database, production, deployment, merge or paid-environment changes.

## 1. Work completed this session

### PR #13 — visual system, navigation, analytics foundations and Instagram

Rechecked the exact current head `1d23b65537ab240121f5459e919c407f8c6b876a`.

GitHub Actions run `42482826490` completed successfully. The build job passed:
- Locked dependency installation.
- Supabase Edge Function type-check.
- Domain tests: **11 test files, 83 tests passed**.
- TypeScript check and production build.
- Cloudflare Worker bundle dry-run.

The run log was inspected, not inferred from a PR label. This closes the previous uncertainty about CI for that exact head. It does not prove database migration execution, browser acceptance or production readiness.

A fresh evidence comment was added to issue #14 with the CI result and remaining Instagram acceptance requirements.

### PR #22 — authorization correction review

Read the current migration and regression SQL from branch `fix/database-role-scope-authorization-2026-11-08`, head `fc9139924e67a56e59ee8c814a308307cf87008a`.

The regression SQL has improved: it now uses a PostgreSQL `DO` block and raises exceptions on failed source assertions. This is better than the earlier SELECT-only boolean checks. The migration's exact replacement logic is still only statically checked; it has not been executed or compiled in an isolated database.

A follow-up review comment was posted identifying:
- Migration filename `20261108290000_...` uses an invalid hour component (`29`); replace with a valid unique UTC timestamp later than the target branch's current migrations.
- No GitHub Actions run/status is reported for this PR head because the PR targets the feature branch rather than `main`.
- Catalog/source assertions do not replace clean migration replay and authenticated positive/negative role-matrix tests.

PR #22 remains draft and unmerged. No production change was made.

### Release safety and sequencing

Reconfirmed the existing instruction: do not create a Supabase branch or incur branch costs until the development work is complete. No branch was created, no cost confirmation was requested and no hosted schema/data/role/payment/secret was changed.

## 2. Tests and verification

| Check | Result |
|---|---|
| PR #13 GitHub Actions run `42482826490` | **Passed** |
| PR #13 Vitest/domain tests | **83/83 passed, 11 files** |
| PR #13 TypeScript and production build | **Passed** |
| PR #13 Cloudflare Worker dry run | **Passed** |
| PR #22 earlier read-only replacement-string simulation | **5/5 passed** (reported in PR; not repeated as DDL) |
| PR #22 new PostgreSQL regression SQL | **Not run** |
| PR #22 clean migration replay | **Blocked / not run** |
| Authenticated role matrix | **Not run** |
| Browser/device acceptance for PR #13 | **Outstanding** |
| Production deployment | **Not performed** |

No failed tests were observed in the checks run this session. “Not run” is not a pass.

## 3. Current highest-priority blockers

1. **Migration-source reconciliation (release gate).** The live ledger is reported as 98 applied version/name records. Seven original SQL sources have been recovered and byte-for-byte verified in PR #21. The remaining unmatched finance source and duplicate policy files need canonical mapping; all 98 versions need a deterministic source map. The duplicate policy files must not be replayed. Full clean replay remains outstanding.
2. **Authorization corrections.** PR #22 needs a valid migration timestamp, CI coverage, clean replay and authenticated role-matrix tests for captain, assigned/unassigned league admin, admin/super_admin, finance_admin, ordinary authenticated and anonymous actors.
3. **Secure role provisioning.** Issue #24 remains open. There is no supported, owner-approved bootstrap or audited grant/revoke workflow. No live account or role should be created until the owner-approved target identity and bootstrap process exist.
4. **Instagram feature acceptance.** PR #13 has green CI, but migration/RPC execution, RLS checks and browser tests (absent URL, valid URL, update/remove, iOS navigation) remain outstanding.
5. **Canonical OP logo.** Issue #18 remains blocked on a safe binary transfer path. The exact Library asset must be copied byte-for-byte and SHA-256 verified; do not substitute the smaller unverified image in PR #6.
6. **PostHog.** Consent/GPC foundation and configuration documentation exist on PR #13. SDK install, lockfile update, consent-gated initialisation, minimal event capture and admin exclusion are not complete.
7. **Native registration and account workflows.** Issues #16 and #23 remain open; do not bypass identity, approval, consent or role safeguards to accelerate them.
8. **Production acceptance.** No production deployment or final end-to-end acceptance has been completed.

## 4. Open backlog snapshot

Open issues at this review: #9, #10, #11, #14, #15, #16, #17, #18, #19, #23 and #24. PRs #6, #8, #12, #13, #20, #21 and #22 remain open in the repository snapshot; PR #20 is documented as superseded and must not be merged. PR #21 is source recovery only. PR #22 is a draft correction proposal. PR #13 has green CI but remains draft.

The older Stage 1/Stage 2 completion reports in the Library describe a separate legacy/Lovable project and must not be treated as implementation evidence for Open Play New. They are historical requirements context only where explicitly carried into the new repository's issues/specifications.

## 5. Completion assessment

- **Verified work completed this session:** PR #13 CI re-verification, source review of PR #22, and two GitHub evidence/review comments.
- **Development completion percentage:** not responsibly quantifiable from the current evidence because the complete master requirement inventory has not yet been reconciled into one weighted acceptance matrix. Do not invent a percentage from PR count or test count.
- **Production/release completion:** **0% of the final production-release gate**; deployment and production acceptance are intentionally still outstanding.

## 6. Precise next task

Continue the migration reconciliation without creating a Supabase branch: build a canonical 98-row applied-version-to-source manifest from the live ledger and PR #21 recovery set, resolve the three unmatched local files without replaying duplicates, and document the exact clean-replay input set. Only after that source set is internally consistent should isolated replay be scheduled at the end of development, using the agreed no-cost-until-end boundary.


### Profile-edit permission audit — issue #25

Reviewed the current picture-only Edit Profile route and queried live profile permissions read-only. The UI writes only `avatar_path`, but the database grants `authenticated` column-level UPDATE on `first_name`, `last_name`, `display_name`, `phone`, `preferred_position` and `avatar_path`. The owner-row RLS policy therefore does not enforce the picture-only restriction against direct Data API calls. No table-level UPDATE is granted, but column-level grants are sufficient for those columns.

Created issue #25 and linked it from issue #23. Required fix: retain own-row RLS, restrict ordinary self-service column UPDATE to `avatar_path`, preserve verified email changes through Supabase Auth, and add negative permission tests for all other profile fields. No production permission was changed; migration work remains blocked on canonical source reconciliation and isolated replay.


### Additional CI refreshes — PRs #6 and #12

- PR #6 current head `309b5394d9ebb5ddc880f588033c384529ed4080`: workflow `42471613171` passed Edge Function type-check, **8 files / 80 tests**, TypeScript/production build and Cloudflare Worker dry-run. Exact test totals were read from the job log. Stripe end-to-end acceptance remains outstanding.
- PR #12 current head `7ebc3d35cbbd5aa8fef2f761167253979f889ceb`: workflow `42439535124` passed Edge Function type-check, **3 files / 32 tests**, TypeScript/production build and Cloudflare Worker dry-run. Browser/device and database authorization acceptance remain outstanding.
- Fresh CI comments were added to both PR conversations. These results do not imply that the PRs are merged, database-tested or deployed.

### Live migration ledger count refresh

A fresh read-only `list_migrations` call returned **98 rows and 98 unique version values**. The name `admin_fixture_management` occurs twice at distinct applied versions `20261107224311` and `20261107224351`; both must remain distinct in the canonical source map. This confirms the live ledger count but does not resolve the local filename/source mapping or prove a clean replay.


### PR #22 timestamp review correction

The initial review flagged the `20261108290000` migration prefix as an invalid hour. A subsequent check of the target feature branch found existing ordered migration filenames using `20261108270000` and `20261108280000`. The repository therefore appears to use extended numeric ordering labels in this sequence; the earlier timestamp concern is **not a confirmed defect** and was corrected in a follow-up PR comment. The actual blockers remain missing CI, clean replay/SQL compilation and authenticated role-matrix evidence.


### Role-provisioning owner decision — issue #24

A personal-context review found no exact owner-approved grant/revoke authority matrix, bootstrap identity-verification rule, or final-super-admin-removal safeguard. A comment was added to issue #24 recording this as an approval dependency. No role or Auth user was created. Do not infer who may grant or revoke `admin`, `super_admin`, `finance_admin` or `league_admin`; continue with independent work until that decision is supplied.


### Live project baseline refresh

Read-only counts on the connected Supabase project returned **0 Auth users, 0 user-role rows, 0 locations and 0 team memberships**. This is consistent with the current unbootstrapped state. It also means no real owner/admin/captain/ordinary-player session exists for live role acceptance; do not create one without the approved bootstrap and test plan. The profile column-grant issue is therefore a latent permission gap to close before onboarding, not evidence that a current user account was modified.


## 7. Continued execution addendum — 8 November 2026, 13:20 UTC

### PostHog provider hardening

The latest PR #13 head had added the consent-gated PostHog provider. Review found that the route-actor resolver called `getSupabaseClient()` without first checking whether Supabase client configuration was available. This could throw inside a React effect in an environment where PostHog was configured but Supabase was not, allowing optional analytics to generate an application error.

Fixed on the PR #13 branch:
- Import and check `isSupabaseConfigured()` before constructing the Supabase client.
- If account services are not configured, leave the analytics actor as `unknown` and do not capture route events. This is fail-closed and does not affect the rest of the app.
- Read the committed file back from GitHub and confirmed the guard is present.
- New commit: `5acdfefb3bd2d52c575abbe570ce29eeb6a52645`.
- GitHub Actions run `42483918988` completed successfully; all build-job steps passed.

### Profile avatar-only regression test

The live database catalog was rechecked read-only. It confirms that authenticated users have UPDATE on `avatar_path`, but also on `first_name`, `last_name`, `display_name`, `phone` and `preferred_position`. The existing storage policies correctly constrain avatar object insert/update/delete to the caller's UUID folder. This is a permission gap relative to the approved avatar-only profile requirement; no live permission was changed.

Added `supabase/tests/profile_avatar_only_permissions.sql` to the core feature branch, commit `7524dfeb1a3b368addaa8edb86e116c890d2a60e`. It uses a PostgreSQL `DO` block that raises on failed catalog assertions and checks:
- no table-level UPDATE on profiles;
- avatar_path UPDATE retained;
- all non-avatar profile UPDATE grants absent;
- profiles RLS and owner/admin row policy retained;
- owner-folder avatar upload, replacement and deletion policies retained.

The file was fetched back from GitHub and an issue #25 comment records its scope. It has not been executed. It is expected to fail against the current live permission grants until the forward-only correction is implemented and tested in an isolated environment. Two-user Data API tests and actual avatar upload/replace/delete tests remain outstanding. The migration gate remains in force: no schema migration added and no production permission changed.

### Migration ledger clarification

A fresh read-only query reconfirmed:
- 98 applied records, 98 unique versions;
- one repeated name, `admin_fixture_management`, at two distinct applied versions (`20261107224311` and `20261107224351`);
- every ledger record contains one SQL statement.

A separate cross-PR path review found two local files on the core feature branch sharing the prefix `20261108015100`: `payment_service_role_privileges` and `stripe_webhook_processing_lease`. Their applied ledger versions are different (`20261107235943` and `20261108001150`). This local filename collision is now recorded in issue #19 and must be resolved before replay. No historical migration version was changed.

### CI refresh

- PR #13 PostHog guard commit: **GitHub Actions passed**.
- PR #6 profile regression-test commit: GitHub Actions run `42483998963` was still in progress at the time of this addendum; do not count it as passed until its final conclusion is checked.


## 8. Continued execution addendum — 8 November 2026, 13:30 UTC

### Authorization migration filename corrected

PR #22's migration was renamed from the invalid-hour local prefix `20261108290000` to `20261109000000_correct_membership_location_and_finance_authorization.sql`. The new file was read back from GitHub (4,966 characters), and the old path now returns 404. SQL content was preserved unchanged. The new UTC timestamp is valid and sorts after the existing 8 November migrations. PR #22 remains draft/unmerged.

A read-only query against the live database confirmed all six source fragments required by the migration's three guarded function replacements are present. This validates the string-replacement preconditions only; it does not execute DDL, compile the replacements or validate runtime permissions.

### Profile regression test CI

The core feature branch commit adding `supabase/tests/profile_avatar_only_permissions.sql` triggered GitHub Actions run `42483998963`, which completed successfully:
- Edge Function type-check passed.
- **80/80 Vitest tests passed across 8 files.**
- TypeScript and production build passed.
- Cloudflare Worker dry-run passed.

The new SQL regression file is not executed by this CI workflow. Its database assertions and the two-user Data API tests remain outstanding. The workflow emitted a Deno peer-dependency compatibility warning during dependency resolution, but the job completed successfully with no failed steps.

### Updated verified status

- PR #13 analytics provider guard: CI passed after the fix.
- PR #6 profile permission regression-test addition: CI passed; SQL test itself not run.
- PR #22 migration filename: corrected and source preconditions checked; no CI or database replay.
- Live database: unchanged.
- Supabase paid branch / isolated environment: still intentionally deferred until development is complete.

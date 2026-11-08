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


## 9. PostHog resilience CI completed — 8 November 2026, 13:35 UTC

The second PR #13 hardening commit (`ccbc27ccb0874878d409ed732e011458d8e073d7`) adds rejection handling for asynchronous Supabase auth/network actor resolution. If the auth lookup rejects, the analytics actor is reset to `unknown`; no route event is captured. The committed source was read back and checked.

GitHub Actions run `42484179685` completed successfully:
- Supabase Edge Function type-check: passed.
- Vitest: **12 files / 96 tests passed**.
- TypeScript and production build: passed.
- Cloudflare Worker dry-run: passed.
- No failed steps. Deno emitted a peer-dependency compatibility warning during install.

A PR #13 comment records the fix and evidence. Consent grant/revocation/GPC browser tests and proof of zero PostHog network requests before consent remain unverified and are still acceptance requirements.


## 10. Extended migration reconciliation — 8 November 2026, 13:45 UTC

### Exact-source mapping progress

The 98-row live ledger was enumerated again. The verified distinct exact-source set is now **74 of 98 applied versions**:

- **35/35** historical sources in the dedicated PR #2 reconciliation branch now match their exact live ledger statements byte-for-byte. Sixteen files that had formatting/comment drift or had absorbed later edits were restored to the original ledger statement and fetched back for verification. In particular, the original admin_dashboard_projection source was restored; the later admin_queue_consistency migration already carries the approved-membership filter and remains its own exact source.
- **33/33** source files on the current PR #6 core feature branch now map to exact applied ledger versions: 32 existing sources plus the recovered 20261107225102_goal_audit_actor_restrict source. Twenty-six files were renamed from synthetic local ordering prefixes to their actual applied version prefixes; exact ledger SQL was used where needed. The branch now has 33 applied source files and no duplicate migration filename prefixes.
- **6 additional** exact sources from PR #21 beyond its overlapping 20261107224311_admin_fixture_management source: appearance tracking, two finance summary options, two explicit deny policies and location-admin assignments.

The four payment source files and 26 core feature migration files were all aligned to exact applied version prefixes. The Instagram profile migration was separately moved to 20261109005000, preserving order before 20261109010000_team_instagram_handle.sql and avoiding the former 20261108015000 collision with Stripe checkout.

### CI after source alignment

- PR #6 latest core branch run 42485543523: **8 files / 80 tests passed**, Edge Function type-check, TypeScript/production build and Cloudflare Worker dry-run all passed.
- PR #13 latest run 42484316495: **12 files / 97 tests passed**, Edge Function type-check, TypeScript/production build and Cloudflare Worker dry-run all passed.
- These CI runs do not execute SQL migrations or replace clean database replay and authenticated role-matrix testing.

### Remaining source gap

24 of 98 applied ledger versions remain to be mapped or recovered. The full version/name list and next recovery action are recorded in issue #19. The fact that a source is not yet in the verified set does not prove it is absent from every branch; the next task is to locate existing source files by content/version or recover the exact statement from the live ledger, while avoiding duplicate local sources.

### Integration constraint

The PR #2 branch is 24 commits ahead but 481 commits behind the current PR #6 core branch and is divergent. It must not be merged wholesale. Its 35 verified SQL sources are a recovery set; port only the reviewed canonical migration files/manifest into the active integration sequence after conflict review.

### Safety state

No Supabase migration, database DDL, role grant, payment, production deployment or paid branch creation was performed. The user-agreed no-cost-until-development-end boundary remains unchanged.


## 11. Finance reconciliation and branch integration review — 8 November 2026, 13:40 UTC

### Finance semantics test

Fetched the PR #13 SQL regression file `supabase/tests/finance_balance_semantics_regression.sql` and executed its read-only PostgreSQL DO-block assertions against the live function definitions. It completed without exception. The current live `get_finance_ledger`, `get_finance_summary` and `admin_create_finance_entry` definitions contain the expected charge/fine/refund versus payment/credit balance signs, finance-role guards, non-negative outstanding summary and audit insertion. This is source-contract verification only; it is not a migration replay or authenticated ledger arithmetic test. No database mutation occurred.

### PR #13 latest CI

After the three new migration files were given valid ordered UTC timestamps, latest PR #13 head `271340b507fe0a2479c46c573a3c0ced6702bb3f` passed run `42485863731`:
- **13 test files / 103 tests passed**;
- Supabase Edge Function type-check passed;
- TypeScript and production build passed;
- Cloudflare Worker dry-run passed.

The three migration content SHAs were preserved through the renames. The finance test above was separately run read-only against live function definitions.

### Branch divergence — integration blocker

A fresh comparison against the current PR #6 core branch reports:
- PR #13 visual/analytics branch: 232 commits ahead and 377 behind; divergent.
- PR #22 authorization correction branch: 8 commits ahead and 62 behind; divergent.
- PR #2 migration reconciliation branch: 24 commits ahead and 481 behind; divergent.

These branches must not be merged wholesale. The verified files and tested changes are useful source material, but integration requires a deliberate port/rebase and conflict review. Green branch CI does not equal integrated acceptance.

### Remaining work and next execution task

The migration source set is 74/98 exact. The next task is to locate and verify the remaining 24 ledger sources (the exact versions are listed in issue #19), identify any existing files under non-canonical names, and recover only genuinely missing statements. Do not add duplicate migration files or run migrations against production. After source reconciliation, build one integration branch and complete isolated replay at the agreed end-of-development stage.

## 12. Migration source closure and verification pipeline — 8 November 2026, 13:50 UTC

### Applied migration source reconciliation — complete

- Re-read the 24 outstanding applied migration rows from the read-only Supabase migration ledger.
- Located all 24 source files on the active core branch under synthetic timestamp prefixes; none required an invented SQL definition.
- Compared every source against its exact ledger statement. Seventeen were already byte-for-byte exact; seven had drifted and were restored from the authoritative ledger statement.
- Created canonical files using the exact applied version and migration name, and removed the 24 synthetic-prefix paths on draft PR #28.
- Verified all 24 canonical file blob SHAs against the expected newly-created blob SHAs in the PR branch tree; all 24 matched and all 24 old paths were absent.
- This closes the applied migration source mapping at **98/98** across the recovered source branches and PR #28. It is not a migration replay, deployment, or production acceptance.
- PR #28: https://github.com/openplayfootballleague/OPENPLAYNEW/pull/28 (draft).

### CI trigger correction

- The active core .github/workflows/ci.yml previously limited pull_request to PRs targeting main. PRs targeting the active feature/core branch were not receiving CI.
- Removed the target-branch restriction for pull_request; pushes remain restricted to main.
- PR #28 workflow run https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42486495405 passed: Deno Edge Function type-check, Vitest, TypeScript/production build and Cloudflare Worker dry-run.
- The active core branch's own PR #6 workflow run https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42486515290 also passed after the workflow change.

### PostHog actor-resolution hardening

- Review of the current PR #13 branch found the analytics actor resolver still called getSupabaseClient() without checking whether Supabase was configured, and an unexpected rejected auth/database lookup could escape as an unhandled promise rejection.
- Added a configuration guard, synchronous client-initialisation fallback, and a fail-closed resolver that maps rejected lookups to unknown; unknown actors do not capture route events.
- Added three tests for the unconfigured path, successful resolution and rejected lookup fallback.
- Latest PR #13/PR #27 shared branch head 32b45fab1112fd970994f7eb03f08d3c3b394ac2 passed https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42486692854: **14 test files / 106 tests passed**, Deno Edge Function type-check, TypeScript/production build and Cloudflare Worker dry-run.
- This does not yet prove browser-level consent/revocation behavior or absence of network requests before opt-in.

### Current blockers and safety state

- PR #13 analytics/visual branch and PR #22 authorization branch remain substantially divergent from the core branch; do not merge wholesale. Port reviewed changes in small, verified increments.
- PR #22 authorization migration still lacks an isolated replay and real positive/negative authenticated role-matrix test. Its static catalog assertions do not establish role behavior.
- Initial Super Admin provisioning remains blocked on explicit owner approval of the authority matrix and confirmation of the first trusted owner Auth identity. No account or role was created.
- PostHog project-level privacy settings and browser network behavior still require verification.
- No Supabase branch was created, no migration was applied, no production data/DDL was changed, no roles/users were provisioned, no payment was triggered, and no production deployment occurred. The agreed no-cost-until-development-end boundary remains intact.

### Precise next task

Port the reviewed consent-aware PostHog provider and actor-resolver hardening onto the active core branch as a small integration PR, then add browser-level tests proving no PostHog network requests before explicit opt-in, opt-out/revocation, GPC override, and cross-tab consent changes. Keep analytics fail-closed and exclude privileged actors. Continue with PR #22's role-matrix validation after the analytics port; do not provision the first Super Admin until the owner approval dependency is resolved.

# M1 — Development environment and release baseline

**Snapshot date:** 12 November 2026  
**Canonical repository:** `openplayfootballleague/OPENPLAYNEW`  
**Canonical integration candidate:** `integration/verified-analytics-and-manual-recruitment-2026-11-12`  
**Snapshot head before this document commit:** `c4161dcda8d32e7cca51657984b515b6e65ea14b`  
**Status:** Partially complete — not signed off; not released.

## 1. Canonical integration route

The canonical candidate is the head branch of PR #109. Commit-graph comparisons establish:

- PR #109 is a direct descendant of PR #89's exact head `cc7fce58d250e78f1dba2f77368a12c3b8dba84a`: 34 commits ahead, 0 behind.
- PR #109 is 31 commits ahead of the superseded PR #97 reconciliation head `f5d0243da56ce3b292cfa88ab0e7289fb1feb8e6`, with 0 behind.
- PR #109 is 24 commits ahead of the former PR #101 combined candidate `c0bb4882fd2a48bd5ec3ae965a324b5973d86e99`, with 0 behind. PR #101 was closed as superseded, not merged; its commits remain in the canonical branch.
- PR #90 and PRs #96–#99 were closed as superseded/obsolete. PR #87 remains an unmerged source/reference branch because its history diverges and must not be mechanically merged. PR #89 remains the required base of the current candidate.
- Feature PRs #110–#113 are separate stacked work and are not part of this M1 baseline.

### Proposed promotion order — not executed

1. Merge PR #89 into `integration/complete-product-build`.
2. Retarget PR #109 to `integration/complete-product-build` and merge its verified 34-commit delta only after reviewing the updated diff and rerunning all checks.
3. Run the full required CI suite on the resulting canonical integration head.
4. Promote toward `main` only after main branch protection, main CI and owner approval are in place.

No PR was merged as part of this M1 work.

## 2. Automated verification evidence

PR #109 exact-head workflow run [43243160741](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/43243160741) passed all four jobs:

- Build / TypeScript / domain tests / Wrangler dry-run.
- Clean Supabase migration replay and database security/regression assertions.
- Chromium responsive and PWA acceptance.
- PostHog consent and network acceptance.

Additional evidence from the run logs:

- 16 Vitest files passed; 148 tests passed.
- Stripe Connect webhook signature tests: 6 passed.
- The clean hosted-order replay passed with 99 baseline migrations followed by 39 forward-only pending migrations (138 total recorded in the replay).
- All 26 database security assertions passed.
- Auth lifecycle integration passed for signup, confirmation email, verified sign-in, account/player separation, player registration, duplicate registration protection, password recovery/update and sign-out.
- `npx wrangler deploy --dry-run` completed successfully. This is a local bundle/configuration dry-run, not a Cloudflare deployment.

The GitHub Actions checks above are exact-head evidence for the candidate branch. They do not establish that `main` is protected or that the Cloudflare dashboard build pipeline is healthy.

## 3. Hosted Supabase baseline — read-only

Connected project: `OPENPLAYNEW` (`ghnrsysvrlgkjmdlwdmp`)

- Status: `ACTIVE_HEALTHY`
- Region: `eu-west-1`
- PostgreSQL: 17.11.0.018 (major version 17)
- Hosted migration ledger: 99 applied entries.
- No hosted migration was applied during this audit.

The canonical candidate's CI verifies the committed migration source manifest and clean replay. The 39 additional forward-only migrations remain pending; they have not been applied to the hosted project.

## 4. Environment and Cloudflare configuration review

Reviewed on the canonical candidate:

- `wrangler.jsonc` names the Worker `openplaynew`, uses the TanStack Start server entry, enables observability, and declares custom domains `openplayfootball.co.uk` and `www.openplayfootball.co.uk`.
- The config does not contain an `account_id` or `zone_id`; those are not to be guessed or added without confirming the actual Cloudflare account and zone.
- `.env.example` contains the public Supabase URL and publishable key only. Stripe and PostHog browser tokens remain blank. PostHog privacy verification remains `false`. Server-side secrets are documented as Worker secrets, not `VITE_` browser variables.
- Local Supabase Auth config points to localhost and requires email confirmation.
- The connected Supabase project is healthy and matches the public project URL in the example configuration.

### Cloudflare blocker

Cloudflare's GitHub preview/build bot reports a failed build for canonical commit `c4161dc`:

- Build ID: `bf17128c-e914-4230-93a3-c05e5d48b98e`
- Dashboard log: https://dash.cloudflare.com/?to=/ef398617677b8165236062bfa5f682ac/workers/services/view/openplaynew/production/builds/bf17128c-e914-4230-93a3-c05e5d48b98e

The GitHub CI Wrangler dry-run passes, but the Cloudflare dashboard build log and account/zone ownership cannot be read through the currently connected GitHub/Supabase tools. Therefore the actual Cloudflare deployment target is not independently verified and the external build failure is not diagnosed. No deployment was attempted.

## 5. Main branch protection and CI

The latest audited main head is `6dec5acf67421328ce6ccc7e0c462aa7d1975364`.

- GitHub previously reported `main` as unprotected (`protected: false`) with no rulesets.
- The connected GitHub integration lacks the Administration permission required to configure branch protection (403).
- No published status checks were returned for this exact main head.
- The connected GitHub toolset cannot dispatch a workflow manually on `main`.

Owner/admin action required in GitHub repository Settings:

1. Add an active branch ruleset targeting `main`.
2. Require pull requests before merging and prevent force-push/deletion.
3. Require the four checks used by the canonical candidate: build, clean Supabase migration replay/security, Chromium responsive/PWA, and PostHog consent/network acceptance.
4. Run the Build verification workflow manually against `main` and confirm the resulting checks.

## 6. M1 acceptance status

- [x] Canonical integration branch selected and promotion order documented.
- [x] Duplicate integration routes closed or classified; source branches retained.
- [x] Hosted migration ledger reconciled; canonical clean replay passes (99 baseline + 39 pending).
- [ ] Main branch protection and required checks enabled.
- [ ] Clean CI evidenced on both the canonical integration head after this document commit and the exact main head.
- [ ] Cloudflare dashboard build failure diagnosed; account/zone target independently verified without deploying.
- [ ] Final M1 baseline reviewed and owner sign-off recorded before M2.

## 7. Safety record

No merges, main-branch changes, hosted Supabase migrations, Edge Function deployments, production data changes, role provisioning, live Stripe actions, notification dispatch, Cloudflare deployments or production configuration changes were performed for this baseline.

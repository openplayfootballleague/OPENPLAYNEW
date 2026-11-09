# Open Play New — Phase 1 audit evidence pack

**Evidence date:** 9 November 2026  
**Status:** Audit pack assembled; Phase 1 is not signed off for release.  
**Repository:** `openplayfootballleague/OPENPLAYNEW`  
**Working branch:** `feat/registration-safeguards-2026-11-08`  
**Pull request:** [#49](https://github.com/openplayfootballleague/OPENPLAYNEW/pull/49)  
**CI evidence commit:** `61937e1105e2bc9d06cfa8d32e9f0cd655cdb2b3`  
**Latest complete automated run:** [#1537](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42687671582)

This pack records the implementation evidence, connected hosted-project baseline, known advisor findings and release gates. It is an engineering audit handover, not an independent penetration test, legal opinion, data-protection impact assessment or release authorisation.

## 1. Executive status

| Area | Status | Evidence / limitation |
|---|---|---|
| Application build, type-check and domain tests | Passed | CI #1537 |
| Edge Function static security checks and Deno type-check | Passed | CI #1537 |
| Clean database migration replay | Passed | CI #1537 |
| Hosted-order migration replay | Passed | CI #1537; 99 baseline + 14 pending |
| SQL role, RLS, lifecycle and identity regression suites | Passed | CI #1537 |
| 90/30/7-day inactivity warning logic | Implemented and regression-tested | CI #1537; provider delivery not yet exercised in staging |
| Connected Supabase hosted baseline | Read-only inspected | 99 migrations; four deployed Edge Functions |
| New Phase 1 migrations / functions deployed | No | Explicit release gate |
| Real-device product acceptance | Outstanding | Requires human mobile, tablet and desktop review |
| Live email and worker acceptance | Outstanding | Requires controlled disposable-account staging |
| Privacy/legal and accounting decisions | Outstanding | See section 6 |
| PR merge / release approval | Not granted | PR #49 remains open |

## 2. Repository and change control

- PR #49 is open and GitHub reports it mergeable.
- Current PR target is `test/auth-email-lifecycle-2026-11-08`; repository default branch is `main`.
- The target has deliberately not been changed. Confirm the intended release target before merge.
- At the evidence check, PR #49 had no submitted reviews, inline review comments or issue comments.
- The implementation commit tested by CI #1537 is `61937e1105e2bc9d06cfa8d32e9f0cd655cdb2b3`. Subsequent commits `2057d335a68e321e72cb21f164a1c43c4c8c7879` and `45429523b9977bc02001d975fa6dfa2c12e45a36` update audit documentation only; no application, Edge Function or SQL implementation changed after the tested implementation commit.
- Do not merge or deploy solely because the automated checks pass.

## 3. Automated evidence

[CI run #1537](https://github.com/openplayfootballleague/OPENPLAYNEW/actions/runs/42687671582) completed successfully. Both jobs passed.

**Build job**
- Canonical migration-source manifest verification.
- Edge Function security-configuration assertions.
- Player navigation specification assertions.
- Deno type-check for Edge Functions.
- Domain tests.
- TypeScript application type-check and build.
- Cloudflare Worker bundle dry-run.

**Clean Supabase migration/security job**
- Start isolated local Supabase database.
- Replay all migration sources from a clean database.
- Recreate the hosted migration baseline and verify pending migration order with the pinned CLI and `--include-all`.
- Player self-service profile permissions.
- Player, captain and admin RLS role boundaries.
- Database security assertions.
- Membership, location and finance authorization.
- Finance ledger balance semantics.
- Points-only league rankings.
- Fixture venue/location boundaries.
- Player identity matching and review-data access.
- Phone canonicalisation and player-ban safeguards.
- Age tiers and guardian-consent lifecycle.
- Player account retention and reactivation.
- Global-admin retention holds.
- Permanent competition identity and safe erasure.
- Captain next-required fixture and post-match amendment guards.
- Auth signup, email confirmation and password recovery.

The retention suite includes warning-stage catch-up, idempotent successful sends, failed-send claim retry, and the database-enforced final seven-day grace period. CI proves the database logic and code build; it does not prove live Resend delivery, actual inbox receipt, storage-object deletion in the hosted environment or visual acceptance on devices.

## 4. Connected Supabase baseline — read-only inspection

**Project:** `OPENPLAYNEW`  
**Project ref:** `ghnrsysvrlgkjmdlwdmp`  
**Region:** `eu-west-1`  
**Status at inspection:** `ACTIVE_HEALTHY`  
**Database:** PostgreSQL 17.11

**Migration ledger**
- 99 migrations are recorded as applied.
- Latest recorded version: `20261108194831`.
- The branch has 14 additional forward-only migrations, giving 113 sources in the clean hosted-order replay (99 recorded baseline + 14 pending).
- Three pending migrations have timestamps older than the latest hosted ledger version. The CI release-path check uses `--include-all`.
- No pending Phase 1 migration was applied to the connected project during this audit.

**Deployed Edge Functions**
- `deliver-notifications`
- `create-player-checkout`
- `stripe-webhook`
- `public-gallery`

`guardian-consent` and `player-account-retention` remain branch-only and are not deployed. The Supabase branch listing shows only the default `main` branch; no separate staging branch is present.

## 5. Supabase advisor baseline

The connected project advisors were queried read-only on 9 November 2026.

### Security advisor

| Finding | Count | Assessment |
|---|---:|---|
| Authenticated-callable SECURITY DEFINER functions | 77 WARN | Reviewed against the hosted source snapshot; all have explicit empty `search_path`; none is callable by `anon`. Caller, role, location and data-scope checks were reviewed. Keep this finding visible; do not weaken grants merely to clear the warning. |
| RLS enabled with no policies | 3 INFO | `admin_context_preferences`, `gallery_items`, `location_admin_assignments`. These use RPC-only access; direct client table grants were separately verified absent in the hosted baseline. |

The earlier catalog review found 96 public SECURITY DEFINER functions in total: 77 authenticated-callable and 19 internal-only. The 77 authenticated-callable definitions were reviewed line-by-line against the hosted snapshot. This review is not a substitute for rechecking the deployed definitions after the pending migrations are released.

### Performance advisor

| Finding | Count | Assessment |
|---|---:|---|
| Unindexed foreign keys | 7 INFO | Review index coverage before material production growth, especially admin-context preferences, gallery uploader, location assignments and Stripe webhook references. |
| Unused indexes | 52 INFO | Low-use/new-project activity can explain this snapshot. Do not drop indexes solely from this finding; reassess after representative traffic and query plans. |
| Multiple permissive RLS policies | 15 WARN | Review the policy OR-composition and query cost. The current role/location regression suite passes; do not consolidate policies without preserving those semantics. |

**Health advisor:** no findings returned at inspection.

These advisor findings are recorded rather than suppressed. A warning is not, by itself, proof of an exploitable vulnerability; equally, a passing CI suite is not a guarantee of security in every runtime configuration.

## 6. Outstanding audit and release gates

The following items remain open and must not be represented as complete.

### A. Staging and operational proof
- Create/identify an approved staging environment. No separate Supabase staging branch currently exists.
- Configure the required secrets in that environment only: Supabase URL/keys, retention cron secret, Resend API key and verified sender address.
- Verify guardian verification, withdrawal and reactivation emails using disposable accounts.
- Verify 90-, 30- and 7-day inactivity emails, provider idempotency, retry after provider failure, warning catch-up and closure grace period.
- Exercise the retention worker only against disposable test accounts. Do not dispatch it against real player accounts as an audit test.
- Verify avatar object removal and retry behaviour against disposable storage objects.
- Record provider message IDs, timestamps, expected outcomes and redacted logs; never place tokens, service-role keys or personal data in the audit evidence.

### B. Product acceptance
A human reviewer must use real devices or representative device/browser combinations and record pass/fail, date, device/browser and evidence for:
- Registration form validation, errors and pending/rejected states.
- Guardian verification, admin decision and withdrawal.
- Ban/unban and captain succession.
- Closure, restricted archive, reactivation and sign-in/session handling.
- Admin result entry, scorer options, season statistics, team sheets, transfer/payment readers after anonymisation.
- Mobile, tablet and desktop layout, keyboard/focus behaviour, touch targets and navigation.

Static CSS and route assertions are not visual acceptance.

### C. Privacy, legal and records management
- Confirm the data controller's full legal identity and final public contact/address details before publishing the privacy notice. The confirmed contact email is `openplayfootballleague@gmail.com`; the full legal name and final public address are not yet confirmed.
- Obtain an appropriate UK GDPR review of lawful basis, retention periods, safeguarding/under-18 data, data-subject rights and legal holds.
- Treat retained competition identity and match history as pseudonymous personal data unless a qualified review establishes genuine anonymisation.
- Document and approve the separate payment/accounting retention schedule, including which Stripe/payment references must remain for statutory, refund or dispute purposes and when direct account/customer links are detached.
- Complete the PostHog consent design before enabling new tracking: explicit opt-in, correct Supabase Auth identity/reset on logout, privacy-safe event properties and no session replay/autocapture until approved. The current branch does not initialise the SDK or provide a consent UI.

### D. Release control
- Confirm whether PR #49 should target `test/auth-email-lifecycle-2026-11-08` or `main`.
- Obtain an explicit merge/release approval.
- Review the migration deployment plan and verify the 99 already-recorded migrations are not reapplied.
- Deploy the two new Edge Functions and apply pending migrations only under an approved release plan.
- Keep unattended retention processing disabled until staging acceptance, legal review and operational sign-off are complete.

## 7. Audit sign-off record

Complete this section during the formal review; do not pre-fill approvals.

| Sign-off | Reviewer | Date | Result / evidence |
|---|---|---|---|
| Engineering source and migration review | Pending | Pending | Pending |
| Security / access-control review | Pending | Pending | Pending |
| Staging email and retention-worker acceptance | Pending | Pending | Pending |
| Product/device acceptance | Pending | Pending | Pending |
| Privacy/legal review | Pending | Pending | Pending |
| Finance/accounting retention review | Pending | Pending | Pending |
| Release / merge approval | Pending | Pending | Pending |

## 8. Current conclusion

Open Play New Phase 1 is **automated-test green and audit-pack prepared, but not release-ready or signed off**. The implementation has reproducible CI evidence and a documented hosted baseline. The remaining blockers are controlled staging proof, human product acceptance, privacy/legal and payment-retention decisions, and explicit release/merge approval.

No hosted migration, Edge Function deployment, PR merge, or unattended retention activation was performed as part of this audit preparation.

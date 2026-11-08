# Team Instagram profile links — 8 November 2026

## Scope
Optional Instagram profile URL stored against `public.teams`, not a player profile. The same team record is referenced from season-specific `season_teams` rows, preserving its social link across seasons and locations wherever that team record is reused.

## Implemented on the development branch
- Team registration accepts an optional Instagram URL and calls the extended `register_team` RPC.
- Existing public registration eligibility checks are retained: authenticated approved player, public published league, and registration-open season.
- Client normalisation helper accepts only direct HTTPS Instagram profile URLs and normalises to `https://www.instagram.com/{handle}/`.
- Database constraint and both registration/update RPCs validate profile URL shape and safe Instagram host.
- Public team directory selects the team-level URL and renders a compact Instagram icon only when a URL exists.
- Active captains can update/remove the URL for their season-team through the existing Captains Hub.
- Platform admins and location-assigned league admins can manage team URLs through the existing admin setup area; authorisation is checked in SQL.
- Changes are audit logged without recording the URL in audit metadata.
- Public read access is restricted to team ID and Instagram URL columns and approved teams in public published seasons.

## Files
- `src/lib/teams/instagram.ts`
- `src/lib/teams/instagram.test.ts`
- `src/routes/join.tsx`
- `src/routes/teams.tsx`
- `src/routes/captain.tsx`
- `src/routes/admin.tsx`
- `src/lib/supabase/database.types.ts`
- `src/styles.css`
- `supabase/migrations/20261108015000_team_instagram_profile.sql`

## Validation
Automated unit tests cover supported URL forms, host normalisation, empty optional values, and rejection of HTTP, lookalike domains, arbitrary domains, script schemes, query/redirect suffixes, non-profile paths and invalid handles.

CI has successfully completed client and server production bundling in the feature runs. The latest TypeScript/build/Cloudflare dry-run workflow is still being verified; earlier failures were diagnosed and corrected (duplicate generated RPC type entries and an admin team-create call incorrectly passing a new parameter to an unchanged RPC). Do not regard the feature as fully verified until a clean latest workflow run passes.

## Acceptance testing still required
- Run a disposable database migration test against the reconciled schema before applying migration.
- Exercise registration with no handle/link, handle only, and both values. Current branch's registration UI had no separate pre-existing Instagram-handle input, and the separate optional handle field is now included in the follow-up implementation below.
- Test invalid URLs against the actual RPC and database constraint.
- Verify icon appears only for non-null valid URLs; update/removal refreshes the team directory.
- Verify iOS universal-link opening with Instagram installed and browser fallback without the app.
- Verify a captain can edit only their own active team; another team captain is denied; location admins are restricted to assigned locations; global admins are permitted.
- Verify updates to one team do not affect other team records.
- Verify same team linked to multiple seasons retains its one team-level profile link.

## Deployment
No migration has been applied to production. No live deployment or PR merge has been performed.

## Final CI verification update — 10:04 UTC
Latest workflow run `42469768931` for commit `d341295ad9d9f7ae8f88200e5b42e7f5c87d10f2` completed successfully:
- Supabase Edge Function type-check: passed
- Domain tests: 8 test files, 61 tests passed (including 10 Instagram URL validation tests)
- TypeScript and production client/server build: passed
- Cloudflare Worker bundle dry-run validation: passed

The previous failures were corrected: duplicate RPC type declarations were removed, and the generated database types now keep `admin_create_season_team` separate from the extended `register_team` signature.

A hosted Supabase development branch was not created: the Supabase tool requires explicit cost confirmation before provisioning. No production migration was applied. SQL migration execution and role/row-level behaviour therefore remain unverified.

## Follow-up: individual team profile route — 8 November 2026

The initial implementation exposed the conditional Instagram link on each team directory card. Review confirmed this branch did not yet contain an individual public team-profile route, despite the intended acceptance behaviour referring to an in-app team profile. Added:
- `src/routes/teams.$teamId.tsx`: public profile for an approved season-team entry, limited to public active/completed seasons.
- Directory team names now link to their individual profile.
- Instagram link is displayed on the profile only when the team-level URL exists; no URL means no icon or link.
- Profile CSS preserves the established visual system.

This is an additional code change awaiting CI. It has not been deployed. Database/RLS behaviour and real-device navigation remain unverified. The profile route intentionally uses the same public-season and approved-team filters as the directory; it does not expose player/member records.

### CI verification update — 8 November 2026

Workflow run `42470183329`, attempt 4, completed successfully on commit `a1566308fbe3fc30497981cf6d65e0c04a5c0a1d`. Passed:
- Install locked dependencies
- Supabase Edge Function type-check
- Domain tests
- TypeScript type-check and production build
- Cloudflare Worker bundle dry-run validation

Attempts 1–3 failed before application tests because GitHub returned HTTP 504 while downloading Deno. Attempt 4 successfully installed Deno and passed every workflow step.

This verifies compilation, current automated domain tests and Worker bundle validation for the code at that commit. It does **not** verify the un-applied Supabase migration, production RLS, live captain/admin authorisation, public database reads, browser navigation, or iOS Instagram deep-link behaviour. The report commit that records this CI result is documentation-only and does not alter application code.
CI run 42470183329 (attempt 4) reported **8 test files passed, 61 tests passed**, followed by a successful `npm run build` (`vite build` plus `tsc --noEmit`) and successful Cloudflare Worker dry-run. The job completed successfully.

### Compact profile icon refinement — 8 November 2026

- Changed the individual team profile action from a labelled “Visit Instagram” pill to the compact Instagram icon requested for team profiles.
- Kept the anchor conditional on `instagram_profile_url`; a missing URL still renders no icon or link.
- Updated the profile-specific CSS to use the same 34px circular icon dimensions as the directory affordance.
- Read the updated route and stylesheet back from GitHub and verified the labelled text is absent and the compact dimensions are present.
- Commits: `51c2d96f76eb8400ac640f57fd7eec128a35a375` (profile markup) and `d5330090864e4f6e2fc4dca08b70f4b52d707585` (CSS).
- A new CI result for these two commits has not yet been observed. Prior successful CI at `a156630` does not prove these later edits passed.


### Separate optional handle field — 8 November 2026

- Added an optional Instagram handle input immediately before the optional profile URL input in team registration.
- The handle is stored separately on the canonical `public.teams.instagram_handle` column; the profile URL remains the sole source for the clickable profile icon. A handle alone never creates a nonfunctional icon.
- Client helper `src/lib/teams/instagram-handle.ts` trims whitespace, removes one optional leading @, and rejects invalid characters, repeated dots, leading/trailing dots and values over 30 characters.
- Added a database constraint and a six-argument `register_team` overload. It validates the handle, delegates existing player/season/team checks to the established five-argument registration RPC, then attaches the handle only to the newly created team owned by the authenticated actor. The old five-argument RPC remains available to existing callers.
- Updated generated Supabase function/table types and reset the handle after successful submission.
- Added unit tests for canonicalisation, empty optional values and invalid inputs.
- Source changes are on the existing PR #13 branch. Workflow runs `42475566080` and `42475572849` were observed running for intermediate commits; a completed result for final head `6bc1fb853f6a0e4beb10412200af0526bf400519` is still required.
- Migration is not applied to production; isolated SQL replay, registration RPC execution, role/browser tests and deployment remain outstanding.

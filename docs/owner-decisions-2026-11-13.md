# Open Play — authoritative owner decisions (13 November 2026)

These decisions were given by the product owner on 13 November 2026. They override any conflicting statement in the
Master Application Blueprint v4.0, older documents, branches or pull requests. Agents must follow them without asking for
re-approval. Changes require a new dated owner decision recorded here.

## D1 — Hosting: Cloudflare Workers

- Cloudflare Workers is the hosting platform. Keep the existing Cloudflare architecture and the
  `openplayfootball.co.uk` / `www.openplayfootball.co.uk` custom-domain configuration in `wrangler.jsonc`.
- Do **not** migrate to Vercel. Vercel tooling may be used only for reference or diagnostics.
- Local development must work by aligning the pinned Wrangler / `@cloudflare/vite-plugin` / `workerd` versions with the
  project's `compatibility_date`. Do not permanently lower the compatibility date or alter configuration only to make a
  temporary local workaround pass.

## D2 — Fixture format: Bideford double round-robin

- Bideford: 8 teams, home-and-away double round-robin.
- 14 gameweeks, 4 matches per gameweek, **56 matches** in total; every team plays every other team twice (home and away).
- "28" in the Blueprint is the number of **unique team pairings**, not the number of matches.
- The fixture generator must support single and double round-robin. **Double is the default for Bideford.**

## D3 — Database source of truth

- Every function, table, policy and grant the application relies on must be recreatable from forward-only migrations in
  this repository. Recover definitions from the live Supabase project where sources are missing.
- Preserve existing behaviour and security permissions. No destructive database changes.
- Status (13 Nov 2026): on the integration line (PR #109 / #140) all 99 applied hosted migrations are present and
  byte-identical to `docs/supabase-migration-source-manifest-2026-11-08.md` (which was derived from the live ledger),
  including `admin_record_fixture_result_with_appearances`, `admin_set_location_active` and the 11 messaging RPCs. All 138
  candidate migrations replay cleanly. The outstanding step is promoting that line to `main`, and committing as files any
  migration that CI currently generates from `supabase/drafts/` at run time.

## D4 — Inbox: Notifications and Messages

- Messaging is required. The member experience is a single **Inbox** at `/inbox` with two separate sections:
  - **Notifications** — automated league alerts and official announcements.
  - **Messages** — player-to-player messaging, including captains.
- Administrators communicate through automated notifications and announcements, **not** direct messages.
- Messaging is **not** unrestricted between every user by default. Follow the existing secure messaging requirements
  (`docs/secure-messaging-platform.md`, migration `20261111194000_secure_messaging_platform.sql`); build on that system rather
  than inventing a new one.

## D5 — Logo

- Use the exact original Open Play logo supplied by the owner. Never recreate, redraw, trace, approximate or substitute it.
- **Outstanding asset requirement (13 Nov 2026):** the repository does not contain a verified full-resolution original.
  `public/open-play-logo.png` is 192×115 px; the `open-play-logo.svg` variants on other branches are a single auto-traced
  polygon path (an approximation) and must not be used. Issue #18 tracks this. Until the original file is committed, any
  rendered logo is a placeholder, not a finished solution.

## D6 — Payments

- Do not build or activate new online card-payment functionality without explicit owner approval.
- Continue the existing approved payment architecture, including referee Stripe Connect payouts, behind release and
  approval gates (test mode only; no live keys, payments, transfers or webhooks without approval).

## D7 — League table and title decider

- Points only. Goal difference and head-to-head are **not** automatic tie-breakers.
- Teams level on points share a league position.
- If two or more teams finish level on points in first place, they play a **final** to decide the champion.
- This rule applies to the league table, competition logic and the season-completion workflow: a season with a shared
  first place cannot be completed until the final has been played and recorded.
- Implementation (migration `20261113160000_title_final_and_season_completion_guard.sql`): `fixtures.is_title_final`;
  `admin_create_title_final` (active season, every league fixture finished with a confirmed result, exactly the two
  joint leaders, location scope, audited); trigger `guard_season_title_final` blocks `completed` until a decisive final
  result is confirmed; the final is excluded from league points but counts for player appearances and goals.

### Open questions for the owner (not invented)

1. **Three or more teams level in first place.** D7 covers two teams. The system refuses to arrange a final and keeps
   the season open until the owner defines the format.
2. **A drawn final.** The guard requires a decisive confirmed score. If finals are settled by extra time or penalties,
   confirm how that should be recorded (for example, a penalty-shootout field) rather than entering a non-match score.

## Development safety (unchanged)

No production deployment, live migration, payment processing or secret changes without explicit owner approval.
GitHub remains the shared source of truth between AI agents (`docs/AI-COMMUNICATION.md`).
